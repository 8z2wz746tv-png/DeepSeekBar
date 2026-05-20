import SwiftUI

struct ModelListSection: View {
    let summaries: [ModelSummary]
    let selectedModel: String?
    let onSelect: (String) -> Void

    @State private var isExpanded = false

    private var visibleSummaries: [ModelSummary] {
        if isExpanded || summaries.count <= 1 {
            return summaries
        }
        return Array(summaries.prefix(1))
    }

    var body: some View {
        if summaries.isEmpty {
            EmptyStateView(
                icon: "cube.box",
                title: "暂无模型数据",
                subtitle: "开始使用 DeepSeek API 后，这里会显示各模型的使用统计"
            )
        } else {
            VStack(spacing: 0) {
                ForEach(Array(visibleSummaries.enumerated()), id: \.element.id) { index, summary in
                    ModelRow(
                        summary: summary,
                        index: index,
                        isSelected: selectedModel == summary.model,
                        onSelect: { onSelect(summary.model) }
                    )
                    if index < visibleSummaries.count - 1 {
                        Divider().padding(.leading, 28)
                    }
                }

                if summaries.count > 1 && !isExpanded {
                    Divider().padding(.leading, 8)
                    Button("展开全部 (\(summaries.count - 1) 个)") {
                        isExpanded = true
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                }
            }
            .cardStyle()
        }
    }
}

private struct ModelRow: View {
    let summary: ModelSummary
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                ModelColorDot(index: index)

                Text(summary.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Text("\(summary.requestCount) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(format: "¥%.2f", summary.totalCost))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
