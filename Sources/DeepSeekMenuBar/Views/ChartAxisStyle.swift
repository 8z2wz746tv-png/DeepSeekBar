import SwiftUI
import Charts

struct ChartAxisStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if value.as(Date.self) != nil {
                        AxisValueLabel(format: .dateTime.day())
                            .font(.caption2)
                        AxisGridLine()
                    }
                }
            }
            .chartYAxis {
                AxisMarks {
                    AxisValueLabel()
                        .font(.caption2)
                    AxisGridLine()
                }
            }
    }
}

extension View {
    func chartAxisStyle() -> some View {
        modifier(ChartAxisStyle())
    }
}
