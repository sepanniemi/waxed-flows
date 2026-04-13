import Foundation

enum APIError: Error, Equatable {
    case httpError(statusCode: Int)
    case decodingFailed
    case networkUnavailable
    case apiChanged(String)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .httpError(let code):   return "HTTP \(code)"
        case .decodingFailed:        return "Decode failed"
        case .networkUnavailable:    return "Network unavailable"
        case .apiChanged(let msg):   return "API changed: \(msg)"
        }
    }
}
