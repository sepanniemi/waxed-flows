# GPS Track Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render a speed-colored, glowing GPS route map inside ActivityDetailView for activities imported from the GDPR ZIP export.

**Architecture:** Parse waypoints from `exercise.routes.route.wayPoints` in the GDPR JSON into `RoutePoint` structs, JSON-encode them into a `@Attribute(.externalStorage) Data?` blob on the SwiftData `Activity` model. `TrackMapView` (UIViewRepresentable) reads these points, computes per-segment speeds with a 5-second rolling mean, normalises them 0–1 per session, maps through the A2 5-stop colour ramp, and renders colour-binned `ColoredPolyline` overlays with a wide translucent halo pass followed by a crisp 4.5pt stroke. A SwiftUI `Slider` below the non-interactive map drives an amber scrub-dot `MKPointAnnotation` that slides along the route.

**Tech Stack:** MapKit (`MKMapView`, `MKPolyline`, `MKPolylineRenderer`), SwiftData (`@Attribute(.externalStorage)`), SwiftUI (`UIViewRepresentable`), XcodeGen

---

## File map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `PolarMyFlow/Models/RoutePoint.swift` | Codable struct: lat/lon/altitude/elapsedMillis |
| Create | `PolarMyFlow/Features/Tracks/SpeedColorRamp.swift` | A2 5-stop colour interpolation (UIColor) |
| Create | `PolarMyFlow/Features/Tracks/TrackMapView.swift` | UIViewRepresentable + Coordinator + ColoredPolyline |
| Modify | `PolarMyFlow/Models/Activity.swift` | Add `routePointsData: Data?` + `routePoints` accessor |
| Modify | `PolarMyFlow/Import/GDPRTrainingSession.swift` | Add route structs; parse waypoints in `toActivity()` |
| Modify | `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift` | Add map card + scrub slider when `activity.hasRoute` |
| Modify | `project.yml` | Add `MapKit.framework` dependency |
| Create | `PolarMyFlowTests/RoutePointTests.swift` | Codable round-trip tests |
| Create | `PolarMyFlowTests/SpeedColorRampTests.swift` | Boundary colour tests |
| Create | `PolarMyFlowTests/GDPRTrainingSessionGPSTests.swift` | Waypoint parsing tests |

---

## Task 1: Add MapKit to project.yml + regenerate

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Add MapKit SDK to the app target**

In `project.yml`, find the `dependencies:` list under `targets > PolarMyFlow` and add `MapKit.framework`:

```yaml
    dependencies:
      - sdk: SwiftData.framework
      - sdk: AuthenticationServices.framework
      - sdk: Security.framework
      - sdk: MapKit.framework
      - package: ZIPFoundation
```

- [ ] **Step 2: Regenerate the Xcode project**

```bash
xcodegen generate
```

Expected: `✔ Done` with no errors.

- [ ] **Step 3: Verify build still compiles**

```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected last line: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add project.yml PolarMyFlow.xcodeproj/project.pbxproj
git commit -m "build: add MapKit framework dependency"
```

---

## Task 2: RoutePoint model

**Files:**
- Create: `PolarMyFlow/Models/RoutePoint.swift`
- Create: `PolarMyFlowTests/RoutePointTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PolarMyFlowTests/RoutePointTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing PolarMyFlowTests/RoutePointTests 2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: error about `RoutePoint` not being defined.

- [ ] **Step 3: Create RoutePoint.swift**

```swift
import Foundation

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let elapsedMillis: Int
}
```

- [ ] **Step 4: Run xcodegen + verify tests pass**

```bash
xcodegen generate
xcodebuild test -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing PolarMyFlowTests/RoutePointTests 2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: `Test Suite 'RoutePointTests' passed`

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Models/RoutePoint.swift PolarMyFlowTests/RoutePointTests.swift PolarMyFlow.xcodeproj/project.pbxproj
git commit -m "feat(tracks): add RoutePoint Codable model"
```

---

## Task 3: SpeedColorRamp

**Files:**
- Create: `PolarMyFlow/Features/Tracks/SpeedColorRamp.swift`
- Create: `PolarMyFlowTests/SpeedColorRampTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `PolarMyFlowTests/SpeedColorRampTests.swift`:

