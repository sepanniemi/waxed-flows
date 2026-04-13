import Foundation

enum APIError: Error, Equatable {
    case httpError(statusCode: Int)
    case decodingFailed
    case networkUnavailable
    case apiChanged(String)
}
