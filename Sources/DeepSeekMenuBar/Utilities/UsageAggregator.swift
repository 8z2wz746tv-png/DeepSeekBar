import Foundation

enum UsageAggregator {
    // MARK: - Cost helper

    /// Returns the actual cost in USD. Falls back to PricingService estimation
    /// when the recorded cost is nil or zero.
    private static func effectiveCost(_ record: UsageRecord) -> Double {
        if let cost = record.cost, cost > 0 { return cost }
        return PricingService.estimateCost(
            model: record.model,
            promptTokens: record.promptTokens ?? record.totalTokens,
            completionTokens: record.completionTokens ?? 0,
            cacheHitTokens: record.cacheHitTokens ?? 0,
            cacheMissTokens: record.cacheMissTokens ?? 0
        )
    }

    // MARK: - Model summaries

    static func modelSummaries(records: [UsageRecord], month: Date) -> [ModelSummary] {
        let calendar = Calendar.current
        let monthRecords = records.filter {
            calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month)
        }

        let grouped = Dictionary(grouping: monthRecords, by: \.model)
        return grouped.map { model, recs in
            let totalCost = recs.reduce(0) { sum, r in
                sum + effectiveCost(r) * PricingService.usdToCNY
            }
            return ModelSummary(
                model: model,
                displayName: PricingService.modelDisplayName(model),
                requestCount: recs.count,
                totalCost: totalCost,
                totalTokens: recs.reduce(0) { $0 + $1.totalTokens }
            )
        }
        .sorted { $0.totalCost > $1.totalCost }
    }

    // MARK: - Trend points

    static func trendPoints(records: [UsageRecord], month: Date) -> [TrendPoint] {
        let calendar = Calendar.current
        let monthRecords = records.filter {
            calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month)
        }

        struct GroupKey: Hashable {
            let day: Date
            let model: String
        }

        let grouped = Dictionary(grouping: monthRecords) { record in
            GroupKey(day: calendar.startOfDay(for: record.timestamp), model: record.model)
        }

        return grouped.map { (key, recs) in
            TrendPoint(
                date: key.day,
                model: key.model,
                cost: recs.reduce(0) { $0 + effectiveCost($1) * PricingService.usdToCNY },
                tokens: recs.reduce(0) { $0 + $1.totalTokens },
                requestCount: recs.count,
                cacheHitTokens: recs.reduce(0) { $0 + ($1.cacheHitTokens ?? 0) },
                cacheMissTokens: recs.reduce(0) { $0 + ($1.cacheMissTokens ?? 0) },
                completionTokens: recs.reduce(0) { $0 + ($1.completionTokens ?? 0) }
            )
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Monthly stats

    static func monthlySpend(records: [UsageRecord], month: Date) -> Double {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) }
            .reduce(0) { $0 + effectiveCost($1) * PricingService.usdToCNY }
    }

    static func monthlyTokens(records: [UsageRecord], month: Date) -> Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalTokens }
    }

    static func monthlyRequestCount(records: [UsageRecord], month: Date) -> Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) }
            .count
    }

    // MARK: - Balance snapshot estimation

    static func estimateSpendFromSnapshots(snapshots: [BalanceSnapshot], month: Date) -> Double {
        let calendar = Calendar.current
        let monthSnapshots = snapshots
            .filter { calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) }
            .sorted { $0.timestamp < $1.timestamp }

        guard monthSnapshots.count >= 2,
              let first = monthSnapshots.first,
              let last = monthSnapshots.last else {
            return 0
        }

        return max(0, first.totalBalance - last.totalBalance)
    }

    // MARK: - Stats for a specific model

    static func spendForModel(records: [UsageRecord], model: String, month: Date) -> Double {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) && $0.model == model }
            .reduce(0) { $0 + effectiveCost($1) * PricingService.usdToCNY }
    }

    static func tokensForModel(records: [UsageRecord], model: String, month: Date) -> Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) && $0.model == model }
            .reduce(0) { $0 + $1.totalTokens }
    }

    static func requestCountForModel(records: [UsageRecord], model: String, month: Date) -> Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) && $0.model == model }
            .count
    }
}
