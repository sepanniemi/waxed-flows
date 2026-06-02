# Polar API v4 Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the v3 `PolarAccessLinkClient` (GPX-only, no per-point speed) with a `PolarV4Client` that fetches training sessions from the Polar Dynamic AccessLink v4 API, populating real per-point speed for the speed-colored GPS map.

**Architecture:** Four tasks in order: (1) migrate `AuthManager` to v4 OAuth endpoints and force re-auth for existing v3 users; (2) extend `AccessLinkClientProtocol` + `SyncCoordinator` to pass `since: Date?` so v4 can do incremental fetches; (3) implement `PolarV4Client` with a v4 session decoder that reuses the same speed-alignment formula as the GDPR importer; (4) wire the new client into the app and remove v3 dead code. The render layer (`TrackMapView`, `SpeedColorRamp`) is already source-agnostic and requires no changes — it colors whatever `RoutePoint.speedKmh` is stored.

**Tech Stack:** Swift/SwiftUI, SwiftData, URLSession, ASWebAuthenticationSession, XCTest

---

## Background: what changes and why

| | v3 (current) | v4 (this plan) |
|---|---|---|
| Auth host | `flow.polar.com` | `auth.polar.com` |
| Token host | `polarremote.com/v2/oauth2/token` | `auth.polar.com/oauth/token` |
| Scope | `accesslink.read_all` | `training_sessions:read` |
| Token lifetime | short, no refresh in practice | 12 h + refresh token |
| Data endpoint | `/v3/exercises` (GPX, last 30 days) | `/v4/data/training-sessions?from=&to=` |
| Per-point speed | ❌ GPX has no speed field | ✅ SPEED sample series, km/h, same shape as GDPR |
| Route waypoints | GPX `<trkpt>` | `routePoints[].location + timeOffsetFromStartMillis` |

The v4 samples shape (`{type, intervalMillis, values}`) is **identical** to `GDPRTrainingSession.SampleSeries`. The same `t / series.intervalMillis` index alignment used by `GDPRTrainingSession.toActivity()` works directly on v4 data.

Existing v3 tokens won't work with v4 endpoints. Task 1 adds a one-time migration that wipes the stored v3 token on first launch, forcing the user to re-authenticate with v4 scope.

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `PolarMyFlow/Auth/AuthManager.swift` | Modify | v4 auth/token endpoints; `training_sessions:read` scope; one-time v3→v4 migration |
| `PolarMyFlow/API/PolarAccessLinkClient.swift` | **Delete** | Replaced by PolarV4Client in Task 4 |
| `PolarMyFlow/API/GPXParser.swift` | **Delete** | No longer needed once v3 client is gone |
| `PolarMyFlow/API/PolarV4Client.swift` | **Create** | v4 HTTP client + `V4Session` decoder + `AccessLinkClientProtocol` conformance |
| `PolarMyFlow/API/AccessLinkClientProtocol.swift` | **Create** | Extract protocol from `PolarAccessLinkClient.swift` before deleting it |
| `PolarMyFlow/Data/SyncCoordinator.swift` | Modify | Pass `state.lastSyncedAt` to `pullNewActivities(since:)` |
| `PolarMyFlow/PolarMyFlowApp.swift` | Modify | Use `PolarV4Client` instead of `PolarAccessLinkClient` |
| `PolarMyFlowTests/PolarV4ClientTests.swift` | **Create** | Unit tests for decoder and HTTP client |
| `PolarMyFlowTests/PolarAccessLinkClientTests.swift` | **Delete** | v3 client removed |
| `PolarMyFlowTests/SyncCoordinatorTests.swift` | Modify | Update `MockAccessLinkClient` for new `since:` param |

> **Note:** `AccessLinkClientProtocol` currently lives at the bottom of `PolarAccessLinkClient.swift`. Extract it to its own file before deleting the v3 client, so nothing else loses the type.

---

## Task 1: Migrate AuthManager to v4 OAuth endpoints

Update the three hardcoded auth constants and add a one-time migration to wipe v3 tokens. Existing v3 users will see the login screen on next launch and re-authenticate with the new scope.

**Files:**
- Modify: `PolarMyFlow/Auth/AuthManager.swift`

- [ ] **Step 1: Update the three auth constants**

In `PolarMyFlow/Auth/AuthManager.swift`, replace:

