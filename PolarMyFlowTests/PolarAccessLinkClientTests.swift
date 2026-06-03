import XCTest
@testable import PolarMyFlow

final class PolarAccessLinkClientTests: XCTestCase {
    var client: PolarAccessLinkClient!

    override func setUp() {
        client = PolarAccessLinkClient(session: makeMockSession(), accessToken: "test-token")
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
    }

    // MARK: - User registration

    func test_registerUser_returnsUserID() async throws {
        let json = """
        { "polar-user-id": 99, "member-id": "user@example.com" }
        """.data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                             statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let userID = try await client.registerUser()
        XCTAssertEqual(userID, "99")
    }

    func test_registerUser_409_meansAlreadyRegistered() async throws {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                             statusCode: 409, httpVersion: nil, headerFields: nil)!, Data())
        }
        let userID = try await client.registerUser()
        XCTAssertEqual(userID, "registered")
    }

    func test_registerUser_sendsXMLContentType() async throws {
        var capturedContentType: String?
        let json = """
        { "polar-user-id": 1, "member-id": "test" }
        """.data(using: .utf8)!
        MockURLProtocol.requestHandler = { request in
            capturedContentType = request.value(forHTTPHeaderField: "Content-Type")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        _ = try await client.registerUser()
        XCTAssertEqual(capturedContentType, "application/xml")
    }

    // MARK: - Exercises

    func test_pullNewActivities_204_returnsEmpty() async throws {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                             statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        let activities = try await client.pullNewActivities(since: nil)
        XCTAssertTrue(activities.isEmpty)
    }

    func test_pullNewActivities_parsesExercises() async throws {
        let json = """
        [
          {
            "id": "2AC312F",
            "start_time": "2025-01-15T09:00:00",
            "duration": "PT1H30M",
            "calories": 800,
            "distance": 15000.0,
            "heart_rate": { "average": 142, "maximum": 170 },
            "sport": "OTHER",
            "detailed_sport_info": "CROSS_COUNTRY_SKIING",
            "has_route": true
          }
        ]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                             statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let activities = try await client.pullNewActivities(since: nil)
        XCTAssertEqual(activities.count, 1)
        let act = activities[0]
        XCTAssertEqual(act.id, "2AC312F")
        XCTAssertEqual(act.duration, 5400, accuracy: 1)
        XCTAssertEqual(act.distance, 15000)
        XCTAssertEqual(act.avgHeartRate, 142)
        XCTAssertEqual(act.maxHeartRate, 170)
        XCTAssertEqual(act.sportRawValue, "CROSS_COUNTRY_SKIING")
        XCTAssertTrue(act.hasRoute)
    }

    func test_pullNewActivities_handlesNullDistance() async throws {
        let json = """
        [
          {
            "id": "ABC123",
            "start_time": "2025-03-01T07:00:00",
            "duration": "PT45M",
            "calories": 300,
            "sport": "STRENGTH_TRAINING",
            "has_route": false
          }
        ]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                             statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let activities = try await client.pullNewActivities(since: nil)
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities[0].distance, 0.0)
        XCTAssertEqual(activities[0].avgSpeed, 0.0)
    }

    func test_parseISO8601Duration_variousFormats() throws {
        let d1 = try XCTUnwrap(PolarAccessLinkClient.parseISO8601Duration("PT1H30M0S"))
        XCTAssertEqual(d1, 5400, accuracy: 0.1)
        let d2 = try XCTUnwrap(PolarAccessLinkClient.parseISO8601Duration("PT42M1S"))
        XCTAssertEqual(d2, 2521, accuracy: 0.1)
        let d3 = try XCTUnwrap(PolarAccessLinkClient.parseISO8601Duration("PT30S"))
        XCTAssertEqual(d3, 30, accuracy: 0.1)
        let d4 = try XCTUnwrap(PolarAccessLinkClient.parseISO8601Duration("PT2H44M"))
        XCTAssertEqual(d4, 9840, accuracy: 0.1)
        XCTAssertNil(PolarAccessLinkClient.parseISO8601Duration("invalid"))
    }
}