```swift
import XCTest
import UIKit
@testable import PolarMyFlow

final class SpeedColorRampTests: XCTestCase {
    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    func testColorAtZero_isIceBlue() {
        let c = components(SpeedColorRamp.color(for: 0.0))
        XCTAssertEqual(c.r, 0xBF / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xDB / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xFE / 255.0, accuracy: 0.01)
    }

    func testColorAtQuarter_isSky() {
        let c = components(SpeedColorRamp.color(for: 0.25))
        XCTAssertEqual(c.r, 0x60 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xA5 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xFA / 255.0, accuracy: 0.01)
    }

    func testColorAtHalf_isAmber() {
        let c = components(SpeedColorRamp.color(for: 0.5))
        XCTAssertEqual(c.r, 0xFB / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xBF / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0x24 / 255.0, accuracy: 0.01)
    }

    func testColorAtOne_isRed() {
        let c = components(SpeedColorRamp.color(for: 1.0))
        XCTAssertEqual(c.r, 0xDC / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0x26 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0x26 / 255.0, accuracy: 0.01)
    }

    func testColorBelowZero_clampsToIceBlue() {
        let atZero = components(SpeedColorRamp.color(for: 0.0))
        let below  = components(SpeedColorRamp.color(for: -1.0))
        XCTAssertEqual(below.r, atZero.r, accuracy: 0.001)
        XCTAssertEqual(below.g, atZero.g, accuracy: 0.001)
    }

    func testColorAboveOne_clampsToRed() {
        let atOne = components(SpeedColorRamp.color(for: 1.0))
        let above = components(SpeedColorRamp.color(for: 2.0))
        XCTAssertEqual(above.r, atOne.r, accuracy: 0.001)
        XCTAssertEqual(above.g, atOne.g, accuracy: 0.001)
    }

    func testMidpointInterpolation_isBetweenStops() {
        // t=0.125 is halfway between ice-blue (0.0) and sky (0.25)
        let c = components(SpeedColorRamp.color(for: 0.125))
        let iceBlueR = 0xBF / 255.0 as CGFloat
        let skyR = 0x60 / 255.0 as CGFloat
        let expected = (iceBlueR + skyR) / 2
        XCTAssertEqual(c.r, expected, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing PolarMyFlowTests/SpeedColorRampTests 2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: error about `SpeedColorRamp` not defined.

- [ ] **Step 3: Create SpeedColorRamp.swift**

```swift
import UIKit

// A2 colour ramp: ice-blue (slow) → sky → amber → orange → red (fast)
enum SpeedColorRamp {
    private static let stops: [(t: Double, r: Double, g: Double, b: Double)] = [
        (0.00, 0xBF / 255.0, 0xDB / 255.0, 0xFE / 255.0),  // #BFDBFE ice-blue
        (0.25, 0x60 / 255.0, 0xA5 / 255.0, 0xFA / 255.0),  // #60A5FA sky
        (0.50, 0xFB / 255.0, 0xBF / 255.0, 0x24 / 255.0),  // #FBBF24 amber
        (0.75, 0xF9 / 255.0, 0x73 / 255.0, 0x16 / 255.0),  // #F97316 orange
        (1.00, 0xDC / 255.0, 0x26 / 255.0, 0x26 / 255.0),  // #DC2626 red
    ]

