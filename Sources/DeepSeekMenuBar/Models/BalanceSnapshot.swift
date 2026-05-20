import Foundation

struct BalanceSnapshot: Codable, Equatable {
    let timestamp: Date
    let totalBalance: Double
    let currency: String
}
