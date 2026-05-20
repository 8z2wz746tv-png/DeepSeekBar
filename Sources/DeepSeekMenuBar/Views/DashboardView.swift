import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(
                onRefresh: { viewModel.refreshBalance() },
                onSettings: onOpenSettings,
                isRefreshing: viewModel.balanceStore.isRefreshing,
                progress: viewModel.balanceStore.refreshProgress
            )
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if viewModel.needsSetup {
                SetupGuideView(onOpenSettings: onOpenSettings)
            } else {
                content
            }
        }
        .frame(width: AppTheme.panelWidth, height: AppTheme.panelHeight)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let error = viewModel.errorMessage {
                    MessageBanner(text: error, type: .error) {
                        viewModel.errorMessage = nil
                    }
                }
                if let success = viewModel.successMessage {
                    MessageBanner(text: success, type: .success) {
                        viewModel.successMessage = nil
                    }
                }

                OverviewSection(
                    balance: formattedBalance,
                    currency: viewModel.balanceStore.balanceInfos.first?.currency ?? "CNY",
                    monthlySpend: viewModel.currentMonthSpend,
                    requests: viewModel.currentMonthRequestCount,
                    tokens: viewModel.currentMonthTokens,
                    selectedModel: viewModel.selectedModel.flatMap { PricingService.modelDisplayName($0) },
                    lastRefresh: viewModel.balanceStore.lastRefresh,
                    ccSwitchStatus: viewModel.usageStore.ccSwitchStatus
                )

                MonthPickerView(
                    selectedMonth: $viewModel.selectedMonth,
                    label: viewModel.selectedMonthLabel,
                    onPrevious: { viewModel.goToPreviousMonth() },
                    onNext: { viewModel.goToNextMonth() },
                    onReset: { viewModel.resetToCurrentMonth() }
                )

                ChartSection(
                    points: viewModel.trendPoints,
                    selectedModel: viewModel.selectedModel,
                    onSelectAllModels: { viewModel.selectModel(nil) }
                )

                ModelListSection(
                    summaries: viewModel.modelSummaries,
                    selectedModel: viewModel.selectedModel,
                    onSelect: { viewModel.selectModel($0) }
                )
            }
            .padding(12)
        }
    }

    private var formattedBalance: String {
        guard !viewModel.balanceStore.balanceInfos.isEmpty else { return "—" }
        if let cny = viewModel.balanceStore.balanceInfos.first(where: { $0.currency == "CNY" }) {
            return String(format: "%.2f", cny.totalBalanceValue)
        }
        let first = viewModel.balanceStore.balanceInfos.first
        return String(format: "%.2f", first?.totalBalanceValue ?? 0)
    }
}

// MARK: - Message banner

private struct MessageBanner: View {
    let text: String
    let type: BannerType
    let onDismiss: () -> Void

    enum BannerType {
        case error, success
    }

    var body: some View {
        HStack {
            Image(systemName: type == .error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(type == .error ? .red : .green)
            Text(text)
                .font(.caption)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(type == .error ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
