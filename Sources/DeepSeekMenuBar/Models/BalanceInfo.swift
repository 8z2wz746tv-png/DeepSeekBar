import Foundation

struct BalanceInfo: Codable, Equatable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }

    var totalBalanceValue: Double {
        Double(totalBalance) ?? 0
    }

    var isZero: Bool {
        abs(totalBalanceValue) < 0.001
    }
}

struct DeepSeekBalanceResponse: Codable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}
