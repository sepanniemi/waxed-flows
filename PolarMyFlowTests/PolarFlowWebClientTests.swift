import XCTest
@testable import PolarMyFlow

final class PolarFlowWebClientTests: XCTestCase {
    var client: PolarFlowWebClient!

    override func setUp() {
        client = PolarFlowWebClient(
            session: makeMockSession(),
            userID: "38805457",
            cookieHeader: "FLOW_SESSION=test"
        )
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
    }

    func test_fetchActivities_parsesNormalActivity() async throws {
        let json = """
        [
          {
            "id": 8313274001,
            "duration": 1671023,
            "distance": 5443.2001953125,
            "hrAvg": 128,
            "calories": 243,
            "note": " ",
            "sportName": "Maastopyöräily",
            "sportId": 5,
            "startDate": "2026-04-05 10:12:28.447",
            "recoveryTime": 17163483,
            "iconUrl": "",
            "trainingLoadHtml": "",
            "hasTrainingTarget": false,
            "swimmingSport": false,
            "swimmingPoolUnits": "METERS",
            "trainingLoadProHtml": "10000",
            "periodDataUuid": "0ff9f3f5-0da4-4e02-9c22-25f00a4ad0cd",
            "isTest": false
          }
        ]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://flow.polar.com")!,
                             statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let activities = try await client.fetchActivities(from: "2026-04-01", to: "2026-04-30")
        XCTAssertEqual(activities.count, 1)
        let act = activities[0]
        XCTAssertEqual(act.id, "8313274001")
        XCTAssertEqual(act.duration, 1671023.0 / 1000.0, accuracy: 0.1)
        XCTAssertEqual(act.distance, 5443.2001953125, accuracy: 0.01)
        XCTAssertEqual(act.avgHeartRate, 128)
        XCTAssertEqual(act.calories, 243)
        XCTAssertEqual(act.sportRawValue, "MOUNTAIN_BIKING")
        XCTAssertNil(act.maxHeartRate)
        XCTAssertNil(act.ascent)
        XCTAssertFalse(act.hasRoute)
    }

    func test_fetchActivities_handlesNullDistance() async throws {
        let json = """
        [
          {
            "id": 8304820317,
            "duration": 2964866,
            "distance": null,
            "hrAvg": 123,
            "calories": 403,
            "sportName": "Voimaharjoittelu",
            "sportId": 15,
            "startDate": "2026-03-24 06:51:23.038",
            "recoveryTime": 28981547,
            "iconUrl": "",
            "trainingLoadHtml": "",
            "hasTrainingTarget": false,
            "swimmingSport": false,
            "swimmingPoolUnits": "METERS",
            "trainingLoadProHtml": "11000",
            "periodDataUuid": "82d2e73b-583f-440f-85b8-70927ccaf1de",
            "isTest": false
          }
        ]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://flow.polar.com")!,
                             statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let activities = try await client.fetchActivities(from: "2026-03-01", to: "2026-03-31")
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities[0].distance, 0.0)
        XCTAssertEqual(activities[0].sportRawValue, "STRENGTH_TRAINING")
        XCTAssertEqual(activities[0].avgSpeed, 0.0)
        XCTAssertEqual(activities[0].avgPace, 0.0)
    }

    func test_httpError_throws() async throws {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://flow.polar.com")!,
                             statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await client.fetchActivities(from: "2026-01-01", to: "2026-01-31")
            XCTFail("Expected error")
        } catch APIError.httpError(let code) {
            XCTAssertEqual(code, 401)
        }
    }

    func test_malformedJSON_throwsAPIChanged() async throws {
        let badJSON = "not json at all".data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://flow.polar.com")!,
                             statusCode: 200, httpVersion: nil, headerFields: nil)!, badJSON)
        }
        do {
            _ = try await client.fetchActivities(from: "2026-01-01", to: "2026-01-31")
            XCTFail("Expected error")
        } catch APIError.apiChanged {
            // success
        }
    }

    func test_sportIdMapping() {
        XCTAssertEqual(SportType.from(polarSportId: 1), .running)
        XCTAssertEqual(SportType.from(polarSportId: 2), .cycling)
        XCTAssertEqual(SportType.from(polarSportId: 3), .walking)
        XCTAssertEqual(SportType.from(polarSportId: 4), .swimming)
        XCTAssertEqual(SportType.from(polarSportId: 5), .mountainBiking)
        XCTAssertEqual(SportType.from(polarSportId: 6), .xcSkiing)
        XCTAssertEqual(SportType.from(polarSportId: 62), .xcSkiing)
        XCTAssertEqual(SportType.from(polarSportId: 15), .strength)
        XCTAssertEqual(SportType.from(polarSportId: 17), .rowing)
        XCTAssertEqual(SportType.from(polarSportId: 999), .other)
    }

    func test_speedAndPaceCalculation() async throws {
        // distance 10000m, duration 3600000ms (1 hour) → speed = 10000/3600 ≈ 2.778 m/s
        let json = """
        [
          {
            "id": 1234567890,
            "duration": 3600000,
            "distance": 10000.0,
            "hrAvg": 150,
            "calories": 500,
            "sportId": 1,
            "startDate": "2026-01-01 08:00:00.000"
          }
        ]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://flow.polar.com")!,
                             statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let activities = try await client.fetchActivities(from: "2026-01-01", to: "2026-01-31")
        XCTAssertEqual(activities.count, 1)
        let act = activities[0]
        XCTAssertEqual(act.avgSpeed, 10000.0 / 3600.0, accuracy: 0.001)
        XCTAssertEqual(act.avgPace, 3600.0 / 10000.0, accuracy: 0.001)
    }
}
