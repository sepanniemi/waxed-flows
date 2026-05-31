import XCTest
@testable import PolarMyFlow

final class RoutePointTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let point = RoutePoint(latitude: 64.99879, longitude: 25.61448, altitude: 22.0, elapsedMillis: 14000)
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(RoutePoint.self, from: data)
        XCTAssertEqual(decoded.latitude, point.latitude, accuracy: 0.00001)
        XCTAssertEqual(decoded.longitude, point.longitude, accuracy: 0.00001)
        XCTAssertEqual(decoded.altitude, point.altitude, accuracy: 0.01)
        XCTAssertEqual(decoded.elapsedMillis, point.elapsedMillis)
    }

    func testArrayCodableRoundTrip() throws {
        let points = [
            RoutePoint(latitude: 64.99879, longitude: 25.61448, altitude: 22.0, elapsedMillis: 0),
            RoutePoint(latitude: 65.00001, longitude: 25.61500, altitude: 23.5, elapsedMillis: 5000),
        ]
        let data = try JSONEncoder().encode(points)
        let decoded = try JSONDecoder().decode([RoutePoint].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[1].elapsedMillis, 5000)
    }

    func testSpeedKmhDefaultsNilAndRoundTrips() throws {
        let noSpeed = RoutePoint(latitude: 1, longitude: 2, altitude: 3, elapsedMillis: 4)
        XCTAssertNil(noSpeed.speedKmh)

        let withSpeed = RoutePoint(latitude: 1, longitude: 2, altitude: 3,
                                   elapsedMillis: 4, speedKmh: 16.1)
        let decoded = try JSONDecoder().decode(
            RoutePoint.self, from: JSONEncoder().encode(withSpeed))
        XCTAssertEqual(decoded.speedKmh ?? -1, 16.1, accuracy: 0.001)

        // Backward compatibility: a blob without the key decodes speedKmh as nil.
        let legacy = #"{"latitude":1,"longitude":2,"altitude":3,"elapsedMillis":4}"#
        let legacyDecoded = try JSONDecoder().decode(
            RoutePoint.self, from: Data(legacy.utf8))
        XCTAssertNil(legacyDecoded.speedKmh)
    }
}
