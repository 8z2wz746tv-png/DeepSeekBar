import Foundation

struct ModelSummary: Identifiable {
    let model: String
    let displayName: String
    let requestCount: Int
    let totalCost: Double
    let totalTokens: Int

    var id: String { model }
}
