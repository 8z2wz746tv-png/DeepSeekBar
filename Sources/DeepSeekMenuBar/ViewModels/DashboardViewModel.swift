import Foundation
import Combine
import OSLog

@MainActor
final class DashboardViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.deepseek.menubar", category: "DashboardVM")

    // MARK: - Dependencies
    private let api = DeepSeekAPI()
    private let keychain = KeychainService()
    private let ccSwitch = CCSwitchService()
    private let persistence = PersistenceService()
    private let notification = NotificationService()
    private let polling = PollingManager()

    // MARK: - Published state
    @Published var balanceInfos: [BalanceInfo] = []
    @Published var records: [UsageRecord] = []
    @Published var snapshots: [BalanceSnapshot] = []
    @Published var selectedModel: String?
    @Published var selectedMonth: Date = Date()
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var refreshProgress = ""
    @Published var ccSwitchStatus = "—"
    @Published var lastBalanceRefresh: Date?
    @Published var lastNotifiedBalance: Double?
    @Published var lastNotificationHour: Int?

    private static let maxRecords = 10_000

    // MARK: - Computed properties
    var needsSetup: Bool {
        keychain.load() == nil && records.isEmpty
    }

    var selectedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: selectedMonth)
    }

    var modelSummaries: [ModelSummary] {
        UsageAggregator.modelSummaries(records: records, month: selectedMonth)
            .filter { model in
                let m = model.model.lowercased()
                return m == "deepseek-v4-pro" || m == "deepseek-v4-flash"
            }
    }

    var trendPoints: [TrendPoint] {
        let points = UsageAggregator.trendPoints(records: records, month: selectedMonth)
        if let model = selectedModel {
            return points.filter { $0.model == model }
        }
        return points
    }

    var currentMonthSpend: String {
        let amount: Double
        if let model = selectedModel {
            amount = UsageAggregator.spendForModel(records: records, model: model, month: selectedMonth)
        } else {
            let recordSpend = UsageAggregator.monthlySpend(records: records, month: selectedMonth)
            if recordSpend > 0 {
                amount = recordSpend
            } else {
                amount = UsageAggregator.estimateSpendFromSnapshots(snapshots: snapshots, month: selectedMonth)
            }
        }
        return String(format: "¥%.2f", amount)
    }

    var currentMonthRequestCount: String {
        let count: Int
        if let model = selectedModel {
            count = UsageAggregator.requestCountForModel(records: records, model: model, month: selectedMonth)
        } else {
            count = UsageAggregator.monthlyRequestCount(records: records, month: selectedMonth)
        }
        return "\(count)"
    }

    var currentMonthTokens: String {
        let tokens = selectedModel.map {
            UsageAggregator.tokensForModel(records: records, model: $0, month: selectedMonth)
        } ?? UsageAggregator.monthlyTokens(records: records, month: selectedMonth)
        return FormatUtils.tokens(tokens)
    }

    // MARK: - Inputs
    func onAppear() {
        loadPersistedState()
        ccSwitchStatus = ccSwitch.isAvailable() ? "已连接" : "未开启"
        startPolling()
    }

    func refreshBalance() {
        isRefreshing = true
        errorMessage = nil
        refreshProgress = "刷新中..."

        // 12 秒后显示"网络较慢"提示
        let slowTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else { return }
            refreshProgress = "网络较慢..."
        }

        Task {
            defer { slowTask.cancel() }
            do {
                guard let apiKey = keychain.load(), !apiKey.isEmpty else {
                    errorMessage = "请先在设置中配置 API Key"
                    isRefreshing = false
                    refreshProgress = ""
                    return
                }

                let response = try await api.fetchBalance(apiKey: apiKey)
                balanceInfos = response.balanceInfos
                lastBalanceRefresh = Date()

                let cnyBalance = balanceInfos.first(where: { $0.currency == "CNY" })?.totalBalanceValue
                    ?? balanceInfos.first?.totalBalanceValue
                    ?? 0

                addSnapshot(balance: cnyBalance, currency: "CNY")
                savePersistedState()

                checkLowBalanceNotification(currentBalance: cnyBalance)

                isRefreshing = false
                refreshProgress = ""
                successMessage = "余额已更新"
            } catch {
                logger.error("余额刷新失败: \(error.localizedDescription)")
                errorMessage = (error as? DeepSeekAPIError)?.errorDescription ?? "刷新失败"
                isRefreshing = false
                refreshProgress = ""
            }
        }
    }

    func selectModel(_ model: String?) {
        selectedModel = selectedModel == model ? nil : model
    }

    func goToPreviousMonth() {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) else { return }
        selectedMonth = newMonth
    }

    func goToNextMonth() {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) else { return }
        if newMonth <= Date() { selectedMonth = newMonth }
    }

    func resetToCurrentMonth() {
        let calendar = Calendar.current
        selectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
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
                savePersistedState()
                successMessage = "已同步 \(dedupedRecords.count) 条记录"
            }

            if AppSettings.perRequestNotificationEnabled {
                notification.sendUsageNotification(records: dedupedRecords)
            }
        } catch {
            logger.error("CC Switch 同步失败: \(error.localizedDescription)")
            errorMessage = "用量同步失败"
        }
    }

    // MARK: - Private
    private func startPolling() {
        let balanceInterval = TimeInterval(AppSettings.refreshIntervalMinutes * 60)
        polling.runBalanceRefresh(interval: balanceInterval) { @MainActor [weak self] in
            self?.refreshBalance()
        }
        polling.runCCSwitchSync { [weak self] in
            await self?.syncFromCCSwitch()
        }
        if AppSettings.perRequestNotificationEnabled {
            polling.runNotificationPoll { [weak self] in
                await self?.syncFromCCSwitch()
            }
        }
    }

    private func loadPersistedState() {
        let state = persistence.load()
        records = state.records
        balanceInfos = state.balanceInfos
        snapshots = state.balanceSnapshots
        lastBalanceRefresh = state.lastUpdated
        lastNotifiedBalance = state.lastNotifiedBalance
        lastNotificationHour = state.lastNotificationHour
    }

    private func savePersistedState() {
        var state = PersistedState()
        state.records = records
        state.balanceInfos = balanceInfos
        state.balanceSnapshots = snapshots
        state.lastUpdated = Date()
        state.lastNotifiedBalance = lastNotifiedBalance
        state.lastNotificationHour = lastNotificationHour
        try? persistence.save(state)
    }

    private func addSnapshot(balance: Double, currency: String) {
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

    private func checkLowBalanceNotification(currentBalance: Double) {
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
        savePersistedState()
    }
}
