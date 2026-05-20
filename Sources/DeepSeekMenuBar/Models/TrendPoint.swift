import Foundation

struct TrendPoint: Identifiable {
    let date: Date
    let model: String
    let cost: Double
    let tokens: Int
    let requestCount: Int
    let cacheHitTokens: Int
    let cacheMissTokens: Int
    let completionTokens: Int

    var id: String { "\(date.timeIntervalSince1970)-\(model)" }
}
