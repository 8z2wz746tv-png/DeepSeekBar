import SwiftUI

struct OverviewSection: View {
    let balance: String
    let currency: String
    let monthlySpend: String
    let requests: String
    let tokens: String
    let selectedModel: String?
    let lastRefresh: Date?
    let ccSwitchStatus: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                OverviewCard(
                    title: "账户余额",
                    value: "\(currency) \(balance)",
                    icon: "wallet.pass.fill"
                )

                OverviewCard(
                    title: selectedModel.map { "\($0) 消费" } ?? "本月消费",
                    value: monthlySpend,
                    icon: "chart.bar.fill"
                )
            }

            HStack(spacing: 8) {
                OverviewCard(
                    title: "请求数",
                    value: requests,
                    icon: "number"
                )

                OverviewCard(
                    title: "Token",
                    value: tokens,
                    icon: "text.alignleft"
                )
            }

            HStack(spacing: 8) {
                if let refresh = lastRefresh {
                    OverviewCard(
                        title: "余额刷新",
                        value: RelativeDateTimeFormatter().localizedString(for: refresh, relativeTo: Date()),
                        icon: "clock"
                    )
                }

                OverviewCard(
                    title: "CC Switch",
                    value: ccSwitchStatus,
                    icon: "antenna.radiowaves.left.and.right"
                )
            }
        }
    }
}

private struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
