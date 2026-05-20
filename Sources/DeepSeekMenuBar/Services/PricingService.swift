import Foundation

struct PricingService {
    struct PriceTier {
        let cacheHitPerMillion: Double
        let cacheMissPerMillion: Double
        let outputPerMillion: Double
    }

    private static let flashPrice = PriceTier(
        cacheHitPerMillion: 0.0028,
        cacheMissPerMillion: 0.14,
        outputPerMillion: 0.28
    )

    private static let proPrice = PriceTier(
        cacheHitPerMillion: 0.0145,
        cacheMissPerMillion: 1.74,
        outputPerMillion: 3.48
    )

    private static let proDiscountedPrice = PriceTier(
        cacheHitPerMillion: 0.003625,
        cacheMissPerMillion: 0.435,
        outputPerMillion: 0.87
    )

    static let usdToCNY: Double = 7.2

    private static let discountEndDate: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 31
        comps.hour = 15
        comps.minute = 59
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: comps) ?? Date.distantFuture
    }()

    static func modelDisplayName(_ model: String) -> String {
        switch model.lowercased() {
        case "deepseek-v4-flash": return "V4 Flash"
        case "deepseek-v4-pro": return "V4 Pro"
        case "deepseek-chat": return "V3 Chat"
        case "deepseek-reasoner": return "R1 Reasoner"
        case "deepseek-r1": return "R1"
        case "deepseek-v3": return "V3"
        default: return model
        }
    }

    static func priceTier(for model: String) -> PriceTier {
        let lowercased = model.lowercased()
        if lowercased == "deepseek-v4-pro" {
            return Date() < discountEndDate ? proDiscountedPrice : proPrice
        }
        return flashPrice
    }

    static func estimateCost(
        model: String,
        promptTokens: Int,
        completionTokens: Int,
        cacheHitTokens: Int,
        cacheMissTokens: Int
    ) -> Double {
        let tier = priceTier(for: model)
        let hitCost = Double(cacheHitTokens) / 1_000_000 * tier.cacheHitPerMillion
        let missCost = Double(cacheMissTokens) / 1_000_000 * tier.cacheMissPerMillion
        let rawUncategorized = promptTokens - cacheHitTokens - cacheMissTokens
        let uncategorizedPrompt = Double(max(0, rawUncategorized))
        let promptCost = uncategorizedPrompt / 1_000_000 * tier.cacheMissPerMillion
        let completionCost = Double(completionTokens) / 1_000_000 * tier.outputPerMillion
        return hitCost + missCost + promptCost + completionCost
    }
}
