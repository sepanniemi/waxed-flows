import XCTest
@testable import PolarMyFlow

final class PolarV4ClientTests: XCTestCase {
    var client: PolarV4Client!

    override func setUp() {
        client = PolarV4Client(session: makeMockSession(), accessToken: "test-token")
    }
    override func tearDown() { MockURLProtocol.requestHandler = nil }

    // MARK: - registerUser

    func test_registerUser_returnsFixedKey() async throws {
        let id = try await client.registerUser()
        XCTAssertEqual(id, "polar-v4")
    }

    // MARK: - pullNewActivities

    func test_pullNewActivities_emptyList_returnsEmpty() async throws {
        MockURLProtocol.requestHandler = { _ in
            let empty = #"{"trainingSessions":[]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: URL(string: "https://polaraccesslink.com")!,
                                    statusCode: 200, httpVersion: nil, headerFields: nil)!, empty)
        }
        let result = try await client.pullNewActivities(since: nil)
        XCTAssertTrue(result.isEmpty)
    }

    func test_pullNewActivities_decodesSessionWithSpeedAligned() async throws {
        // Actual v4 API structure (verified from Polar API example):
        // - session-level: identifier.id, durationMillis, distanceMeters, hrAvg/hrMax
        // - exercises[0].samples.samples[]: type, intervalMillis, values[]
        // - exercises[0].routes.route.wayPoints[]: longitude, latitude, altitude, elapsedMillis
        let listJSON = """
        {
          "trainingSessions": [
            {
              "identifier": {"id": "abc123"},
              "startTime": "2026-05-30T05:30:00.000Z",
              "durationMillis": 5400000,
              "distanceMeters": 15000,
              "hrAvg": 142,
              "hrMax": 170,
              "sport": {"id": "22353647432"},
              "exercises": [
                {
                  "distanceMeters": 15000,
                  "ascentMeters": 200,
                  "descentMeters": 180,
                  "samples": {
                    "samples": [
                      {
                        "type": "SPEED",
                        "intervalMillis": 1000,
                        "values": [0.0, 18.5, 19.2, 17.8]
                      }
                    ]
                  },
                  "routes": {
                    "route": {
                      "wayPoints": [
                        {"longitude": 25.01, "latitude": 60.17, "altitude": 10.0, "elapsedMillis": 0},
                        {"longitude": 25.02, "latitude": 60.18, "altitude": 11.0, "elapsedMillis": 1000},
                        {"longitude": 25.03, "latitude": 60.19, "altitude": 12.0, "elapsedMillis": 2000},
                        {"longitude": 25.04, "latitude": 60.20, "altitude": 11.0, "elapsedMillis": 3000}
                      ]
                    }
                  }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: URL(string: "https://polaraccesslink.com")!,
                                    statusCode: 200, httpVersion: nil, headerFields: nil)!, listJSON)
        }

        let activities = try await client.pullNewActivities(since: nil)
        XCTAssertEqual(activities.count, 1)
        let act = activities[0]
        XCTAssertEqual(act.id, "abc123")
        XCTAssertEqual(act.avgHeartRate, 142)
        XCTAssertEqual(act.distance, 15000, accuracy: 1)
        XCTAssertEqual(act.duration, 5400, accuracy: 1)  // 5400000ms = 5400s
        XCTAssertTrue(act.hasRoute)

        // Speed alignment: waypoint at elapsedMillis=1000, intervalMillis=1000 → idx=1 → 18.5 km/h
        let points = act.routePoints
        XCTAssertEqual(points.count, 4)
        XCTAssertNil(points[0].speedKmh)                                          // 0.0 filtered to nil
        XCTAssertEqual(try XCTUnwrap(points[1].speedKmh), 18.5, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(points[2].speedKmh), 19.2, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(points[3].speedKmh), 17.8, accuracy: 0.01)
    }

    func test_pullNewActivities_nullSpeedValues_yieldNilSpeedKmh() async throws {
        let listJSON = """
        {
          "trainingSessions": [
            {
              "identifier": {"id": "s1"},
              "startTime": "2026-05-30T08:30:00.000Z",
              "durationMillis": 600000,
              "exercises": [
                {
                  "samples": {
                    "samples": [
                      {"type": "SPEED", "intervalMillis": 1000, "values": [null, 10.0]}
                    ]
                  },
                  "routes": {
                    "route": {
                      "wayPoints": [
                        {"longitude": 25.0, "latitude": 60.0, "elapsedMillis": 0},
                        {"longitude": 25.1, "latitude": 60.1, "elapsedMillis": 1000}
                      ]
                    }
                  }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: URL(string: "https://polaraccesslink.com")!,
                                    statusCode: 200, httpVersion: nil, headerFields: nil)!, listJSON)
        }
        let acts = try await client.pullNewActivities(since: nil)
        XCTAssertNil(acts[0].routePoints[0].speedKmh)
        XCTAssertEqual(try XCTUnwrap(acts[0].routePoints[1].speedKmh), 10.0, accuracy: 0.01)
    }

    func test_pullNewActivities_nanStringValues_yieldNilSpeedKmh() async throws {
        // Polar encodes missing samples as the string "NaN", not JSON null.
        let listJSON = """
        {
          "trainingSessions": [
            {
              "identifier": {"id": "s2"},
              "startTime": "2026-05-30T08:30:00.000Z",
              "durationMillis": 600000,
              "exercises": [
                {
                  "samples": {
                    "samples": [
                      {"type": "SPEED", "intervalMillis": 1000, "values": ["NaN", 12.5, "NaN"]}
                    ]
                  },
                  "routes": {
                    "route": {
                      "wayPoints": [
                        {"longitude": 25.0, "latitude": 60.0, "elapsedMillis": 0},
                        {"longitude": 25.1, "latitude": 60.1, "elapsedMillis": 1000},
                        {"longitude": 25.2, "latitude": 60.2, "elapsedMillis": 2000}
                      ]
                    }
                  }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in
            return (HTTPURLResponse(url: URL(string: "https://polaraccesslink.com")!,
                                    statusCode: 200, httpVersion: nil, headerFields: nil)!, listJSON)
        }
        let acts = try await client.pullNewActivities(since: nil)
        XCTAssertEqual(acts.count, 1)
        let pts = acts[0].routePoints
        XCTAssertNil(pts[0].speedKmh)
        XCTAssertEqual(try XCTUnwrap(pts[1].speedKmh), 12.5, accuracy: 0.01)
        XCTAssertNil(pts[2].speedKmh)
    }

    func test_pullNewActivities_sinceNil_usesFallbackDateRange() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    #"{"trainingSessions":[]}"#.data(using: .utf8)!)
        }
        _ = try await client.pullNewActivities(since: nil)
        let urlString = capturedURL?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("from="), "should include a from= param")
        XCTAssertTrue(urlString.contains("to="),   "should include a to= param")
    }
}
