import SwiftUI
import Charts

enum ChartMode: String, CaseIterable {
    case spend = "消费"
    case tokens = "Token"
    case requests = "请求"
    case cacheBreakdown = "缓存"

    var icon: String {
        switch self {
        case .spend: return "yensign.circle"
        case .tokens: return "text.alignleft"
        case .requests: return "number"
        case .cacheBreakdown: return "square.split.2x2"
        }
    }
}

struct ChartSection: View {
    let points: [TrendPoint]
    let selectedModel: String?
    let onSelectAllModels: () -> Void

    @State private var selectedMode: ChartMode = .spend
    @State private var selectedDate: Date?
    @State private var selectedPoint: TrendPoint?
    @State private var selectedValue: Double?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("图表类型", selection: $selectedMode) {
                    ForEach(ChartMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if selectedModel != nil {
                    Button("全部模型") {
                        onSelectAllModels()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }

            if points.isEmpty {
                EmptyStateView(
                    icon: "chart.xyaxis.line",
                    title: "暂无数据",
                    subtitle: "使用 DeepSeek API 后这里将显示趋势图表"
                )
                .frame(height: AppTheme.chartHeight)
            } else {
                chartContent
                    .frame(height: AppTheme.chartHeight)
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 8)
                                        .onChanged { value in
                                            updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                        }
                                        .onEnded { _ in
                                            selectedDate = nil
                                            selectedPoint = nil
                                            selectedValue = nil
                                        }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let point = selectedPoint {
                            ChartTooltip(
                                date: point.date,
                                cost: point.cost,
                                tokens: point.tokens,
                                requests: point.requestCount,
                                cacheHit: point.cacheHitTokens,
                                cacheMiss: point.cacheMissTokens,
                                completionTokens: point.completionTokens,
                                mode: tooltipMode
                            )
                            .padding(8)
                        }
                    }

                if selectedMode == .cacheBreakdown {
                    HStack(spacing: 16) {
                        legendItem(color: .green, label: "缓存命中")
                        legendItem(color: .blue, label: "缓存未命中")
                        legendItem(color: .orange, label: "输出 Token")
                    }
                    .font(.caption2)
                }
            }
        }
    }

    // MARK: - Chart content

    @ViewBuilder
    private var chartContent: some View {
        switch selectedMode {
        case .spend: spendChart
        case .tokens: tokensChart
        case .requests: requestsChart
        case .cacheBreakdown: cacheChart
        }
    }

    private var spendChart: some View {
        let aggregated = aggregateByDate(points) { $0.cost }
        return Chart {
            ForEach(aggregated, id: \.date) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("消费", point.value)
                )
                .foregroundStyle(Color.accentColor.gradient)
            }
            hoverMarks
        }
        .chartAxisStyle()
    }

    private var tokensChart: some View {
        let aggregated = aggregateByDate(points) { Double($0.tokens) }
        return Chart {
            ForEach(aggregated, id: \.date) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("Token", point.value)
                )
                .foregroundStyle(Color.purple.gradient)
            }
            hoverMarks
        }
        .chartAxisStyle()
    }

    private var requestsChart: some View {
        let aggregated = aggregateByDate(points) { Double($0.requestCount) }
        return Chart {
            ForEach(aggregated, id: \.date) { point in
                LineMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("请求数", point.value)
                )
                .foregroundStyle(Color.orange)
                .symbol(Circle())
            }
            hoverMarks
        }
        .chartAxisStyle()
    }

    private var cacheChart: some View {
        let aggregated = aggregateCacheByDate(points)
        return Chart {
            ForEach(aggregated, id: \.date) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("Token", point.hit)
                )
                .foregroundStyle(Color.green)
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("Token", point.miss)
                )
                .foregroundStyle(Color.blue)
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("Token", point.completion)
                )
                .foregroundStyle(Color.orange)
            }
            hoverMarks
        }
        .chartAxisStyle()
    }

    @ChartContentBuilder
    private var hoverMarks: some ChartContent {
        if let date = selectedDate, let value = selectedValue {
            RuleMark(x: .value("选中", date, unit: .day))
                .foregroundStyle(Color.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))

            PointMark(
                x: .value("选中", date, unit: .day),
                y: .value("数值", value)
            )
            .foregroundStyle(Color.accentColor)
            .symbolSize(36)
        }
    }

    // MARK: - Tooltip selection

    private var tooltipMode: ChartTooltip.ChartTooltipMode {
        switch selectedMode {
        case .spend: return .spend
        case .tokens: return .tokens
        case .requests: return .requests
        case .cacheBreakdown: return .cacheBreakdown
        }
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let date: Date = proxy.value(atX: location.x) else { return }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let dayPoints = points.filter { calendar.isDate($0.date, inSameDayAs: day) }

        guard !dayPoints.isEmpty else { return }

        if let current = selectedDate, calendar.isDate(current, inSameDayAs: day) { return }

        let aggregated = TrendPoint(
            date: day,
            model: selectedModel ?? "all",
            cost: dayPoints.reduce(0) { $0 + $1.cost },
            tokens: dayPoints.reduce(0) { $0 + $1.tokens },
            requestCount: dayPoints.reduce(0) { $0 + $1.requestCount },
            cacheHitTokens: dayPoints.reduce(0) { $0 + $1.cacheHitTokens },
            cacheMissTokens: dayPoints.reduce(0) { $0 + $1.cacheMissTokens },
            completionTokens: dayPoints.reduce(0) { $0 + $1.completionTokens }
        )

        selectedDate = day
        selectedPoint = aggregated

        switch selectedMode {
        case .spend: selectedValue = aggregated.cost
        case .tokens: selectedValue = Double(aggregated.tokens)
        case .requests: selectedValue = Double(aggregated.requestCount)
        case .cacheBreakdown:
            selectedValue = Double(aggregated.cacheHitTokens + aggregated.cacheMissTokens + aggregated.completionTokens)
        }
    }

    // MARK: - Aggregation helpers

    private struct AggPoint {
        let date: Date
        let value: Double
    }

    private struct CacheAggPoint {
        let date: Date
        let hit: Double
        let miss: Double
        let completion: Double
    }

    private func aggregateByDate(_ points: [TrendPoint], value: (TrendPoint) -> Double) -> [AggPoint] {
        let grouped = Dictionary(grouping: points) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.map { date, pts in AggPoint(date: date, value: pts.reduce(0) { $0 + value($1) }) }
            .sorted { $0.date < $1.date }
    }

    private func aggregateCacheByDate(_ points: [TrendPoint]) -> [CacheAggPoint] {
        let grouped = Dictionary(grouping: points) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.map { date, pts in
            CacheAggPoint(
                date: date,
                hit: Double(pts.reduce(0) { $0 + $1.cacheHitTokens }),
                miss: Double(pts.reduce(0) { $0 + $1.cacheMissTokens }),
                completion: Double(pts.reduce(0) { $0 + $1.completionTokens })
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundColor(.secondary)
        }
    }
}
