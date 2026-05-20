import SwiftUI

struct MonthPickerView: View {
    @Binding var selectedMonth: Date
    let label: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onReset: () -> Void

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var canGoNext: Bool {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? Date.distantPast
        return nextMonth <= Date()
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(minWidth: 90)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(!canGoNext)
            .opacity(canGoNext ? 1 : 0.3)

            if !isCurrentMonth {
                Button("回到本月") {
                    onReset()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
    }
}
