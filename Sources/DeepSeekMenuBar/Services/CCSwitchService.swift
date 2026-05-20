import Foundation
import SQLite3
import OSLog

protocol CCSwitchServiceProtocol {
    func isAvailable() -> Bool
    func readRequestLogs(since: Date?) async throws -> [UsageRecord]
    func readDeepSeekAPIKey() async throws -> (key: String, baseURL: String)?
    func latestRequestTimestamp() async throws -> Date?
}

struct CCSwitchService: CCSwitchServiceProtocol {
    private let logger = Logger(subsystem: "com.deepseek.menubar", category: "CCSwitch")

    private var dbPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cc-switch/cc-switch.db")
            .path
    }

    func isAvailable() -> Bool {
        FileManager.default.fileExists(atPath: dbPath)
    }

    // MARK: - Schema discovery

    private struct ColumnInfo {
        let name: String
        let type: String
    }

    /// Our logical field → possible CC Switch column names
    private static let columnCandidates: [String: [String]] = [
        "timestamp":   ["created_at", "timestamp", "request_time", "time"],
        "model":       ["model", "request_model"],
        "total_tokens":  [], // computed from input+output+cache
        "input_tokens":   ["input_tokens"],
        "output_tokens":  ["output_tokens", "completion_tokens"],
        "cache_hit_tokens":  ["cache_read_tokens", "cache_hit_tokens"],
        "cache_miss_tokens": ["cache_creation_tokens", "cache_miss_tokens"],
        "total_cost_usd": ["total_cost_usd", "cost_usd", "cost"],
        "request_id":   ["request_id", "requestId"],
    ]

    private func discoverColumns(_ db: OpaquePointer) -> [ColumnInfo] {
        let sql = "PRAGMA table_info(proxy_request_logs)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var cols: [ColumnInfo] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let name = sqlite3_column_type(stmt, 1) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(stmt, 1)) : ""
            let type = sqlite3_column_type(stmt, 2) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(stmt, 2)) : ""
            if !name.isEmpty { cols.append(ColumnInfo(name: name, type: type.lowercased())) }
        }
        return cols
    }

    private func buildColumnMap(columns: [ColumnInfo]) -> [String: (name: String, type: String)] {
        var map: [String: (name: String, type: String)] = [:]
        for (logical, candidates) in Self.columnCandidates {
            for candidate in candidates {
                if let col = columns.first(where: { $0.name.lowercased() == candidate.lowercased() }) {
                    map[logical] = (col.name, col.type)
                    break
                }
            }
        }
        return map
    }

    // MARK: - Timestamp parsing

    private func parseTimestamp(_ stmt: OpaquePointer, col idx: Int32, type: String) -> Date? {
        if sqlite3_column_type(stmt, idx) == SQLITE_NULL { return nil }

        if type.contains("int") {
            let ts = sqlite3_column_int64(stmt, idx)
            if ts > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: Double(ts) / 1000.0)
            }
            return Date(timeIntervalSince1970: Double(ts))
        }

        if let text = sqlite3_column_text(stmt, idx) {
            let str = String(cString: text)
            if let d = ISO8601DateFormatter().date(from: str) { return d }
        }

        return nil
    }

    // MARK: - Data reading

    func readRequestLogs(since: Date?) async throws -> [UsageRecord] {
        guard isAvailable() else { return [] }

        let path = dbPath
        return try await Task.detached {
            var db: OpaquePointer?
            guard sqlite3_open(path, &db) == SQLITE_OK, let db = db else {
                logger.error("无法打开 CC Switch 数据库")
                return []
            }
            defer { sqlite3_close(db) }
            sqlite3_busy_timeout(db, 2000)

            let columns = discoverColumns(db)
            guard !columns.isEmpty else {
                logger.warning("proxy_request_logs 表不存在或无列")
                return []
            }

            let col = buildColumnMap(columns: columns)
            guard let tsInfo = col["timestamp"] else {
                logger.warning("未找到时间戳列，可用: \(columns.map(\.name).joined(separator: ", "))")
                return []
            }

            // Build SELECT: only columns we actually found
            var selectParts: [String] = ["`\(tsInfo.name)`"]
            var selectedLogical: [(String, String)] = [("timestamp", tsInfo.type)]

            for logical in ["model", "input_tokens", "output_tokens",
                            "cache_hit_tokens", "cache_miss_tokens",
                            "total_cost_usd", "request_id"] {
                if let info = col[logical] {
                    selectParts.append("`\(info.name)`")
                    selectedLogical.append((logical, info.type))
                }
            }

            let sql: String
            if since != nil {
                sql = "SELECT \(selectParts.joined(separator: ",")) FROM proxy_request_logs WHERE `\(tsInfo.name)` > ? ORDER BY `\(tsInfo.name)` ASC"
            } else {
                sql = "SELECT \(selectParts.joined(separator: ",")) FROM proxy_request_logs ORDER BY `\(tsInfo.name)` ASC"
            }

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else {
                logger.error("查询失败: \(String(cString: sqlite3_errmsg(db)))")
                return []
            }
            defer { sqlite3_finalize(stmt) }

            if let since = since {
                sqlite3_bind_int64(stmt, 1, Int64(since.timeIntervalSince1970))
            }

            var records: [UsageRecord] = []
            var skipped = 0

            while sqlite3_step(stmt) == SQLITE_ROW {
                // Parse timestamp (column 0)
                guard let timestamp = parseTimestamp(stmt, col: 0, type: tsInfo.type) else {
                    skipped += 1; continue
                }

                // Build index map for the rest
                var idx = 1
                var model = "unknown", inputT = 0, outputT = 0
                var cacheHit = 0, cacheMiss = 0
                var costUSD: Double? = nil
                var requestID: String? = nil

                for (logical, type) in selectedLogical.dropFirst() {
                    guard sqlite3_column_type(stmt, Int32(idx)) != SQLITE_NULL else { idx += 1; continue }
                    switch logical {
                    case "model":
                        model = String(cString: sqlite3_column_text(stmt, Int32(idx)))
                    case "input_tokens":
                        inputT = Int(sqlite3_column_int64(stmt, Int32(idx)))
                    case "output_tokens":
                        outputT = Int(sqlite3_column_int64(stmt, Int32(idx)))
                    case "cache_hit_tokens":
                        cacheHit = Int(sqlite3_column_int64(stmt, Int32(idx)))
                    case "cache_miss_tokens":
                        cacheMiss = Int(sqlite3_column_int64(stmt, Int32(idx)))
                    case "total_cost_usd":
                        costUSD = Double(String(cString: sqlite3_column_text(stmt, Int32(idx))))
                    case "request_id":
                        requestID = String(cString: sqlite3_column_text(stmt, Int32(idx)))
                    default: break
                    }
                    idx += 1
                }

                records.append(UsageRecord(
                    timestamp: timestamp,
                    model: model,
                    totalTokens: inputT + outputT + cacheHit + cacheMiss,
                    cost: costUSD,
                    cacheHitTokens: cacheHit > 0 ? cacheHit : nil,
                    cacheMissTokens: cacheMiss > 0 ? cacheMiss : nil,
                    completionTokens: outputT > 0 ? outputT : nil,
                    promptTokens: inputT > 0 ? inputT : nil,
                    requestID: requestID
                ))
            }

            if skipped > 0 { logger.warning("跳过 \(skipped) 条时间戳解析失败的记录") }
            logger.info("CC Switch: 读取 \(records.count) 条记录")
            return records
        }.value
    }

    func readDeepSeekAPIKey() async throws -> (key: String, baseURL: String)? {
        guard isAvailable() else { return nil }

        let path = dbPath
        return try await Task.detached {
            var db: OpaquePointer?
            guard sqlite3_open(path, &db) == SQLITE_OK, let db = db else {
                logger.error("无法打开 CC Switch 数据库")
                return nil
            }
            defer { sqlite3_close(db) }
            sqlite3_busy_timeout(db, 2000)

            let sql = "SELECT api_key, base_url FROM providers WHERE name LIKE '%deepseek%' LIMIT 1"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logger.error("查询 providers 失败: \(String(cString: sqlite3_errmsg(db)))")
                return nil
            }
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_step(stmt) == SQLITE_ROW,
                  sqlite3_column_type(stmt, 0) != SQLITE_NULL
            else { return nil }

            let key = String(cString: sqlite3_column_text(stmt, 0))
            let base = sqlite3_column_type(stmt, 1) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(stmt, 1))
                : "https://api.deepseek.com"

            return (key, base)
        }.value
    }

    func latestRequestTimestamp() async throws -> Date? {
        guard isAvailable() else { return nil }

        let path = dbPath
        return try await Task.detached {
            var db: OpaquePointer?
            guard sqlite3_open(path, &db) == SQLITE_OK, let db = db else {
                logger.error("无法打开 CC Switch 数据库")
                return nil
            }
            defer { sqlite3_close(db) }
            sqlite3_busy_timeout(db, 2000)

            let columns = discoverColumns(db)
            let col = buildColumnMap(columns: columns)
            guard let tsInfo = col["timestamp"] else { return nil }

            let sql = "SELECT MAX(`\(tsInfo.name)`) FROM proxy_request_logs"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else { return nil }
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_step(stmt) == SQLITE_ROW,
                  sqlite3_column_type(stmt, 0) != SQLITE_NULL
            else { return nil }

            return parseTimestamp(stmt, col: 0, type: tsInfo.type)
        }.value
    }
}