    static func color(for normalizedSpeed: Double) -> UIColor {
        let t = max(0, min(1, normalizedSpeed))
        guard let hiIdx = stops.firstIndex(where: { $0.t >= t }) else {
            let s = stops.last!
            return UIColor(red: s.r, green: s.g, blue: s.b, alpha: 1)
        }
        if hiIdx == 0 {
            let s = stops[0]
            return UIColor(red: s.r, green: s.g, blue: s.b, alpha: 1)
        }
        let lo = stops[hiIdx - 1]
        let hi = stops[hiIdx]
        let frac = (t - lo.t) / (hi.t - lo.t)
        return UIColor(
            red:   lo.r + (hi.r - lo.r) * frac,
            green: lo.g + (hi.g - lo.g) * frac,
            blue:  lo.b + (hi.b - lo.b) * frac,
            alpha: 1
        )
    }
}
```

- [ ] **Step 4: Run xcodegen + verify tests pass**

```bash
xcodegen generate
xcodebuild test -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing PolarMyFlowTests/SpeedColorRampTests 2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: `Test Suite 'SpeedColorRampTests' passed`

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Features/Tracks/SpeedColorRamp.swift PolarMyFlowTests/SpeedColorRampTests.swift PolarMyFlow.xcodeproj/project.pbxproj
git commit -m "feat(tracks): add A2 speed colour ramp"
```

---

## Task 4: Activity model — routePointsData

**Files:**
- Modify: `PolarMyFlow/Models/Activity.swift`

- [ ] **Step 1: Add routePointsData property and accessor**

In `Activity.swift`, after the `hasRoute` property declaration, add:

```swift
    @Attribute(.externalStorage) var routePointsData: Data?
```

Add the computed accessor just before `var sportType`:

```swift
    var routePoints: [RoutePoint] {
        guard let data = routePointsData else { return [] }
        return (try? JSONDecoder().decode([RoutePoint].self, from: data)) ?? []
    }
```

- [ ] **Step 2: Update init to accept routePointsData**

In the `init(...)` parameter list, add after `hasRoute`:

```swift
        routePointsData: Data? = nil
```

In the body of `init`, add after `self.hasRoute = hasRoute`:

```swift
        self.routePointsData = routePointsData
```

The complete updated `Activity.swift` should look like:

```swift
import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: String
    var startTime: Date
    var duration: TimeInterval
    var distance: Double
    var sportRawValue: String
    var avgSpeed: Double
    var avgPace: Double
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var ascent: Double?
    var descent: Double?
    var calories: Int?
    var hasRoute: Bool
    @Attribute(.externalStorage) var routePointsData: Data?

    var routePoints: [RoutePoint] {
        guard let data = routePointsData else { return [] }
        return (try? JSONDecoder().decode([RoutePoint].self, from: data)) ?? []
    }

    var sportType: SportType { SportType(polarString: sportRawValue) }

    init(
        id: String,
        startTime: Date,
        duration: TimeInterval,
        distance: Double,
        sportRawValue: String,
        avgSpeed: Double,
        avgPace: Double,
        avgHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        ascent: Double? = nil,
        descent: Double? = nil,
        calories: Int? = nil,
        hasRoute: Bool = false,
        routePointsData: Data? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.duration = duration
        self.distance = distance
        self.sportRawValue = sportRawValue
        self.avgSpeed = avgSpeed
        self.avgPace = avgPace
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.ascent = ascent
        self.descent = descent
        self.calories = calories
        self.hasRoute = hasRoute
        self.routePointsData = routePointsData
    }
}
```

- [ ] **Step 2: Build to confirm no compile errors**

```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Models/Activity.swift
git commit -m "feat(tracks): add routePointsData external-storage attribute to Activity"
```

---

## Task 5: GDPR GPS parsing

**Files:**
- Modify: `PolarMyFlow/Import/GDPRTrainingSession.swift`
- Create: `PolarMyFlowTests/GDPRTrainingSessionGPSTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PolarMyFlowTests/GDPRTrainingSessionGPSTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing PolarMyFlowTests/GDPRTrainingSessionGPSTests 2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: failures because GPS is not parsed yet.

- [ ] **Step 3: Add route decoding structs to GDPRTrainingSession.swift**

Replace the current `Exercise` struct and add route structs. The full updated `GDPRTrainingSession.swift`:

