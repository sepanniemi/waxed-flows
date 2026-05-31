import Foundation

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let elapsedMillis: Int
    let speedKmh: Double?

    init(latitude: Double, longitude: Double, altitude: Double,
         elapsedMillis: Int, speedKmh: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.elapsedMillis = elapsedMillis
        self.speedKmh = speedKmh
    }
}
