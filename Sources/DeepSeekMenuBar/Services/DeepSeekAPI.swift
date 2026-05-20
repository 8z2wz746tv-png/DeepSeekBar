import Foundation

protocol DeepSeekAPIProtocol {
    func fetchBalance(apiKey: String) async throws -> DeepSeekBalanceResponse
}

struct DeepSeekAPI: DeepSeekAPIProtocol {
    private let baseURL = "https://api.deepseek.com"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    func fetchBalance(apiKey: String) async throws -> DeepSeekBalanceResponse {
        guard let url = URL(string: "\(baseURL)/user/balance") else {
            throw DeepSeekAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        let data: Data
        let httpResponse: HTTPURLResponse

        do {
            (data, httpResponse) = try await {
                let (d, r) = try await session.data(for: request)
                guard let hr = r as? HTTPURLResponse else {
                    throw DeepSeekAPIError.invalidResponse
                }
                return (d, hr)
            }()
        } catch let error as DeepSeekAPIError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw DeepSeekAPIError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw DeepSeekAPIError.networkUnavailable
            default:
                throw DeepSeekAPIError.networkError(error.localizedDescription)
            }
        } catch {
            throw DeepSeekAPIError.networkError(error.localizedDescription)
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw DeepSeekAPIError.unauthorized
            }
            throw DeepSeekAPIError.httpError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(DeepSeekBalanceResponse.self, from: data)
        } catch {
            let rawJSON = String(data: data, encoding: .utf8) ?? "<无法读取>"
            throw DeepSeekAPIError.decodeError(rawJSON)
        }
    }
}

enum DeepSeekAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case timeout
    case networkUnavailable
    case networkError(String)
    case decodeError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 API 地址"
        case .invalidResponse: return "无效的服务器响应"
        case .unauthorized: return "API Key 无效，请在设置中重新配置"
        case .httpError(let code): return "服务器错误 (HTTP \(code))"
        case .timeout: return "请求超时，网络较慢"
        case .networkUnavailable: return "网络不可用"
        case .networkError(let msg): return "网络错误: \(msg)"
        case .decodeError(let raw): return "API 返回格式不匹配\n\n\(raw)"
        }
    }
}
