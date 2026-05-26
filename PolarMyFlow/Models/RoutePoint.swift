import Foundation

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let elapsedMillis: Int
    let speedKmh: Double?
}
