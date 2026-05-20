import SwiftUI

struct ChartTooltip: View {
    let date: Date
    let cost: Double
    let tokens: Int
    let requests: Int
    let cacheHit: Int
    let cacheMiss: Int
    let completionTokens: Int
    let mode: ChartTooltipMode

    enum ChartTooltipMode {
        case spend, tokens, requests, cacheBreakdown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate)
                .font(.caption)
                .fontWeight(.medium)

            Divider()

            switch mode {
            case .spend:
                Text(String(format: "¥%.4f", cost))
                    .font(.caption).monospacedDigit()
            case .tokens:
                Text(FormatUtils.tokens(tokens))
                    .font(.caption).monospacedDigit()
            case .requests:
                Text("\(requests) 次")
                    .font(.caption).monospacedDigit()
            case .cacheBreakdown:
                VStack(alignment: .leading, spacing: 2) {
                    LabeledValue(label: "命中", value: FormatUtils.tokens(cacheHit), color: .green)
                    LabeledValue(label: "未命中", value: FormatUtils.tokens(cacheMiss), color: .blue)
                    LabeledValue(label: "输出", value: FormatUtils.tokens(completionTokens), color: .orange)
                }
                .font(.caption)
            }
        }
        .padding(8)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(radius: 4)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(label): \(value)")
        }
    }
}