```swift
import Foundation

// Schema matches the real Polar GDPR export format (verified against actual
// 4.4 GB export spanning 2012–2026). Fields use the real JSON keys.
struct GDPRTrainingSession: Decodable {
    let startTime: String
    let durationMillis: Int
    let distanceMeters: Double?
    let calories: Int?
    let hrAvg: Int?
    let hrMax: Int?
    let sport: SportRef?
    let exercises: [Exercise]?

    struct SportRef: Decodable { let id: String }

    struct Exercise: Decodable {
        let ascentMeters: Double?
        let descentMeters: Double?
        let routes: RoutesContainer?
    }

    struct RoutesContainer: Decodable {
        let route: RouteData?
    }

    struct RouteData: Decodable {
        let wayPoints: [WayPoint]?
    }

    struct WayPoint: Decodable {
        let longitude: Double
        let latitude: Double
        let altitude: Double?
        let elapsedMillis: Int
    }

    func toActivity(fileID: String) -> Activity? {
        guard durationMillis > 0 else { return nil }
        guard let start = Self.parseDate(startTime) else { return nil }

        let dur = Double(durationMillis) / 1000.0
        let dist = distanceMeters ?? 0.0
        let speed = dist > 0 ? dist / dur : 0.0
        let pace  = dist > 0 ? dur / dist : 0.0

        let sportId = sport.flatMap { Int($0.id) } ?? -1
        let sportStr = SportType.from(polarSportId: sportId).rawValue

        let waypoints = exercises?.first?.routes?.route?.wayPoints ?? []
        let routePoints = waypoints.map {
            RoutePoint(latitude: $0.latitude, longitude: $0.longitude,
                       altitude: $0.altitude ?? 0, elapsedMillis: $0.elapsedMillis)
        }
        let routeData: Data? = routePoints.isEmpty ? nil : try? JSONEncoder().encode(routePoints)

        return Activity(
            id: fileID,
            startTime: start,
            duration: dur,
            distance: dist,
            sportRawValue: sportStr,
            avgSpeed: speed,
            avgPace: pace,
            avgHeartRate: hrAvg,
            maxHeartRate: hrMax,
            ascent: exercises?.first?.ascentMeters,
            descent: exercises?.first?.descentMeters,
            calories: calories,
            hasRoute: !routePoints.isEmpty,
            routePointsData: routeData
        )
    }

    // Polar GDPR export uses naive local-time strings like
    // "2025-01-15T09:00:00.000" with no timezone offset. We interpret the
    // wall clock in the device's current timezone — same policy AccessLink
    // uses — so a session shows the same time the user sees in Polar Flow.
    // DateFormatter defaults to the system TZ when timeZone is unset.
    static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let d = formatter.date(from: string) { return d }
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: string)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing PolarMyFlowTests/GDPRTrainingSessionGPSTests 2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: `Test Suite 'GDPRTrainingSessionGPSTests' passed`

- [ ] **Step 5: Run full test suite to check for regressions**

```bash
xcodebuild test -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "FAILED|passed|error:"
```

Expected: all suites passed, no errors.

- [ ] **Step 6: Commit**

```bash
git add PolarMyFlow/Import/GDPRTrainingSession.swift PolarMyFlowTests/GDPRTrainingSessionGPSTests.swift PolarMyFlow.xcodeproj/project.pbxproj
git commit -m "feat(tracks): parse GPS waypoints from GDPR export into Activity.routePointsData"
```

---

## Task 6: TrackMapView component

**Files:**
- Create: `PolarMyFlow/Features/Tracks/TrackMapView.swift`

This task has no unit tests — visual correctness verified by running the app in Task 7. The speed computation helpers are pure functions that could be extracted later for testing, but are left inline here to keep the view self-contained.

- [ ] **Step 1: Create TrackMapView.swift**

```swift
import MapKit
import SwiftUI

// MARK: - ColoredPolyline

final class ColoredPolyline: MKPolyline {
    var speedColor: UIColor = .white
    var isHalo: Bool = false
}

// MARK: - TrackMapView

