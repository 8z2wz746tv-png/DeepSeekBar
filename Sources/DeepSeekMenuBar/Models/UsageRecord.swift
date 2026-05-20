import Foundation

struct UsageRecord: Codable, Identifiable, Equatable {
    let timestamp: Date
    let model: String
    let totalTokens: Int
    let cost: Double?
    let cacheHitTokens: Int?
    let cacheMissTokens: Int?
    let completionTokens: Int?
    let promptTokens: Int?
    let requestID: String?

    var id: String {
        if let reqID = requestID, !reqID.isEmpty {
            return reqID
        }
        return "\(timestamp.timeIntervalSince1970)-\(model)-\(totalTokens)-\(cost ?? 0)"
    }

    enum CodingKeys: String, CodingKey {
        case timestamp, model, cost
        case totalTokens = "total_tokens"
        case cacheHitTokens = "cache_hit_tokens"
        case cacheMissTokens = "cache_miss_tokens"
        case completionTokens = "completion_tokens"
        case promptTokens = "prompt_tokens"
        case requestID = "request_id"
    }
}
