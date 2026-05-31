# Speed-Track Glow & Honest Normalizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the GPS track's glow radiate the segment's own speed color (fast = big hot bloom, slow = tight cool line), tell the truth about flat efforts, give every point a real-derived speed, and let the user pinch-zoom/pan the map with a recenter button.

**Architecture:** Three pure, unit-tested helpers (`GlowProfile`, `SpeedInterpolator`, `SpeedNormalizer`) hold the math. `SpeedTrackRenderer` draws a per-segment colored glow scaled by `GlowProfile`. `TrackMapView.Coordinator` interpolates nil speeds and normalizes them at load time; `ActivityDetailView` adds the recenter button. All render-side — speed is consumed from already-stored `routePoints.speedKmh` (GDPR import populates it today; live-API sourcing is a separate spec).

**Tech Stack:** Swift 5.9, SwiftUI, MapKit (`MKOverlayRenderer`, `CGContext`), XCTest, XcodeGen.

---

## Conventions used by every task

- **Build (app):** `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Run one test class:** `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:PolarMyFlowTests/<ClassName>`
- **CRITICAL — new files:** After creating ANY new `.swift` file (source or test), run `xcodegen generate` **before** building/testing. XcodeGen rebuilds the `.pbxproj` from the directory glob; skipping it makes xcodebuild silently ignore the new file (false `BUILD SUCCEEDED`, tests not found).
- The iPhone 17 Pro simulator is the only modern one installed and is already booted. iPhone 16/16 Pro are NOT available.
- SourceKit/IDE diagnostics in this repo frequently report false "Cannot find type … in scope" errors after edits. Trust `xcodebuild`, not the diagnostics.

## File Structure

**Create:**
- `PolarMyFlow/Features/Tracks/GlowProfile.swift` — normalized speed → glow blur factor + alpha.
- `PolarMyFlow/Features/Tracks/SpeedInterpolator.swift` — `[Double?]` → gap-filled `[Double]`.
- `PolarMyFlow/Features/Tracks/SpeedNormalizer.swift` — `[Double]` → percentile-with-floor normalize closure.
- `PolarMyFlowTests/GlowProfileTests.swift`
- `PolarMyFlowTests/SpeedInterpolatorTests.swift`
- `PolarMyFlowTests/SpeedNormalizerTests.swift`

**Modify:**
- `PolarMyFlow/Models/RoutePoint.swift` — explicit initializer with `speedKmh: Double? = nil` default (restores the test target).
- `PolarMyFlow/Features/Tracks/TrackMapView.swift` — `Segment.normalizedSpeed`; per-segment colored glow; coordinator uses the three helpers; `filledSpeeds` drives the scrub readout; zoom/pan + recenter.
- `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift` — recenter button overlay + `recenterToken` binding.

---

### Task 1: Restore the test target — RoutePoint initializer

`RoutePoint` gained a non-defaulted `let speedKmh: Double?`, so its synthesized memberwise init now *requires* `speedKmh`. The existing `RoutePointTests` omits it, so the whole `PolarMyFlowTests` target currently fails to compile. Add an explicit initializer with a `nil` default — callers may omit `speedKmh`, the parsers still pass it, and Codable is unaffected (optional decodes as nil when absent).

**Files:**
- Modify: `PolarMyFlow/Models/RoutePoint.swift`
- Test: `PolarMyFlowTests/RoutePointTests.swift` (already exists; add one case)

- [ ] **Step 1: Run the existing test class to confirm the target is broken**

Run: `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:PolarMyFlowTests/RoutePointTests`
Expected: FAIL — compile error `missing argument for parameter 'speedKmh' in call` in `RoutePointTests.swift`.

- [ ] **Step 2: Add the explicit initializer**

Replace the whole body of `PolarMyFlow/Models/RoutePoint.swift` with:

```swift
import Foundation

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let elapsedMillis: Int
    let speedKmh: Double?

    init(latitude: Double, longitude: Double, altitude: Double,
         elapsedMillis: Int, speedKmh: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.elapsedMillis = elapsedMillis
        self.speedKmh = speedKmh
    }
}
```

- [ ] **Step 3: Add a test that locks the default + speed round-trip**

In `PolarMyFlowTests/RoutePointTests.swift`, add this method inside the `RoutePointTests` class (after `testArrayCodableRoundTrip`):

```swift
func testSpeedKmhDefaultsNilAndRoundTrips() throws {
    let noSpeed = RoutePoint(latitude: 1, longitude: 2, altitude: 3, elapsedMillis: 4)
    XCTAssertNil(noSpeed.speedKmh)

    let withSpeed = RoutePoint(latitude: 1, longitude: 2, altitude: 3,
                               elapsedMillis: 4, speedKmh: 16.1)
    let decoded = try JSONDecoder().decode(
        RoutePoint.self, from: JSONEncoder().encode(withSpeed))
    XCTAssertEqual(decoded.speedKmh ?? -1, 16.1, accuracy: 0.001)

    // Backward compatibility: a blob without the key decodes speedKmh as nil.
    let legacy = #"{"latitude":1,"longitude":2,"altitude":3,"elapsedMillis":4}"#
    let legacyDecoded = try JSONDecoder().decode(
        RoutePoint.self, from: Data(legacy.utf8))
    XCTAssertNil(legacyDecoded.speedKmh)
}
```

- [ ] **Step 4: Run the test class to verify it passes**

Run: `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:PolarMyFlowTests/RoutePointTests`
Expected: PASS (all `RoutePointTests` methods).

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Models/RoutePoint.swift PolarMyFlowTests/RoutePointTests.swift
git commit -m "fix(tracks): explicit RoutePoint init with nil speedKmh default, restore test target

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: GlowProfile (pure helper, TDD)

Maps a normalized speed `n` (0…1) to the glow's pre-zoom blur factor and alpha. Strong-contrast `n^1.8` ramp: slow → near-hairline dim halo; fast → large bright bloom.

**Files:**
- Create: `PolarMyFlow/Features/Tracks/GlowProfile.swift`
- Create: `PolarMyFlowTests/GlowProfileTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PolarMyFlowTests/GlowProfileTests.swift`:

```swift
import XCTest
@testable import PolarMyFlow