struct TrackMapView: UIViewRepresentable {
    let routePoints: [RoutePoint]
    @Binding var scrubFraction: Double

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        // Non-interactive: scroll/zoom handled by the containing ScrollView + Slider
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = false
        mapView.pointOfInterestFilter = .excludingAll
        context.coordinator.buildOverlays(on: mapView, routePoints: routePoints)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.moveScrubDot(on: mapView, routePoints: routePoints, fraction: scrubFraction)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        private let scrubAnnotation = MKPointAnnotation()

        func buildOverlays(on mapView: MKMapView, routePoints: [RoutePoint]) {
            guard routePoints.count >= 2 else { return }

            let rawSpeeds = computeRawSpeeds(routePoints)
            let midTimes  = computeMidTimes(routePoints)
            let smoothed  = rollingMean(speeds: rawSpeeds, midTimes: midTimes)

            let minSpeed = smoothed.min() ?? 0
            let maxSpeed = max(minSpeed + 0.001, smoothed.max() ?? 1)

            let groups = buildSegments(waypoints: routePoints, smoothedSpeeds: smoothed,
                                       minSpeed: minSpeed, maxSpeed: maxSpeed)

            // Add halo pass first (underneath), crisp pass on top
            let halos: [ColoredPolyline] = groups.map { g in
                var coords = g.coords
                let p = ColoredPolyline(coordinates: &coords, count: coords.count)
                p.speedColor = SpeedColorRamp.color(for: g.normalizedSpeed)
                p.isHalo = true
                return p
            }
            let crisps: [ColoredPolyline] = groups.map { g in
                var coords = g.coords
                let p = ColoredPolyline(coordinates: &coords, count: coords.count)
                p.speedColor = SpeedColorRamp.color(for: g.normalizedSpeed)
                p.isHalo = false
                return p
            }
            mapView.addOverlays(halos, level: .aboveRoads)
            mapView.addOverlays(crisps, level: .aboveRoads)

            // Fit map rect to all waypoints with padding
            var rect = MKMapRect.null
            for p in routePoints {
                let pt = MKMapPoint(CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude))
                rect = rect.union(MKMapRect(x: pt.x, y: pt.y, width: 0, height: 0))
            }
            mapView.setVisibleMapRect(rect,
                edgePadding: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
                animated: false)

