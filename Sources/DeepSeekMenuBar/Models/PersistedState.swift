import Foundation

struct PersistedState: Codable {
    var records: [UsageRecord] = []
    var balanceSnapshots: [BalanceSnapshot] = []
    var lastUpdated: Date?
    var balanceInfos: [BalanceInfo] = []
    var lastNotifiedBalance: Double?
    var lastNotificationHour: Int?
}
