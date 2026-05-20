import Foundation
import Combine
import OSLog

/// UI 状态与协调器 —— 余额/用量逻辑已拆分到 BalanceStore / UsageStore
@MainActor
final class DashboardViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.deepseek.menubar", category: "DashboardVM")

    let balanceStore = BalanceStore()
    let usageStore = UsageStore()
    private let polling = PollingManager()

    @Published var selectedModel: String?
    @Published var selectedMonth: Date = Date()
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var needsSetup: Bool {
        KeychainService().load() == nil && usageStore.records.isEmpty
    }

    var selectedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: selectedMonth)
    }

    var modelSummaries: [ModelSummary] {
        UsageAggregator.modelSummaries(records: usageStore.records, month: selectedMonth)
            .filter { model in
                let m = model.model.lowercased()
                return m == "deepseek-v4-pro" || m == "deepseek-v4-flash"
            }
    }

    var trendPoints: [TrendPoint] {
        let points = UsageAggregator.trendPoints(records: usageStore.records, month: selectedMonth)
        if let model = selectedModel {
            return points.filter { $0.model == model }
        }
        return points
    }

    var currentMonthSpend: String {
        let amount: Double
        if let model = selectedModel {
            amount = UsageAggregator.spendForModel(records: usageStore.records, model: model, month: selectedMonth)
        } else {
            let recordSpend = UsageAggregator.monthlySpend(records: usageStore.records, month: selectedMonth)
            if recordSpend > 0 {
                amount = recordSpend
            } else {
                amount = UsageAggregator.estimateSpendFromSnapshots(snapshots: balanceStore.snapshots, month: selectedMonth)
            }
        }
        return String(format: "¥%.2f", amount)
    }

    var currentMonthRequestCount: String {
        let count: Int
        if let model = selectedModel {
            count = UsageAggregator.requestCountForModel(records: usageStore.records, model: model, month: selectedMonth)
        } else {
            count = UsageAggregator.monthlyRequestCount(records: usageStore.records, month: selectedMonth)
        }
        return "\(count)"
    }

    var currentMonthTokens: String {
        let tokens = selectedModel.map {
            UsageAggregator.tokensForModel(records: usageStore.records, model: $0, month: selectedMonth)
        } ?? UsageAggregator.monthlyTokens(records: usageStore.records, month: selectedMonth)
        return FormatUtils.tokens(tokens)
    }

    func onAppear() {
        usageStore.loadPersisted()
        balanceStore.balanceInfos = usageStore.loadBalanceFromPersisted()
        balanceStore.snapshots = usageStore.loadSnapshotsFromPersisted()
        balanceStore.lastRefresh = usageStore.loadLastUpdatedFromPersisted()
        balanceStore.lastNotifiedBalance = usageStore.loadLastNotifiedBalanceFromPersisted()
        balanceStore.lastNotificationHour = usageStore.loadLastNotificationHourFromPersisted()
        usageStore.updateCCSwitchStatus()
        startPolling()
    }

    func refreshBalance() {
        Task {
            do {
                try await balanceStore.refresh()
                usageStore.savePersisted(
                    balanceInfos: balanceStore.balanceInfos,
                    snapshots: balanceStore.snapshots,
                    lastNotifiedBalance: balanceStore.lastNotifiedBalance,
                    lastNotificationHour: balanceStore.lastNotificationHour
                )
                errorMessage = nil
                successMessage = "余额已更新"
            } catch {
                logger.error("余额刷新失败: \(error.localizedDescription)")
                errorMessage = (error as? DeepSeekAPIError)?.errorDescription ?? (error as? BalanceStoreError)?.errorDescription ?? "刷新失败"
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
        await usageStore.syncFromCCSwitch()
        usageStore.savePersisted(
            balanceInfos: balanceStore.balanceInfos,
            snapshots: balanceStore.snapshots,
            lastNotifiedBalance: balanceStore.lastNotifiedBalance,
            lastNotificationHour: balanceStore.lastNotificationHour
        )
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
}
