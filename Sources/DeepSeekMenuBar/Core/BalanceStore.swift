import Foundation
import OSLog

/// 管理余额获取、快照记录和低余额通知
@MainActor
final class BalanceStore: ObservableObject {
    private let logger = Logger(subsystem: "com.deepseek.menubar", category: "BalanceStore")

    private let api = DeepSeekAPI()
    private let keychain = KeychainService()
    private let notification = NotificationService()

    @Published var balanceInfos: [BalanceInfo] = []
    @Published var snapshots: [BalanceSnapshot] = []
    @Published var lastRefresh: Date?
    @Published var isRefreshing = false
    @Published var refreshProgress = ""

    var lastNotifiedBalance: Double?
    var lastNotificationHour: Int?

    func refresh() async throws {
        isRefreshing = true
        refreshProgress = "刷新中..."

        let slowTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else { return }
            refreshProgress = "网络较慢..."
        }
        defer { slowTask.cancel() }

        guard let apiKey = keychain.load(), !apiKey.isEmpty else {
            isRefreshing = false
            refreshProgress = ""
            throw BalanceStoreError.missingAPIKey
        }

        let response = try await api.fetchBalance(apiKey: apiKey)
        balanceInfos = response.balanceInfos
        lastRefresh = Date()

        let cnyBalance = balanceInfos.first(where: { $0.currency == "CNY" })?.totalBalanceValue
            ?? balanceInfos.first?.totalBalanceValue
            ?? 0

        addSnapshot(balance: cnyBalance, currency: "CNY")
        checkLowBalanceNotification(currentBalance: cnyBalance)

        isRefreshing = false
        refreshProgress = ""
    }

    func addSnapshot(balance: Double, currency: String) {
        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-300)

        if let last = snapshots.last,
           abs(last.totalBalance - balance) < 0.001,
           last.timestamp > fiveMinutesAgo {
            return
        }

        snapshots.append(BalanceSnapshot(timestamp: now, totalBalance: balance, currency: currency))
        if snapshots.count > 500 {
            snapshots.removeFirst(snapshots.count - 500)
        }
    }

    func checkLowBalanceNotification(currentBalance: Double) {
        guard AppSettings.lowBalanceNotificationEnabled,
              currentBalance < AppSettings.lowBalanceThreshold
        else {
            if currentBalance >= AppSettings.lowBalanceThreshold {
                lastNotifiedBalance = nil
                lastNotificationHour = nil
            }
            return
        }

        if let last = lastNotifiedBalance, abs(currentBalance - last) < 0.001 { return }

        let currentHour = Calendar.current.component(.hour, from: Date())
        if let lastHour = lastNotificationHour, lastHour == currentHour { return }

        notification.sendLowBalanceNotification(
            balance: currentBalance,
            threshold: AppSettings.lowBalanceThreshold
        )
        lastNotifiedBalance = currentBalance
        lastNotificationHour = currentHour
    }
}

enum BalanceStoreError: LocalizedError {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "请先在设置中配置 API Key"
        }
    }
}