```swift
static let authURLBase  = "https://flow.polar.com/oauth2/authorization"
static let tokenURL     = "https://polarremote.com/v2/oauth2/token"
```

with:

```swift
static let authURLBase  = "https://auth.polar.com/oauth/authorize"
static let tokenURL     = "https://auth.polar.com/oauth/token"
```

And update the scope in `authenticate()` — find the `URLQueryItem(name: "scope", value: "accesslink.read_all")` line and change it to:

```swift
URLQueryItem(name: "scope", value: "training_sessions:read"),
```

- [ ] **Step 2: Add one-time v3 token migration**

At the very top of `restoreSession()`, before the `guard let token = try? tokenStore.load()` line, add:

```swift
let v4MigrationKey = "com.personal.polarmyflow.auth.v4migrated"
if !UserDefaults.standard.bool(forKey: v4MigrationKey) {
    try? tokenStore.delete()
    UserDefaults.standard.set(true, forKey: v4MigrationKey)
}
```

This runs exactly once on first launch after the upgrade. It deletes the stored v3 token so `restoreSession()` finds nothing and leaves `isAuthenticated = false`, sending the user to the login screen.

- [ ] **Step 3: Build to verify no compile errors**

```bash
xcodebuild build -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "BUILD|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PolarMyFlow/Auth/AuthManager.swift
git commit -m "feat(auth): migrate to v4 OAuth endpoints and training_sessions:read scope"
```

---

## Task 2: Extract protocol + update `SyncCoordinator` for incremental sync

Extract `AccessLinkClientProtocol` to its own file (so it survives deleting the v3 client), add `since: Date?` to it, and update `SyncCoordinator` to pass `lastSyncedAt` so v4 only fetches new sessions. Also update `MockAccessLinkClient` in the sync tests.

**Files:**
- Create: `PolarMyFlow/API/AccessLinkClientProtocol.swift`
- Modify: `PolarMyFlow/Data/SyncCoordinator.swift`
- Modify: `PolarMyFlowTests/SyncCoordinatorTests.swift`

- [ ] **Step 1: Write the failing test**

In `PolarMyFlowTests/SyncCoordinatorTests.swift`, add a test that verifies `since` is passed through. Add it inside `SyncCoordinatorTests` and also add `capturedSince: Date?` to `MockAccessLinkClient`:

```swift
// Add property to MockAccessLinkClient:
var capturedSince: Date?

// Change existing pullNewActivities signature in MockAccessLinkClient:
func pullNewActivities(since: Date?) async throws -> [Activity] {
    capturedSince = since
    if let e = pullError { throw e }
    return stubbedActivities
}

// New test:
func test_sync_passesSinceToClient() async throws {
    let knownDate = Date(timeIntervalSince1970: 1_700_000_000)
    _ = try await coordinator.sync(userID: "user-1")      // first sync — sets lastSyncedAt
    mockAccessLink.stubbedActivities = []
    _ = try await coordinator.sync(userID: "user-1")      // second sync — should pass since
    XCTAssertNotNil(mockAccessLink.capturedSince)
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/SyncCoordinatorTests \
  2>&1 | grep -E "FAILED|error:" | head -5
```

Expected: compile error — `pullNewActivities` has wrong signature in `MockAccessLinkClient`.

- [ ] **Step 3: Create `AccessLinkClientProtocol.swift`**

Create `PolarMyFlow/API/AccessLinkClientProtocol.swift`:

```swift
import Foundation

protocol AccessLinkClientProtocol {
    func registerUser() async throws -> String
    /// Fetch new activities. `since` is the timestamp of the last successful sync;
    /// `nil` means first sync, use a sensible default lookback window.
    func pullNewActivities(since: Date?) async throws -> [Activity]
}
```

- [ ] **Step 4: Update `SyncCoordinator` to pass `lastSyncedAt`**

In `PolarMyFlow/Data/SyncCoordinator.swift`, reorder the `sync` body so state is read before the pull:

```swift
@discardableResult
func sync(userID: String) async throws -> Int {
    let state = try repository.syncState(forUserID: userID)
    let activities = try await accessLinkClient.pullNewActivities(since: state.lastSyncedAt)
    var imported = 0
    for activity in activities {
        try repository.save(activity)
        imported += 1
    }
    state.lastSyncedAt = Date()
    try repository.saveSyncState()
    return imported
}
```

- [ ] **Step 5: Update `PolarAccessLinkClient` to conform to the new signature**

