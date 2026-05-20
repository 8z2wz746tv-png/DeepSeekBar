import Foundation
import OSLog

/// 管理用量记录、cc-switch 同步和本地持久化
@MainActor
final class UsageStore: ObservableObject {
    private let logger = Logger(subsystem: "com.deepseek.menubar", category: "UsageStore")

    private let ccSwitch = CCSwitchService()
    private let persistence = PersistenceService()
    private let notification = NotificationService()

    @Published var records: [UsageRecord] = []
    @Published var ccSwitchStatus = "—"

    private static let maxRecords = 10_000

    func loadPersisted() {
        let state = persistence.load()
        records = state.records
    }

    func savePersisted(
        balanceInfos: [BalanceInfo],
        snapshots: [BalanceSnapshot],
        lastNotifiedBalance: Double?,
        lastNotificationHour: Int?
    ) {
        var state = PersistedState()
        state.records = records
        state.balanceInfos = balanceInfos
        state.balanceSnapshots = snapshots
        state.lastUpdated = Date()
        state.lastNotifiedBalance = lastNotifiedBalance
        state.lastNotificationHour = lastNotificationHour
        try? persistence.save(state)
    }

    func loadBalanceFromPersisted() -> [BalanceInfo] {
        persistence.load().balanceInfos
    }

    func loadSnapshotsFromPersisted() -> [BalanceSnapshot] {
        persistence.load().balanceSnapshots
    }

    func loadLastUpdatedFromPersisted() -> Date? {
        persistence.load().lastUpdated
    }

    func loadLastNotifiedBalanceFromPersisted() -> Double? {
        persistence.load().lastNotifiedBalance
    }

    func loadLastNotificationHourFromPersisted() -> Int? {
        persistence.load().lastNotificationHour
    }

    func updateCCSwitchStatus() {
        ccSwitchStatus = ccSwitch.isAvailable() ? "已连接" : "未开启"
    }

    func syncFromCCSwitch() async {
        guard ccSwitch.isAvailable() else { return }

        do {
            let latest = records.map(\.timestamp).max()
            let newRecords = try await ccSwitch.readRequestLogs(since: latest)

            let existingIDs = Set(records.map(\.id))
            let dedupedRecords = newRecords.filter { !existingIDs.contains($0.id) }
            records.append(contentsOf: dedupedRecords)

            if records.count > Self.maxRecords {
                records = Array(records.suffix(Self.maxRecords))
            }

            if !dedupedRecords.isEmpty {
                logger.info("CC Switch 同步: \(dedupedRecords.count) 条新记录")
            }

            if AppSettings.perRequestNotificationEnabled {
                notification.sendUsageNotification(records: dedupedRecords)
            }
        } catch {
            logger.error("CC Switch 同步失败: \(error.localizedDescription)")
        }
    }
}
