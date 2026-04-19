import XCTest
@testable import PolarMyFlow

final class GDPRTrainingSessionTests: XCTestCase {

    func test_decode_fullFields_mapsToActivity() throws {
        let json = #"""
        {
            "startTime": "2025-01-15T09:00:00.000",
            "duration": "PT1H30M",
            "distance": 15000.0,
            "sport": "CROSS_COUNTRY_SKIING",
            "exercises": [{
                "sport": "CROSS_COUNTRY_SKIING",
                "startTime": "2025-01-15T09:00:00.000",
                "duration": "PT1H30M",
                "distance": 15000.0,
                "heartRate": { "avg": 142, "max": 170 },
                "calories": 800,
                "ascent": 120.5,
                "descent": 115.0
            }]
        }
        """#.data(using: .utf8)!

        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: json)
        let activity = try XCTUnwrap(session.toActivity(fileID: "training-session-2025-01-15-12345"))

        XCTAssertEqual(activity.id, "training-session-2025-01-15-12345")
        XCTAssertEqual(activity.duration, 5400, accuracy: 0.1)
        XCTAssertEqual(activity.distance, 15000)
        XCTAssertEqual(activity.sportRawValue, "CROSS_COUNTRY_SKIING")
        XCTAssertEqual(activity.avgHeartRate, 142)
        XCTAssertEqual(activity.maxHeartRate, 170)
        XCTAssertEqual(activity.calories, 800)
        XCTAssertEqual(activity.ascent, 120.5)
        XCTAssertEqual(activity.descent, 115.0)
    }

    func test_decode_missingOptionalFields_stillMaps() throws {
        let json = #"""
        {
            "startTime": "2025-03-01T07:00:00.000",
            "duration": "PT45M",
            "sport": "STRENGTH_TRAINING",
            "exercises": [{
                "sport": "STRENGTH_TRAINING",
                "startTime": "2025-03-01T07:00:00.000",
                "duration": "PT45M"
            }]
        }
        """#.data(using: .utf8)!

        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: json)
        let activity = try XCTUnwrap(session.toActivity(fileID: "id-123"))

        XCTAssertEqual(activity.distance, 0.0)
        XCTAssertEqual(activity.avgSpeed, 0.0)
        XCTAssertNil(activity.avgHeartRate)
        XCTAssertNil(activity.calories)
        XCTAssertNil(activity.ascent)
    }

    func test_decode_invalidStartTime_returnsNilFromMapper() throws {
        let json = #"""
        {
            "startTime": "not-a-date",
            "duration": "PT1H",
            "sport": "RUNNING",
            "exercises": [{
                "sport": "RUNNING",
                "startTime": "not-a-date",
                "duration": "PT1H"
            }]
        }
        """#.data(using: .utf8)!

        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: json)
        XCTAssertNil(session.toActivity(fileID: "id"))
    }

    func test_decode_unknownSport_mapsToOther() throws {
        let json = #"""
        {
            "startTime": "2025-05-01T12:00:00.000",
            "duration": "PT30M",
            "sport": "ZORBING",
            "exercises": [{
                "sport": "ZORBING",
                "startTime": "2025-05-01T12:00:00.000",
                "duration": "PT30M"
            }]
        }
        """#.data(using: .utf8)!

        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: json)
        let activity = try XCTUnwrap(session.toActivity(fileID: "id"))
        XCTAssertEqual(activity.sportType, .other)
        XCTAssertEqual(activity.sportRawValue, "ZORBING")
    }
}
