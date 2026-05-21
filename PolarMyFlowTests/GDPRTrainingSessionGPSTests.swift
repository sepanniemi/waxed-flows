import XCTest
@testable import PolarMyFlow

final class GDPRTrainingSessionGPSTests: XCTestCase {
    private let sessionJSON = """
    {
        "startTime": "2019-04-10T07:20:36.000",
        "durationMillis": 3600000,
        "distanceMeters": 10000.0,
        "exercises": [
            {
                "ascentMeters": 50.0,
                "descentMeters": 45.0,
                "routes": {
                    "route": {
                        "wayPoints": [
                            {"longitude": 25.61448, "latitude": 64.99879, "altitude": 22.0, "elapsedMillis": 0},
                            {"longitude": 25.61500, "latitude": 64.99920, "altitude": 23.0, "elapsedMillis": 5000},
                            {"longitude": 25.61560, "latitude": 64.99960, "altitude": 24.0, "elapsedMillis": 10000}
                        ],
                        "startTime": "2019-04-10T07:20:36.000"
                    }
                }
            }
        ]
    }
    """.data(using: .utf8)!

    func testParsesWaypointsAndSetsHasRoute() throws {
        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: sessionJSON)
        let activity = try XCTUnwrap(session.toActivity(fileID: "test-session"))
        XCTAssertTrue(activity.hasRoute)
        XCTAssertNotNil(activity.routePointsData)
    }

    func testRoutePointsDecodeCorrectly() throws {
        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: sessionJSON)
        let activity = try XCTUnwrap(session.toActivity(fileID: "test-session"))
        let points = activity.routePoints
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].latitude, 64.99879, accuracy: 0.00001)
        XCTAssertEqual(points[0].longitude, 25.61448, accuracy: 0.00001)
        XCTAssertEqual(points[0].altitude, 22.0, accuracy: 0.01)
        XCTAssertEqual(points[0].elapsedMillis, 0)
        XCTAssertEqual(points[2].elapsedMillis, 10000)
    }

    func testSessionWithNoRoutes_hasRouteFalse() throws {
        let noRouteJSON = """
        {
            "startTime": "2019-04-10T07:20:36.000",
            "durationMillis": 3600000
        }
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: noRouteJSON)
        let activity = try XCTUnwrap(session.toActivity(fileID: "no-route"))
        XCTAssertFalse(activity.hasRoute)
        XCTAssertNil(activity.routePointsData)
    }

    func testSessionWithEmptyWaypoints_hasRouteFalse() throws {
        let emptyJSON = """
        {
            "startTime": "2019-04-10T07:20:36.000",
            "durationMillis": 3600000,
            "exercises": [
                {
                    "routes": {
                        "route": {
                            "wayPoints": []
                        }
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: emptyJSON)
        let activity = try XCTUnwrap(session.toActivity(fileID: "empty-route"))
        XCTAssertFalse(activity.hasRoute)
        XCTAssertNil(activity.routePointsData)
    }
}