final class GlowProfileTests: XCTestCase {
    func testBlurFactorEndpoints() {
        XCTAssertEqual(GlowProfile.blurFactor(0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.blurFactor(1), 12.0, accuracy: 1e-9)
    }

    func testAlphaEndpoints() {
        XCTAssertEqual(GlowProfile.alpha(0), 0.12, accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(1), 0.90, accuracy: 1e-9)
    }

    func testMonotonicInSpeed() {
        XCTAssertLessThan(GlowProfile.blurFactor(0.25), GlowProfile.blurFactor(0.75))
        XCTAssertLessThan(GlowProfile.alpha(0.25), GlowProfile.alpha(0.75))
    }

    func testClampsOutOfRange() {
        XCTAssertEqual(GlowProfile.blurFactor(-1), GlowProfile.blurFactor(0), accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.blurFactor(2),  GlowProfile.blurFactor(1), accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(-1),      GlowProfile.alpha(0),      accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(2),       GlowProfile.alpha(1),      accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Regenerate project and run the test to verify it fails**

Run: `xcodegen generate && xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:PolarMyFlowTests/GlowProfileTests`
Expected: FAIL — `Cannot find 'GlowProfile' in scope`.

- [ ] **Step 3: Write the implementation**

Create `PolarMyFlow/Features/Tracks/GlowProfile.swift`:

```swift
import Foundation

/// Maps a normalized speed (0...1) to the track glow's pre-zoom blur factor and
/// alpha. Strong-contrast ramp: slow segments get a near-hairline, near-invisible
/// halo; fast segments bloom large and bright. The exponent makes the contrast
/// aggressive rather than linear.
enum GlowProfile {
    private static let exponent = 1.8

    /// Pre-zoom blur radius factor. The renderer divides this by `zoomScale`.
    static func blurFactor(_ n: Double) -> Double {
        0.5 + 11.5 * pow(clamp(n), exponent)
    }

    /// Glow opacity in 0...1.
    static func alpha(_ n: Double) -> Double {
        0.12 + 0.78 * pow(clamp(n), exponent)
    }

    private static func clamp(_ n: Double) -> Double { max(0, min(1, n)) }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:PolarMyFlowTests/GlowProfileTests`
Expected: PASS.

- [ ] **Step 5: Commit**

The `.xcodeproj` is gitignored (regenerated by XcodeGen), so commit only the source + test files:

```bash
git add PolarMyFlow/Features/Tracks/GlowProfile.swift PolarMyFlowTests/GlowProfileTests.swift
git commit -m "feat(tracks): GlowProfile maps normalized speed to glow blur + alpha

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: SpeedInterpolator (pure helper, TDD)

Fills nil gaps so every route point has a real-derived speed. Interior gaps → linear interpolation between bracketing known values; leading/trailing gaps → nearest known value; all-nil → empty array (caller falls back to flat amber).

**Files:**
- Create: `PolarMyFlow/Features/Tracks/SpeedInterpolator.swift`
- Create: `PolarMyFlowTests/SpeedInterpolatorTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PolarMyFlowTests/SpeedInterpolatorTests.swift`:

```swift
import XCTest
@testable import PolarMyFlow

final class SpeedInterpolatorTests: XCTestCase {
    func testInteriorGapInterpolates() {
        XCTAssertEqual(SpeedInterpolator.fill([10, nil, 20]), [10, 15, 20])
    }

    func testLeadingGapTakesFirstKnown() {
        XCTAssertEqual(SpeedInterpolator.fill([nil, nil, 12]), [12, 12, 12])
    }

    func testTrailingGapTakesLastKnown() {
        XCTAssertEqual(SpeedInterpolator.fill([12, nil, nil]), [12, 12, 12])
    }

    func testAllNilReturnsEmpty() {
        XCTAssertEqual(SpeedInterpolator.fill([nil, nil]), [])
    }

    func testEmptyReturnsEmpty() {
        XCTAssertEqual(SpeedInterpolator.fill([]), [])
    }

    func testNoNilPassthrough() {
        XCTAssertEqual(SpeedInterpolator.fill([5, 6, 7]), [5, 6, 7])
    }

    func testCombinedLeadingInteriorTrailing() {
        XCTAssertEqual(SpeedInterpolator.fill([nil, 10, nil, nil, 40, nil]),
                       [10, 10, 20, 30, 40, 40])
    }
}
```

- [ ] **Step 2: Regenerate project and run the test to verify it fails**

Run: `xcodegen generate && xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:PolarMyFlowTests/SpeedInterpolatorTests`
Expected: FAIL — `Cannot find 'SpeedInterpolator' in scope`.

- [ ] **Step 3: Write the implementation**

Create `PolarMyFlow/Features/Tracks/SpeedInterpolator.swift`:

```swift
import Foundation

/// Fills nil gaps in a per-point speed series so every point has a real-derived
/// value. Interior gaps are linearly interpolated between the nearest known
/// values; leading/trailing gaps take the nearest known value. Returns an empty
/// array when no value is known (caller then falls back to a flat color).
enum SpeedInterpolator {
    static func fill(_ speeds: [Double?]) -> [Double] {
        let knownIndices = speeds.indices.filter { speeds[$0] != nil }
        guard let first = knownIndices.first, let last = knownIndices.last else {
            return []   // all-nil or empty input
        }

        var result = [Double](repeating: 0, count: speeds.count)

        // Leading gap → first known value; trailing gap → last known value.
        let firstValue = speeds[first]!
        for i in 0..<first { result[i] = firstValue }
        let lastValue = speeds[last]!
        for i in (last + 1)..<speeds.count { result[i] = lastValue }

        // Known points copy through; interior gaps interpolate linearly by index.
        result[first] = firstValue
        var prevKnown = first
        for k in knownIndices.dropFirst() {
            result[k] = speeds[k]!
            let gap = k - prevKnown
            if gap > 1 {
                let lo = speeds[prevKnown]!
                let hi = speeds[k]!
                for j in (prevKnown + 1)..<k {
                    let t = Double(j - prevKnown) / Double(gap)
                    result[j] = lo + (hi - lo) * t
                }
            }
            prevKnown = k
        }
        return result
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:PolarMyFlowTests/SpeedInterpolatorTests`
Expected: PASS.

- [ ] **Step 5: Commit**

The `.xcodeproj` is gitignored (regenerated by XcodeGen), so commit only the source + test files:

```bash
git add PolarMyFlow/Features/Tracks/SpeedInterpolator.swift PolarMyFlowTests/SpeedInterpolatorTests.swift
git commit -m "feat(tracks): SpeedInterpolator fills nil speed gaps from neighbours

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: SpeedNormalizer (pure helper, TDD)

Builds the percentile normalizer mapping speed (km/h) → 0…1. Median anchors at 0.5; the scale stretches over p10→p90 but never tighter than a 3 km/h `minSpan`, so a steady effort stays near amber instead of a false rainbow. <2 samples → constant 0.5.

**Files:**
- Create: `PolarMyFlow/Features/Tracks/SpeedNormalizer.swift`
- Create: `PolarMyFlowTests/SpeedNormalizerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PolarMyFlowTests/SpeedNormalizerTests.swift`:

```swift
import XCTest
@testable import PolarMyFlow

final class SpeedNormalizerTests: XCTestCase {
    func testFewerThanTwoIsConstantHalf() {
        let n0 = SpeedNormalizer.make(from: [])
        XCTAssertEqual(n0(99), 0.5, accuracy: 1e-9)
        let n1 = SpeedNormalizer.make(from: [5])
        XCTAssertEqual(n1(5),  0.5, accuracy: 1e-9)
        XCTAssertEqual(n1(50), 0.5, accuracy: 1e-9)
    }

    func testVariedInputSpansFullRamp() {
        // p10 = 2, p50 = 10, p90 = 18; half-span = 8 km/h.
        let speeds = [0.0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
        let n = SpeedNormalizer.make(from: speeds)
        XCTAssertEqual(n(10), 0.5, accuracy: 1e-9)   // p50 → amber
        XCTAssertEqual(n(18), 1.0, accuracy: 1e-9)   // p90 → red
        XCTAssertEqual(n(2),  0.0, accuracy: 1e-9)   // p10 → ice-blue
    }

    func testFloorPreventsFalseContrastOnFlatEffort() {
        // All-equal speeds: real span is 0, so the 3 km/h minSpan floor governs.
        let n = SpeedNormalizer.make(from: [10.0, 10, 10, 10])
        XCTAssertEqual(n(10),    0.5,  accuracy: 1e-9)   // median stays amber
        XCTAssertEqual(n(10.75), 0.75, accuracy: 1e-9)   // mid-ramp, not saturated
        XCTAssertEqual(n(11.5),  1.0,  accuracy: 1e-9)   // a full half-span reaches the end
    }
}
```

- [ ] **Step 2: Regenerate project and run the test to verify it fails**

Run: `xcodegen generate && xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:PolarMyFlowTests/SpeedNormalizerTests`
Expected: FAIL — `Cannot find 'SpeedNormalizer' in scope`.

- [ ] **Step 3: Write the implementation**

Create `PolarMyFlow/Features/Tracks/SpeedNormalizer.swift`:

```swift
import Foundation

/// Builds a percentile-based normalizer mapping a speed (km/h) to 0...1 for the
/// color ramp. The median anchors at 0.5; the scale stretches across the
/// p10→p90 span but never tighter than `minSpan`, so a steady effort stays near
/// amber instead of being blown into a false rainbow. Fewer than two samples →
/// a constant 0.5.
enum SpeedNormalizer {
    static let minSpan = 3.0   // km/h

    static func make(from speeds: [Double]) -> (Double) -> Double {
        guard speeds.count >= 2 else { return { _ in 0.5 } }
        let sorted = speeds.sorted()
        func pct(_ p: Double) -> Double {
            let idx = Int((p * Double(sorted.count - 1)).rounded())
            return sorted[max(0, min(sorted.count - 1, idx))]
        }
        let p10 = pct(0.10), p50 = pct(0.50), p90 = pct(0.90)
        let half = max((p90 - p10) / 2.0, minSpan / 2.0)
        return { speed in max(0, min(1, 0.5 + 0.5 * (speed - p50) / half)) }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:PolarMyFlowTests/SpeedNormalizerTests`
Expected: PASS.

- [ ] **Step 5: Commit**

The `.xcodeproj` is gitignored (regenerated by XcodeGen), so commit only the source + test files:

```bash
git add PolarMyFlow/Features/Tracks/SpeedNormalizer.swift PolarMyFlowTests/SpeedNormalizerTests.swift
git commit -m "feat(tracks): SpeedNormalizer percentile scale with 3km/h min-span floor

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Wire renderer + coordinator to the helpers (per-segment colored glow)

Add `normalizedSpeed` to `Segment`, rewrite the glow pass to a per-segment colored speed-scaled bloom, and have the coordinator interpolate + normalize via the new helpers. The scrub readout reads the gap-filled speeds so it never freezes. No unit test (rendering); verified by build + simulator.

**Files:**
- Modify: `PolarMyFlow/Features/Tracks/TrackMapView.swift`

- [ ] **Step 1: Add `normalizedSpeed` to `Segment`**

In `PolarMyFlow/Features/Tracks/TrackMapView.swift`, replace the `Segment` struct (inside `SpeedTrackOverlay`):

```swift
    struct Segment {
        let coords: [CLLocationCoordinate2D]
        let color: UIColor
    }
```

with:

```swift
    struct Segment {
        let coords: [CLLocationCoordinate2D]
        let color: UIColor
        let normalizedSpeed: Double
    }
```

- [ ] **Step 2: Rewrite the renderer's `draw` glow pass**

In the same file, replace the entire `draw(_:zoomScale:in:)` method of `SpeedTrackRenderer` with:

```swift
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let lineWidth = 2.5 / zoomScale

        context.setLineJoin(.round)

        // Glow pass — each segment in its own transparency layer, with a shadow
        // tinted to the segment's own speed color and scaled by speed. Fast
        // segments bloom large and bright; slow segments stay a tight, dim line.
        // Adjacent fast→slow boundaries let the hot bloom spill over the cool
        // line, so heat appears to radiate from the fast sections.
        for seg in track.segments {
            guard let path = makePath(seg.coords) else { continue }
            let blur  = GlowProfile.blurFactor(seg.normalizedSpeed) / zoomScale
            let alpha = GlowProfile.alpha(seg.normalizedSpeed)
            context.saveGState()
            context.setShadow(offset: .zero, blur: blur,
                              color: seg.color.withAlphaComponent(alpha).cgColor)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            context.setLineCap(.round)
            context.setLineWidth(lineWidth)
            context.setStrokeColor(seg.color.cgColor)
            context.addPath(path)
            context.strokePath()
            context.endTransparencyLayer()
            context.restoreGState()
        }

        // Crisp line pass — butt caps so adjacent segments meet flush at their
        // shared coordinate with no round-cap overlap.
        context.setLineCap(.butt)
        context.setLineWidth(lineWidth)
        for seg in track.segments {
            guard let path = makePath(seg.coords) else { continue }
            context.setStrokeColor(seg.color.cgColor)
            context.addPath(path)
            context.strokePath()
        }
    }
```

- [ ] **Step 3: Rename the coordinator's stored speeds to filled `[Double]`**

In the `Coordinator` class, replace:

```swift
        private(set) var speedsKmh: [Double?] = []
```

with:

```swift
        private(set) var filledSpeeds: [Double] = []
```

- [ ] **Step 4: Replace the speed/normalize/segment-building block in `buildOverlays`**

In `buildOverlays`, replace this block:

```swift
            speedsKmh = routePoints.map { $0.speedKmh }

            let knownSpeeds = speedsKmh.compactMap { $0 }
            let normalize: (Double) -> Double
            if knownSpeeds.count >= 2 {
                let sorted = knownSpeeds.sorted()
                func pct(_ p: Double) -> Double {
                    sorted[max(0, min(sorted.count - 1, Int((p * Double(sorted.count - 1)).rounded())))]
                }
                let p10 = pct(0.10), p50 = pct(0.50), p90 = pct(0.90)
                let half = max((p90 - p10) / 2.0, 0.001)
                normalize = { speed in max(0, min(1, 0.5 + 0.5 * (speed - p50) / half)) }
            } else {
                normalize = { _ in 0.5 }
            }

            func bin(_ speed: Double?) -> Int {
                guard let s = speed else { return 50 }
                return min(99, Int(normalize(s) * 100))
            }

            var result: [(coords: [CLLocationCoordinate2D], normalizedSpeed: Double)] = []
            var current = [CLLocationCoordinate2D(latitude: routePoints[0].latitude,
                                                   longitude: routePoints[0].longitude)]
            var currentBin = bin(speedsKmh[0])

            for i in 1..<routePoints.count {
                let coord = CLLocationCoordinate2D(latitude: routePoints[i].latitude,
                                                    longitude: routePoints[i].longitude)
                let b = bin(speedsKmh[i])
                if b != currentBin, current.count >= 2 {
                    result.append((current, Double(currentBin) / 99.0))
                    currentBin = b
                    current = [current.last!, coord]
                } else {
                    current.append(coord)
                }
            }
            if current.count >= 2 {
                result.append((current, Double(currentBin) / 99.0))
            }

            let segments = result.map {
                SpeedTrackOverlay.Segment(coords: $0.coords,
                                          color: SpeedColorRamp.color(for: $0.normalizedSpeed))
            }
```

with:

```swift
            filledSpeeds = SpeedInterpolator.fill(routePoints.map { $0.speedKmh })
            let normalize = SpeedNormalizer.make(from: filledSpeeds)

            // No recorded speed at all → flat amber (normalized 0.5).
            func bin(_ i: Int) -> Int {
                guard !filledSpeeds.isEmpty else { return 50 }
                return min(99, Int(normalize(filledSpeeds[i]) * 100))
            }

            var result: [(coords: [CLLocationCoordinate2D], normalizedSpeed: Double)] = []
            var current = [CLLocationCoordinate2D(latitude: routePoints[0].latitude,
                                                   longitude: routePoints[0].longitude)]
            var currentBin = bin(0)

            for i in 1..<routePoints.count {
                let coord = CLLocationCoordinate2D(latitude: routePoints[i].latitude,
                                                    longitude: routePoints[i].longitude)
                let b = bin(i)
                if b != currentBin, current.count >= 2 {
                    result.append((current, Double(currentBin) / 99.0))
                    currentBin = b
                    current = [current.last!, coord]
                } else {
                    current.append(coord)
                }
            }
            if current.count >= 2 {
                result.append((current, Double(currentBin) / 99.0))
            }

            let segments = result.map {
                SpeedTrackOverlay.Segment(coords: $0.coords,
                                          color: SpeedColorRamp.color(for: $0.normalizedSpeed),
                                          normalizedSpeed: $0.normalizedSpeed)
            }
```

- [ ] **Step 5: Update `updateUIView` to read `filledSpeeds`**

Replace the body of `updateUIView` with:

```swift
    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.rebuildIfNeeded(on: mapView, routePoints: routePoints)
        context.coordinator.moveScrubDot(on: mapView, routePoints: routePoints, fraction: scrubFraction)
        let speeds = context.coordinator.filledSpeeds
        guard !speeds.isEmpty else { return }
        let idx = max(0, min(speeds.count - 1, Int(scrubFraction * Double(speeds.count - 1))))
        let rounded = (speeds[idx] * 10).rounded() / 10
        if abs(rounded - speedKmh) > 0.05 {
            DispatchQueue.main.async { speedKmh = rounded }
        }
    }
```

- [ ] **Step 6: Build the app and verify it compiles**

Run: `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `BUILD SUCCEEDED`. (No new files, so no `xcodegen generate` needed.)

- [ ] **Step 7: Visual check in the simulator**

Launch the app, open an activity that has a GPS route (a GDPR-imported run/ride), and confirm:
- Fast sections of the track glow with a large, bright **warm** (orange/red) bloom; slow sections are a tight, dim **cool** (blue) line — the glow color matches the line color, not white.
- No obvious bright seams at segment joins.
- Dragging the scrub slider updates the km/h number smoothly, including at the very start of the route (no frozen 0.0 during the initial sensor-lock seconds).
- A genuinely steady-pace activity does NOT show a dramatic full blue→red rainbow.

- [ ] **Step 8: Commit**

```bash
git add PolarMyFlow/Features/Tracks/TrackMapView.swift
git commit -m "feat(tracks): per-segment colored speed-scaled glow; interpolate + normalize via helpers

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Pinch-zoom + pan with recenter button

Enable map zoom/pan, add a recenter control that snaps back to the full-route bounds, and make sure scrubbing no longer force-recenters.

**Files:**
- Modify: `PolarMyFlow/Features/Tracks/TrackMapView.swift`
- Modify: `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift`

- [ ] **Step 1: Enable zoom/pan in `makeUIView`**

In `TrackMapView.swift`, in `makeUIView`, replace:

```swift
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
```

with:

```swift
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isRotateEnabled = false   // keep north-up
        mapView.isPitchEnabled = false
```

- [ ] **Step 2: Add the `recenterToken` binding to `TrackMapView`**

In the `TrackMapView` struct, add the binding next to the existing ones. Replace:

```swift
    let routePoints: [RoutePoint]
    @Binding var scrubFraction: Double
    @Binding var speedKmh: Double
```

with:

```swift
    let routePoints: [RoutePoint]
    @Binding var scrubFraction: Double
    @Binding var speedKmh: Double
    @Binding var recenterToken: Int
```

- [ ] **Step 3: Store the route bounds and add a recenter method in the Coordinator**

In the `Coordinator` class, add these stored properties next to `filledSpeeds`:

```swift
        private var routeRect: MKMapRect = .null
        private var lastRecenterToken = 0
```

In `buildOverlays`, the fit rect is computed as `let fitRect = rect`. Immediately after that line, add:

```swift
            routeRect = fitRect
```

Then add this method to the `Coordinator` (e.g. after `moveScrubDot`):

```swift
        func recenterIfNeeded(on mapView: MKMapView, token: Int) {
            guard token != lastRecenterToken else { return }
            lastRecenterToken = token
            guard !routeRect.isNull else { return }
            mapView.setVisibleMapRect(routeRect,
                edgePadding: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
                animated: true)
        }
```

- [ ] **Step 4: Call `recenterIfNeeded` from `updateUIView`**

In `updateUIView`, add the recenter call right after the `moveScrubDot` line:

```swift
        context.coordinator.recenterIfNeeded(on: mapView, token: recenterToken)
```

(Place it between the `moveScrubDot(...)` line and the `let speeds = ...` line. The token starts at 0 and `lastRecenterToken` starts at 0, so the first render does not recenter — the initial auto-fit in `buildOverlays` still owns the first framing.)

- [ ] **Step 5: Add the recenter state + button in `ActivityDetailView`**

In `ActivityDetailView.swift`, add the state next to the other `@State` properties (after `scrubSpeedKmh`):

```swift
    @State private var recenterToken: Int = 0
```

Then replace `trackSection()` with:

```swift
    private func trackSection() -> some View {
        VStack(spacing: 12) {
            TrackMapView(routePoints: cachedRoutePoints,
                         scrubFraction: $scrubFraction,
                         speedKmh: $scrubSpeedKmh,
                         recenterToken: $recenterToken)
                .frame(height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        recenterToken += 1
                    } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(12)
                    .accessibilityLabel("Recenter map on route")
                }
                .padding(.horizontal, -Spacing.screenMargin)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", scrubSpeedKmh))
                    .font(.displaySmall)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                Text("km/h").metaLabel()
                Spacer()
            }
            Slider(value: $scrubFraction, in: 0...1)
                .tint(Palette.polarAmber)
        }
    }
```

- [ ] **Step 6: Build the app and verify it compiles**

Run: `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `BUILD SUCCEEDED`. (No new files; no `xcodegen generate` needed.)

- [ ] **Step 7: Visual check in the simulator**

Open an activity with a route and confirm:
- Pinch-zoom and drag both work on the map.
- The "scope" button sits at the bottom-trailing corner of the map; tapping it animates back to framing the whole route.
- Dragging the scrub slider moves the dot but does NOT yank the map back to full-route framing while you're zoomed in.

- [ ] **Step 8: Commit**

```bash
git add PolarMyFlow/Features/Tracks/TrackMapView.swift PolarMyFlow/Features/ActivityList/ActivityDetailView.swift
git commit -m "feat(tracks): pinch-zoom/pan map with recenter-to-route button

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final verification (after all tasks)

- [ ] **Full test suite passes**

Run: `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
Expected: all `PolarMyFlowTests` pass, including the three new helper suites and the restored `RoutePointTests`.

- [ ] **Spec acceptance walkthrough** — on a real GDPR-imported route, confirm all four goals from the spec: (1) glow radiates the segment color, hot/big when fast and tight/dim when slow; (2) steady efforts no longer show a false rainbow; (3) the scrub readout shows a real value everywhere and never freezes; (4) the map pinch-zooms/pans with a working recenter button.