            // Initial scrub dot at start of route
            scrubAnnotation.coordinate = CLLocationCoordinate2D(
                latitude: routePoints[0].latitude,
                longitude: routePoints[0].longitude)
            mapView.addAnnotation(scrubAnnotation)
        }

        func moveScrubDot(on mapView: MKMapView, routePoints: [RoutePoint], fraction: Double) {
            guard !routePoints.isEmpty else { return }
            let idx = min(routePoints.count - 1, max(0, Int(fraction * Double(routePoints.count - 1))))
            scrubAnnotation.coordinate = CLLocationCoordinate2D(
                latitude: routePoints[idx].latitude,
                longitude: routePoints[idx].longitude)
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? ColoredPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineCap = .round
            renderer.lineJoin = .round
            if polyline.isHalo {
                renderer.strokeColor = polyline.speedColor.withAlphaComponent(0.32)
                renderer.lineWidth = 12.0
            } else {
                renderer.strokeColor = polyline.speedColor
                renderer.lineWidth = 4.5
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKPointAnnotation else { return nil }
            let reuseId = "scrubDot"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            view.annotation = annotation
            let size: CGFloat = 12
            view.frame = CGRect(x: 0, y: 0, width: size, height: size)
            view.layer.cornerRadius = size / 2
            // polarAmber #FBBF24
            view.backgroundColor = UIColor(red: 0xFB / 255.0, green: 0xBF / 255.0, blue: 0x24 / 255.0, alpha: 1)
            view.layer.borderWidth = 2
            view.layer.borderColor = UIColor.white.cgColor
            view.centerOffset = .zero
            return view
        }

        // MARK: - Speed computation

        private func computeRawSpeeds(_ waypoints: [RoutePoint]) -> [Double] {
            (0..<waypoints.count - 1).map { i in
                let dt = waypoints[i + 1].elapsedMillis - waypoints[i].elapsedMillis
                guard dt > 0 else { return 0 }
                return haversine(waypoints[i], waypoints[i + 1]) / (Double(dt) / 1000.0)
            }
        }

        private func computeMidTimes(_ waypoints: [RoutePoint]) -> [Int] {
            (0..<waypoints.count - 1).map { i in
                (waypoints[i].elapsedMillis + waypoints[i + 1].elapsedMillis) / 2
            }
        }

        // 5-second centred rolling mean to smooth GPS-jitter speed spikes
        private func rollingMean(speeds: [Double], midTimes: [Int], halfWindowMs: Int = 2500) -> [Double] {
            speeds.indices.map { i in
                let t = midTimes[i]
                var sum = 0.0, count = 0
                for j in speeds.indices where abs(midTimes[j] - t) <= halfWindowMs {
                    sum += speeds[j]; count += 1
                }
                return count > 0 ? sum / Double(count) : 0
            }
        }

        private func haversine(_ a: RoutePoint, _ b: RoutePoint) -> Double {
            let R = 6_371_000.0
            let lat1 = a.latitude  * .pi / 180
            let lat2 = b.latitude  * .pi / 180
            let dLat = (b.latitude  - a.latitude)  * .pi / 180
            let dLon = (b.longitude - a.longitude) * .pi / 180
            let s = sin(dLat / 2) * sin(dLat / 2)
                  + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
            return 2 * R * atan2(sqrt(s), sqrt(1 - s))
        }

        // Group consecutive waypoints in the same speed bin into a single polyline.
        // Uses 100 bins — contiguous segments with the same bin are merged, which
        // reduces overlay count to ~50–200 depending on how varied the speed is.
        private func buildSegments(
            waypoints: [RoutePoint],
            smoothedSpeeds: [Double],
            minSpeed: Double,
            maxSpeed: Double
        ) -> [(coords: [CLLocationCoordinate2D], normalizedSpeed: Double)] {
            let range = maxSpeed - minSpeed

            func normalized(_ speed: Double) -> Double {
                range > 0 ? max(0, min(1, (speed - minSpeed) / range)) : 0.5
            }
            func bin(_ speed: Double) -> Int {
                min(99, Int(normalized(speed) * 100))
            }

            var result: [(coords: [CLLocationCoordinate2D], normalizedSpeed: Double)] = []
            var current = [CLLocationCoordinate2D(latitude: waypoints[0].latitude,
                                                   longitude: waypoints[0].longitude)]
            var currentBin = bin(smoothedSpeeds[0])

            for i in 1..<waypoints.count {
                let coord = CLLocationCoordinate2D(latitude: waypoints[i].latitude,
                                                    longitude: waypoints[i].longitude)
                let speedIdx = min(i - 1, smoothedSpeeds.count - 1)
                let b = bin(smoothedSpeeds[speedIdx])

                if b != currentBin, current.count >= 2 {
                    result.append((current, normalized(smoothedSpeeds[speedIdx])))
                    currentBin = b
                    // Overlap: new group starts from last point so no gaps
                    current = [current.last!, coord]
                } else {
                    current.append(coord)
                }
            }
            if current.count >= 2 {
                result.append((current, normalized(smoothedSpeeds.last ?? 0.5)))
            }
            return result
        }
    }
}
```

- [ ] **Step 2: Run xcodegen to register the new file**

```bash
xcodegen generate
```

- [ ] **Step 3: Build to confirm it compiles**

```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PolarMyFlow/Features/Tracks/TrackMapView.swift PolarMyFlow.xcodeproj/project.pbxproj
git commit -m "feat(tracks): add TrackMapView with speed-coloured glowing polylines and scrub dot"
```

---

## Task 7: ActivityDetailView integration

**Files:**
- Modify: `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift`

- [ ] **Step 1: Add scrubFraction state and map section**

Replace the entire `ActivityDetailView.swift` with:

```swift
import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityDetailViewModel
    @State private var scrubFraction: Double = 0.0

    init(activity: Activity) {
        _viewModel = State(initialValue: ActivityDetailViewModel(activity: activity))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(viewModel)
                heroStats(viewModel)
                PolarRule(variant: .full)
                threeUp(viewModel)
                if viewModel.activity.hasRoute {
                    PolarRule(variant: .full)
                    trackSection(viewModel.activity)
                }
                // FIXME: HR zone chart not wired — Activity model has no zone-time data.
                if viewModel.ascentString != nil || viewModel.descentString != nil {
                    PolarRule(variant: .full)
                    elevation(viewModel)
                }
                if let calories = viewModel.caloriesString {
                    PolarRule(variant: .full)
                    energy(calories)
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.screenTop)
        }
        .polarBackground()
        .navigationBarHidden(true)
    }

    private func header(_ vm: ActivityDetailViewModel) -> some View {
        PolarBackHeader(
            crumb: "Log · \(vm.dateString)",
            title: vm.title,
            titleFont: .displaySmall,
            onDismiss: { dismiss() }
        )
    }

    private func heroStats(_ vm: ActivityDetailViewModel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.distanceString)
                    .font(.displayJumbo)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                Text("Km").metaLabel()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(vm.durationString)
                    .font(.displaySmall)
                    .foregroundStyle(Palette.polarSkyLight)
                Text("Moving").metaLabel()
            }
        }
    }

    private func threeUp(_ vm: ActivityDetailViewModel) -> some View {
        HStack(alignment: .top, spacing: 20) {
            statCell(value: vm.paceString, label: "Pace /km")
            Spacer()
            if let hr = vm.avgHRString {
                statCell(value: hr, label: "Avg HR")
            }
        }
    }

    private func trackSection(_ activity: Activity) -> some View {
        PolarCard {
            VStack(spacing: 12) {
                TrackMapView(routePoints: activity.routePoints, scrubFraction: $scrubFraction)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Slider(value: $scrubFraction, in: 0...1)
                    .tint(Palette.polarAmber)
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.displaySmall)
                .foregroundStyle(Palette.ink)
                .displayShadow()
            Text(label).metaLabel()
        }
    }

    private func elevation(_ vm: ActivityDetailViewModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            if let asc = vm.ascentString {
                statCell(value: asc, label: "Ascent")
            }
            Spacer()
            if let desc = vm.descentString {
                statCell(value: desc, label: "Descent")
            }
        }
    }

    private func energy(_ calories: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(calories)
                .font(.displaySmall)
                .foregroundStyle(Palette.ink)
                .displayShadow()
            Text("Energy").metaLabel()
        }
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run full test suite — no regressions**

