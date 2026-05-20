import Foundation
import OSLog

protocol PersistenceServiceProtocol {
    func load() -> PersistedState
    func save(_ state: PersistedState) throws
}

struct PersistenceService: PersistenceServiceProtocol {
    private let logger = Logger(subsystem: "com.deepseek.menubar", category: "Persistence")

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DeepSeekMenuBar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("usage-history.json")
    }()

    func load() -> PersistedState {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return PersistedState()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PersistedState.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return PersistedState()
        } catch {
            logger.warning("加载持久化数据失败: \(error.localizedDescription)")
            return PersistedState()
        }
    }

    func save(_ state: PersistedState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: storageURL, options: .atomic)
    }
}
