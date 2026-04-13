import XCTest
@testable import PolarMyFlow

final class PolarAccessLinkClientTests: XCTestCase {
    var client: PolarAccessLinkClient!

    override func setUp() {
        client = PolarAccessLinkClient(session: makeMockSession(), accessToken: "test-token")
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
        // 409 Conflict = user already registered — should succeed, return existing ID
        // The client re-fetches user info on 409
        let json = """
        { "polar-user-id": 77, "member-id": "user@example.com" }
        """.data(using: .utf8)!
        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let code = callCount == 1 ? 409 : 200
            return (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                                   statusCode: code, httpVersion: nil, headerFields: nil)!, json)
        }
        let userID = try await client.registerUser()
        XCTAssertEqual(userID, "77")
    }

    // MARK: - Exercise transaction

    func test_pullNewActivities_204_returnsEmpty() async throws {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                             statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        let activities = try await client.pullNewActivities()
        XCTAssertTrue(activities.isEmpty)
    }

    func test_pullNewActivities_parsesExerciseDetail() async throws {
        let transactionJSON = """
        { "transaction-id": 101, "exercises": [
            { "id": 1, "href": "https://www.polaraccesslink.com/v3/exercises/101/1" }
        ]}
        """.data(using: .utf8)!

        let detailJSON = """
        {
          "id": 1,
          "transaction-id": 101,
          "start-time": "2025-01-15T09:00:00",
          "duration": "PT1H30M0S",
          "calories": 800,
          "distance": 15000.0,
          "heart-rate": { "average": 142, "maximum": 170 },
          "sport": "CROSS_COUNTRY_SKIING",
          "has-route": true
        }
        """.data(using: .utf8)!

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            switch callCount {
            case 1: // POST transaction
                return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, transactionJSON)
            case 2: // GET exercise list
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, transactionJSON)
            case 3: // GET exercise detail
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, detailJSON)
            default: // PUT commit
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        let activities = try await client.pullNewActivities()
        XCTAssertEqual(activities.count, 1)
        let act = activities[0]
        XCTAssertEqual(act.id, "101-1")
        XCTAssertEqual(act.duration, 5400, accuracy: 1)
        XCTAssertEqual(act.distance, 15000)
        XCTAssertEqual(act.avgHeartRate, 142)
        XCTAssertEqual(act.maxHeartRate, 170)
        XCTAssertEqual(act.sportRawValue, "CROSS_COUNTRY_SKIING")
        XCTAssertTrue(act.hasRoute)
    }

    func test_parseISO8601Duration_variousFormats() throws {
        let d1 = try XCTUnwrap(PolarAccessLinkClient.parseISO8601Duration("PT1H30M0S"))
        XCTAssertEqual(d1, 5400, accuracy: 0.1)
        let d2 = try XCTUnwrap(PolarAccessLinkClient.parseISO8601Duration("PT42M1S"))
        XCTAssertEqual(d2, 2521, accuracy: 0.1)
        let d3 = try XCTUnwrap(PolarAccessLinkClient.parseISO8601Duration("PT30S"))
        XCTAssertEqual(d3, 30, accuracy: 0.1)
        XCTAssertNil(PolarAccessLinkClient.parseISO8601Duration("invalid"))
    }
}