In `PolarMyFlow/API/PolarAccessLinkClient.swift`, change the `pullNewActivities` signature and remove the now-duplicate protocol declaration at the bottom:

```swift
// Change signature (ignore the `since` param — v3 always returns last 30 days):
func pullNewActivities(since: Date?) async throws -> [Activity] {
```

Remove the `protocol AccessLinkClientProtocol { ... }` block at the bottom of the file (it's now in `AccessLinkClientProtocol.swift`). Keep the `extension PolarAccessLinkClient: AccessLinkClientProtocol {}` line.

- [ ] **Step 6: Run xcodegen to register new file**

```bash
xcodegen generate 2>&1 | tail -3
```

- [ ] **Step 7: Run tests to verify they pass**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/SyncCoordinatorTests \
  2>&1 | grep -E "PASSED|FAILED|error:" | tail -5
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add PolarMyFlow/API/AccessLinkClientProtocol.swift \
        PolarMyFlow/Data/SyncCoordinator.swift \
        PolarMyFlow/API/PolarAccessLinkClient.swift \
        PolarMyFlowTests/SyncCoordinatorTests.swift
git commit -m "feat(sync): extract AccessLinkClientProtocol; pass lastSyncedAt to pullNewActivities"
```

---

## Task 3: Create `PolarV4Client` with decoder and tests

Implement the v4 HTTP client and the `V4Session` decoder. The decoder reuses the exact same `t / intervalMillis` speed-alignment formula as `GDPRTrainingSession.toActivity()`. The `SampleSeries` custom decoder handles possible `null` values in the speed array.

> **Verify field names before writing decoders.** After Task 1 is deployed and you've re-authenticated with v4 scope, confirm the actual JSON field names with:
> ```bash
> # The DEBUG build prints the access token on launch. Copy it from the Xcode console.
> curl -s "https://www.polaraccesslink.com/v4/data/training-sessions?from=2026-01-01T00:00:00Z&to=2026-06-30T00:00:00Z" \
>   -H "Authorization: Bearer <your-v4-token>" \
>   -H "Accept: application/json" | head -c 2000
>
> # Then fetch one session's detail:
> curl -s "https://www.polaraccesslink.com/v4/data/training-sessions/<id>" \
>   -H "Authorization: Bearer <your-v4-token>" \
>   -H "Accept: application/json" | python3 -m json.tool | head -80
> ```
> The plan uses field names from the v4 spec research. If the live response differs, update the `CodingKeys` enums or struct property names to match before running the tests.

**Files:**
- Create: `PolarMyFlow/API/PolarV4Client.swift`
- Create: `PolarMyFlowTests/PolarV4ClientTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `PolarMyFlowTests/PolarV4ClientTests.swift`:

```swift
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
        let detailJSON = """
        {
          "id": "abc123",
          "startTime": "2026-05-30T08:30:00+03:00",
          "duration": "PT1H30M",
          "distance": 15000.0,
          "heartRate": {"average": 142, "maximum": 170},
          "sport": "CROSS_COUNTRY_SKIING",
          "hasRoute": true,
          "samples": [
            {
              "type": "SPEED",
              "intervalMillis": 1000,
              "values": [0.0, 18.5, 19.2, 17.8]
            }
          ],
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
        XCTAssertEqual(act.distance, 15000, accuracy: 1)
        // duration "PT1H30M" = 5400s
        XCTAssertEqual(act.duration, 5400, accuracy: 1)
        XCTAssertTrue(act.hasRoute)

        // Speed alignment: waypoint at t=1000ms, intervalMillis=1000 → idx=1 → 18.5 km/h
        let points = act.routePoints
        XCTAssertEqual(points.count, 4)
        XCTAssertEqual(points[0].speedKmh, 0.0,  accuracy: 0.01)  // idx=0
        XCTAssertEqual(points[1].speedKmh, 18.5, accuracy: 0.01)  // idx=1
        XCTAssertEqual(points[2].speedKmh, 19.2, accuracy: 0.01)  // idx=2
        XCTAssertEqual(points[3].speedKmh, 17.8, accuracy: 0.01)  // idx=3
    }

    func test_pullNewActivities_nullSpeedValues_yieldNilSpeedKmh() async throws {
        let listJSON = #"[{"id":"s1"}]"#.data(using: .utf8)!
        let detailJSON = """
        {
          "id": "s1",
          "startTime": "2026-05-30T08:30:00Z",
          "duration": "PT10M",
          "samples": [{"type":"SPEED","intervalMillis":1000,"values":[null, 10.0]}],
          "routePoints": [
            {"location":{"longitude":25.0,"latitude":60.0},"timeOffsetFromStartMillis":0},
            {"location":{"longitude":25.1,"latitude":60.1},"timeOffsetFromStartMillis":1000}
          ]
        }
        """.data(using: .utf8)!
        var count = 0
        MockURLProtocol.requestHandler = { req in
            count += 1
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    count == 1 ? listJSON : detailJSON)
        }
        let acts = try await client.pullNewActivities(since: nil)
        XCTAssertEqual(acts[0].routePoints[0].speedKmh, nil)
        XCTAssertEqual(acts[0].routePoints[1].speedKmh, 10.0, accuracy: 0.01)
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

    func test_parseISO8601Duration_hoursMinutesSeconds() {
        // parseISO8601Duration is internal for testing
        XCTAssertEqual(PolarV4Client.parseISO8601Duration("PT1H30M"), 5400, accuracy: 0.01)
        XCTAssertEqual(PolarV4Client.parseISO8601Duration("PT45S"),   45,   accuracy: 0.01)
        XCTAssertNil(PolarV4Client.parseISO8601Duration("invalid"))
    }
}

// MARK: - helper
private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}
```

- [ ] **Step 2: Run xcodegen to register the test file**

```bash
xcodegen generate 2>&1 | tail -3
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/PolarV4ClientTests \
  2>&1 | grep -E "FAILED|error:|PolarV4Client" | head -6
```

Expected: compile error — `cannot find type 'PolarV4Client' in scope`

- [ ] **Step 4: Create `PolarV4Client.swift`**

Create `PolarMyFlow/API/PolarV4Client.swift`:

```swift
import Foundation

final class PolarV4Client {
    private let urlSession: URLSession
    private let accessToken: String
    private static let baseURL = "https://www.polaraccesslink.com/v4/data"

    init(session: URLSession = .shared, accessToken: String) {
        self.urlSession = session
        self.accessToken = accessToken
    }

    // Internal for testing
    static func parseISO8601Duration(_ string: String) -> TimeInterval? {
        guard string.hasPrefix("PT") else { return nil }
        var remaining = String(string.dropFirst(2))
        var total: Double = 0
        for (unit, multiplier) in [("H", 3600.0), ("M", 60.0), ("S", 1.0)] {
            if let range = remaining.range(of: unit) {
                if let value = Double(remaining[remaining.startIndex..<range.lowerBound]) {
                    total += value * multiplier
                }
                remaining = String(remaining[range.upperBound...])
            }
        }
        return total > 0 ? total : nil
    }
}

// MARK: - AccessLinkClientProtocol

extension PolarV4Client: AccessLinkClientProtocol {
    func registerUser() async throws -> String {
        // v4 uses OAuth2 consent — no user registration step. Fixed key for SyncState.
        return "polar-v4"
    }

    func pullNewActivities(since: Date?) async throws -> [Activity] {
        let to = Date()
        let from = since ?? Calendar.current.date(byAdding: .day, value: -30, to: to)!
        let list = try await fetchSessionList(from: from, to: to)
        var activities: [Activity] = []
        for item in list {
            guard let session = try? await fetchSessionDetail(id: item.id),
                  let activity = session.toActivity() else { continue }
            activities.append(activity)
        }
        return activities
    }
}

// MARK: - HTTP

private extension PolarV4Client {
    func makeRequest(path: String) -> URLRequest {
        var req = URLRequest(url: URL(string: "\(Self.baseURL)\(path)")!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    func perform(_ request: URLRequest, label: String) async throws -> (Data, Int) {
        let (data, response) = try await urlSession.data(for: request)
        let http = response as! HTTPURLResponse
        #if DEBUG
        let preview = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
        print("📡 \(label): HTTP \(http.statusCode), \(data.count) bytes — \(preview)")
        #endif
        return (data, http.statusCode)
    }

    func fetchSessionList(from: Date, to: Date) async throws -> [V4SessionListItem] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let path = "/training-sessions?from=\(iso.string(from: from))&to=\(iso.string(from: to))"
        let (data, status) = try await perform(makeRequest(path: path),
                                               label: "GET /training-sessions")
        if status == 204 { return [] }
        guard status == 200 else { throw APIError.httpError(statusCode: status) }
        return (try? JSONDecoder().decode([V4SessionListItem].self, from: data)) ?? []
    }

    func fetchSessionDetail(id: String) async throws -> V4Session? {
        let (data, status) = try await perform(makeRequest(path: "/training-sessions/\(id)"),
                                               label: "GET /training-sessions/\(id)")
        guard status == 200 else { return nil }
        return try? JSONDecoder().decode(V4Session.self, from: data)
    }
}

// MARK: - DTOs

private struct V4SessionListItem: Decodable {
    let id: String
}

private struct V4Session: Decodable {
    let id: String
    let startTime: String          // ISO-8601 with offset e.g. "2026-05-30T08:30:00+03:00"
    let duration: String           // ISO-8601 e.g. "PT1H30M"
    let distance: Double?          // metres
    let heartRate: HeartRate?
    let sport: String?
    let hasRoute: Bool?
    let samples: [SampleSeries]?
    let routePoints: [WayPoint]?

    struct HeartRate: Decodable {
        let average: Int?
        let maximum: Int?
    }

    // Same shape as GDPRTrainingSession.SampleSeries.
    // Custom init tolerates null values in the array.
    struct SampleSeries: Decodable {
        let type: String
        let intervalMillis: Int
        let values: [Double?]

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            intervalMillis = try c.decode(Int.self, forKey: .intervalMillis)
            var raw = try c.nestedUnkeyedContainer(forKey: .values)
            var decoded: [Double?] = []
            while !raw.isAtEnd {
                if let d = try? raw.decode(Double.self) { decoded.append(d) }
                else { _ = try? raw.decode(String.self); decoded.append(nil) }
            }
            values = decoded
        }
        enum CodingKeys: String, CodingKey { case type, intervalMillis, values }
    }

    struct WayPoint: Decodable {
        let location: Location
        let timeOffsetFromStartMillis: Int

        struct Location: Decodable {
            let longitude: Double
            let latitude: Double
            let altitudeMeters: Double?
        }
    }

    func toActivity() -> Activity? {
        guard let start = Self.parseDate(startTime),
              let dur = PolarV4Client.parseISO8601Duration(duration) else { return nil }

        let dist = distance ?? 0
        let speedSeries = samples?.first(where: { $0.type == "SPEED" })
        let wayPoints = routePoints ?? []

        // Same alignment formula as GDPRTrainingSession.toActivity():
        // idx = timeOffsetFromStartMillis / intervalMillis
        let points: [RoutePoint] = wayPoints.map { wp in
            let t = wp.timeOffsetFromStartMillis
            var speedKmh: Double? = nil
            if let series = speedSeries, series.intervalMillis > 0 {
                let idx = t / series.intervalMillis
                if idx < series.values.count, let v = series.values[idx] {
                    speedKmh = v  // v4 SPEED is in km/h (same as GDPR)
                }
            }
            return RoutePoint(
                latitude: wp.location.latitude,
                longitude: wp.location.longitude,
                altitude: wp.location.altitudeMeters ?? 0,
                elapsedMillis: t,
                speedKmh: speedKmh
            )
        }

        return Activity(
            id: id,
            startTime: start,
            duration: dur,
            distance: dist,
            sportRawValue: sport ?? SportType.other.rawValue,
            avgSpeed: dist > 0 ? dist / dur : 0,
            avgPace:  dist > 0 ? dur / dist : 0,
            avgHeartRate: heartRate?.average,
            maxHeartRate: heartRate?.maximum,
            calories: nil,
            hasRoute: !points.isEmpty,
            routePointsData: points.isEmpty ? nil : try? JSONEncoder().encode(points)
        )
    }

    private static func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
```

- [ ] **Step 5: Run xcodegen to register the source file**

```bash
xcodegen generate 2>&1 | tail -3
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/PolarV4ClientTests \
  2>&1 | grep -E "PASSED|FAILED|error:" | tail -5
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add PolarMyFlow/API/PolarV4Client.swift \
        PolarMyFlowTests/PolarV4ClientTests.swift
git commit -m "feat(api): add PolarV4Client — training-sessions endpoint with SPEED sample alignment"
```

---

## Task 4: Wire `PolarV4Client` into app; remove v3 dead code

Replace `PolarAccessLinkClient` with `PolarV4Client` in `PolarMyFlowApp`, then delete the v3 client and GPX parser. Run the full suite to confirm nothing breaks.

**Files:**
- Modify: `PolarMyFlow/PolarMyFlowApp.swift`
- Delete: `PolarMyFlow/API/PolarAccessLinkClient.swift`
- Delete: `PolarMyFlow/API/GPXParser.swift`
- Delete: `PolarMyFlowTests/PolarAccessLinkClientTests.swift`

- [ ] **Step 1: Update `PolarMyFlowApp.swift` to use `PolarV4Client`**

In `PolarMyFlow/PolarMyFlowApp.swift`, in `startSyncIfAuthenticated()`, find:

```swift
let accessLinkClient = PolarAccessLinkClient(accessToken: token.accessToken)
let fetchedID = try await accessLinkClient.registerUser()
```

Change `PolarAccessLinkClient` → `PolarV4Client` in both places where it's instantiated (there are two: the register call inside the `if let knownID` else-branch and the `runSync` call):

```swift
// In startSyncIfAuthenticated, else branch:
let accessLinkClient = PolarV4Client(accessToken: token.accessToken)
let fetchedID = try await accessLinkClient.registerUser()
```

```swift
// In runSync:
let accessLinkClient = PolarV4Client(accessToken: token.accessToken)
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "BUILD|error:"
```

Expected: `** BUILD SUCCEEDED **`

If there are compile errors referencing `PolarAccessLinkClient`, fix them before deleting the file.

- [ ] **Step 3: Delete v3 files**

```bash
rm PolarMyFlow/API/PolarAccessLinkClient.swift
rm PolarMyFlow/API/GPXParser.swift
rm PolarMyFlowTests/PolarAccessLinkClientTests.swift
xcodegen generate 2>&1 | tail -3
```

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "Executed|SUCCEEDED|FAILED" | tail -5
```

Expected: `** TEST SUCCEEDED **` with no failures. Test count will decrease by the number of deleted v3 client tests — this is expected.

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/PolarMyFlowApp.swift
git rm PolarMyFlow/API/PolarAccessLinkClient.swift \
       PolarMyFlow/API/GPXParser.swift \
       PolarMyFlowTests/PolarAccessLinkClientTests.swift
git commit -m "feat(app): wire PolarV4Client; remove v3 PolarAccessLinkClient and GPXParser"
```

---

## Self-Review

**Spec coverage:**
- v4 auth endpoints + scope → Task 1 ✓
- v3 token migration → Task 1 ✓
- `since: Date?` incremental sync → Task 2 ✓
- v4 session list + detail HTTP → Task 3 `fetchSessionList` + `fetchSessionDetail` ✓
- `routePoints[].location + timeOffsetFromStartMillis` → `RoutePoint` mapping → Task 3 `V4Session.toActivity()` ✓
- SPEED sample alignment (same formula as GDPR) → Task 3 ✓
- Null-tolerant sample decoder → Task 3 `SampleSeries.init(from:)` ✓
- `registerUser()` no-op for v4 → Task 3 ✓
- Remove `PolarAccessLinkClient` + `GPXParser` → Task 4 ✓
- Full test suite green → Task 4, Step 4 ✓
- `parseISO8601Duration` preserved (moved to `PolarV4Client`) → Task 3 ✓

**Placeholder scan:** None — all steps have complete code.

**Type consistency:**
- `PolarV4Client(session:accessToken:)` — used in tests (Task 3 Step 1) and app (Task 4 Step 1) ✓
- `pullNewActivities(since: Date?)` — protocol (Task 2 Step 3), coordinator (Task 2 Step 4), mock (Task 2 Step 1), client (Task 3 Step 4) ✓
- `V4Session`, `V4SessionListItem`, `SampleSeries`, `WayPoint` — all private to `PolarV4Client.swift`; no external references ✓
- `PolarV4Client.parseISO8601Duration` is `static` and referenced in tests (Task 3 Step 1) and in `V4Session.toActivity()` ✓

**Open items that require live-response verification (before committing Task 3):**
- Session-level JSON field names: `startTime`, `duration`, `distance`, `heartRate`, `sport`, `hasRoute` — these are from the v4 spec description and are likely correct, but must be confirmed against a real response. If names differ, update `V4Session` property names or add `CodingKeys`.
- Whether the session list response is a bare array `[...]` or wrapped in an object — if wrapped, update `fetchSessionList` decoder.
- Whether `calories` appears in the v4 detail response — if so, decode it and pass to `Activity.init`.
