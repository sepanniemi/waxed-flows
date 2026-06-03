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
        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            let empty = "[]".data(using: .utf8)!
            return (HTTPURLResponse(url: URL(string: "https://polaraccesslink.com")!,
                                    statusCode: 200, httpVersion: nil, headerFields: nil)!, empty)
        }
        let result = try await client.pullNewActivities(since: nil)
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(callCount, 1, "only the list call should fire")
    }

    func test_pullNewActivities_decodesSessionWithSpeedAligned() async throws {
        let listJSON = #"[{"id":"abc123"}]"#.data(using: .utf8)!
        // Correct v4 API structure (polar.com/polar-api-v4):
        // - statistics: { distance (km), avgHeartRate, maxHeartRate }
        // - samples: { samples: [ { type: "SPEED", intervalValues: { interval, values } } ] }
        // - routes: { route: [ { routePoints: [...] } ] }
        let detailJSON = """
        {
          "id": "abc123",
          "startTime": "2026-05-30T08:30:00+03:00",
          "duration": "PT1H30M",
          "sportId": "CROSS_COUNTRY_SKIING",
          "statistics": {
            "distance": 15.0,
            "avgHeartRate": 142,
            "maxHeartRate": 170
          },
          "samples": {
            "samples": [
              {
                "type": "SPEED",
                "intervalValues": {
                  "interval": "1000",
                  "values": [0.0, 18.5, 19.2, 17.8]
                }
              }
            ]
          },
          "routes": {
            "route": [
              {
                "routePoints": [
                  {"location": {"longitude": 25.01, "latitude": 60.17, "altitudeMeters": 10.0},
                   "timeOffsetFromStartMillis": 0},
                  {"location": {"longitude": 25.02, "latitude": 60.18, "altitudeMeters": 11.0},
                   "timeOffsetFromStartMillis": 1000},
                  {"location": {"longitude": 25.03, "latitude": 60.19, "altitudeMeters": 12.0},
                   "timeOffsetFromStartMillis": 2000},
                  {"location": {"longitude": 25.04, "latitude": 60.20, "altitudeMeters": 11.0},
                   "timeOffsetFromStartMillis": 3000}
                ]
              }
            ]
          }
        }
        """.data(using: .utf8)!

        var requestCount = 0
        MockURLProtocol.requestHandler = { req in
            requestCount += 1
            let data = requestCount == 1 ? listJSON : detailJSON
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let activities = try await client.pullNewActivities(since: nil)
        XCTAssertEqual(activities.count, 1)
        let act = activities[0]
        XCTAssertEqual(act.id, "abc123")
        XCTAssertEqual(act.avgHeartRate, 142)
        XCTAssertEqual(act.distance, 15000, accuracy: 1)  // 15.0 km × 1000 = 15000 m
        XCTAssertEqual(act.duration, 5400, accuracy: 1)    // PT1H30M = 5400s
        XCTAssertTrue(act.hasRoute)

        // Speed alignment: waypoint at t=1000ms, interval=1000 → idx=1 → 18.5 km/h
        let points = act.routePoints
        XCTAssertEqual(points.count, 4)
        XCTAssertNil(points[0].speedKmh)                                          // 0.0 filtered to nil
        XCTAssertEqual(try XCTUnwrap(points[1].speedKmh), 18.5, accuracy: 0.01)  // idx=1
        XCTAssertEqual(try XCTUnwrap(points[2].speedKmh), 19.2, accuracy: 0.01)  // idx=2
        XCTAssertEqual(try XCTUnwrap(points[3].speedKmh), 17.8, accuracy: 0.01)  // idx=3
    }

    func test_pullNewActivities_nullSpeedValues_yieldNilSpeedKmh() async throws {
        let listJSON = #"[{"id":"s1"}]"#.data(using: .utf8)!
        let detailJSON = """
        {
          "id": "s1",
          "startTime": "2026-05-30T08:30:00Z",
          "duration": "PT10M",
          "samples": {
            "samples": [
              {"type":"SPEED","intervalValues":{"interval":"1000","values":[null, 10.0]}}
            ]
          },
          "routes": {
            "route": [
              {
                "routePoints": [
                  {"location":{"longitude":25.0,"latitude":60.0},"timeOffsetFromStartMillis":0},
                  {"location":{"longitude":25.1,"latitude":60.1},"timeOffsetFromStartMillis":1000}
                ]
              }
            ]
          }
        }
        """.data(using: .utf8)!
        var count = 0
        MockURLProtocol.requestHandler = { req in
            count += 1
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    count == 1 ? listJSON : detailJSON)
        }
        let acts = try await client.pullNewActivities(since: nil)
        XCTAssertNil(acts[0].routePoints[0].speedKmh)
        XCTAssertEqual(try XCTUnwrap(acts[0].routePoints[1].speedKmh), 10.0, accuracy: 0.01)
    }

    func test_pullNewActivities_nanStringValues_yieldNilSpeedKmh() async throws {
        // Polar encodes missing samples as the string "NaN", not JSON null.
        // A native [Double?] decoder throws on "NaN", silently making intervalValues nil.
        let listJSON = #"[{"id":"s2"}]"#.data(using: .utf8)!
        let detailJSON = """
        {
          "id": "s2",
          "startTime": "2026-05-30T08:30:00Z",
          "duration": "PT10M",
          "samples": {
            "samples": [
              {"type":"SPEED","intervalValues":{"interval":"1000","values":["NaN", 12.5, "NaN"]}}
            ]
          },
          "routes": {
            "route": [
              {
                "routePoints": [
                  {"location":{"longitude":25.0,"latitude":60.0},"timeOffsetFromStartMillis":0},
                  {"location":{"longitude":25.1,"latitude":60.1},"timeOffsetFromStartMillis":1000},
                  {"location":{"longitude":25.2,"latitude":60.2},"timeOffsetFromStartMillis":2000}
                ]
              }
            ]
          }
        }
        """.data(using: .utf8)!
        var count = 0
        MockURLProtocol.requestHandler = { req in
            count += 1
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    count == 1 ? listJSON : detailJSON)
        }
        let acts = try await client.pullNewActivities(since: nil)
        XCTAssertEqual(acts.count, 1)
        let pts = acts[0].routePoints
        XCTAssertNil(pts[0].speedKmh)                                            // "NaN" → nil
        XCTAssertEqual(try XCTUnwrap(pts[1].speedKmh), 12.5, accuracy: 0.01)    // 12.5
        XCTAssertNil(pts[2].speedKmh)                                            // "NaN" → nil
    }

    func test_pullNewActivities_sinceNil_usesFallbackDateRange() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        _ = try await client.pullNewActivities(since: nil)
        let urlString = capturedURL?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("from="), "should include a from= param")
        XCTAssertTrue(urlString.contains("to="),   "should include a to= param")
    }

    func test_parseISO8601Duration_hoursMinutesSeconds() throws {
        XCTAssertEqual(try XCTUnwrap(PolarV4Client.parseISO8601Duration("PT1H30M")), 5400, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(PolarV4Client.parseISO8601Duration("PT45S")),   45,   accuracy: 0.01)
        XCTAssertNil(PolarV4Client.parseISO8601Duration("invalid"))
    }
}