```bash
xcodebuild test -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "FAILED|passed|error:"
```

Expected: all test suites passed.

- [ ] **Step 4: Commit**

```bash
git add PolarMyFlow/Features/ActivityList/ActivityDetailView.swift
git commit -m "feat(tracks): show speed-coloured GPS map in ActivityDetailView"
```

---

## Spec coverage check

| Spec requirement | Task |
|-----------------|------|
| Speed-coloured GPS track map | Task 6 (TrackMapView) |
| A2 colour ramp: ice-blue → sky → amber → orange → red | Task 3 (SpeedColorRamp) |
| Glow: wide translucent halo + crisp 4.5pt stroke | Task 6 (isHalo rendering) |
| Scrub dot: 12pt amber circle with white border | Task 6 (viewFor annotation) |
| Scrub dot driven by distance slider | Task 7 (Slider + scrubFraction) |
| No separate Tracks tab | Task 7 (integrated into ActivityDetailView) |
| Speed normalised per-session | Task 6 (minSpeed/maxSpeed per buildOverlays call) |
| 5-second rolling mean to suppress GPS jitter | Task 6 (rollingMean, halfWindowMs: 2500) |
| GPS parsed from GDPR export | Task 5 (GDPRTrainingSession) |
| RoutePoint stored as external blob on Activity | Task 4 (Activity.routePointsData) |
