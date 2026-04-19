import XCTest
@testable import PolarMyFlow

final class GDPRTrainingSessionTests: XCTestCase {

    func test_decode_realExportShape_mapsToActivity() throws {
        let json = #"""
        {
            "startTime": "2024-01-01T12:10:25",
            "durationMillis": 5937850,
            "distanceMeters": 8819.0,
            "calories": 754,
            "hrAvg": 112,
            "hrMax": 135,
            "sport": { "id": "3" },
            "exercises": [{ "ascentMeters": 120.5, "descentMeters": 115.0 }]
        }
        """#.data(using: .utf8)!

        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: json)
        let a = try XCTUnwrap(session.toActivity(fileID: "training-session-2024-01-01-x"))

        XCTAssertEqual(a.id, "training-session-2024-01-01-x")
        XCTAssertEqual(a.duration, 5937.85, accuracy: 0.01)
        XCTAssertEqual(a.distance, 8819)
        XCTAssertEqual(a.sportType, .walking)
        XCTAssertEqual(a.sportRawValue, "WALKING")
        XCTAssertEqual(a.avgHeartRate, 112)
        XCTAssertEqual(a.maxHeartRate, 135)
        XCTAssertEqual(a.ascent, 120.5)
        XCTAssertEqual(a.descent, 115.0)
        XCTAssertEqual(a.calories, 754)
        XCTAssertFalse(a.hasRoute)
    }

    func test_decode_missingOptional_stillMaps() throws {
        let json = #"""
        {
            "startTime": "2012-01-02T14:12:53",
            "durationMillis": 3600000,
            "distanceMeters": 5000.0,
            "sport": { "id": "2" },
            "exercises": [{}]
        }
        """#.data(using: .utf8)!

        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: json)
        let a = try XCTUnwrap(session.toActivity(fileID: "id-2012"))
        XCTAssertEqual(a.duration, 3600)
        XCTAssertEqual(a.distance, 5000)
        XCTAssertEqual(a.sportType, .cycling)
        XCTAssertNil(a.avgHeartRate)
        XCTAssertNil(a.maxHeartRate)
        XCTAssertNil(a.calories)
        XCTAssertNil(a.ascent)
        XCTAssertNil(a.descent)
    }

    func test_decode_unknownSportId_mapsToOther() throws {
        let json = #"""
        {
            "startTime": "2025-05-01T12:00:00",
            "durationMillis": 1800000,
            "sport": { "id": "99999" },
            "exercises": []
        }
        """#.data(using: .utf8)!

        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: json)
        let a = try XCTUnwrap(session.toActivity(fileID: "id"))
        XCTAssertEqual(a.sportType, .other)
        XCTAssertEqual(a.sportRawValue, "OTHER")
    }

    func test_decode_zeroDuration_returnsNilFromMapper() throws {
        let json = #"""
        {
            "startTime": "2025-01-01T00:00:00",
            "durationMillis": 0,
            "sport": { "id": "1" }
        }
        """#.data(using: .utf8)!
        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: json)
        XCTAssertNil(session.toActivity(fileID: "id"))
    }

    func test_decode_invalidStartTime_returnsNilFromMapper() throws {
        let json = #"""
        {
            "startTime": "not-a-date",
            "durationMillis": 3600000,
            "sport": { "id": "1" }
        }
        """#.data(using: .utf8)!
        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: json)
        XCTAssertNil(session.toActivity(fileID: "id"))
    }
}
