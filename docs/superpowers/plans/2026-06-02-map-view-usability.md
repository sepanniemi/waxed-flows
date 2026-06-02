# Map View Usability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the GPS map the hero of `ActivityDetailView` — map-first layout, neon speed-colored route, and MML Maastokartta topo tiles.

**Architecture:** Four independent changes applied in order: (1) add `speedKmh` formatting to the view-model layer; (2) tune the color ramp and glow profile; (3) add `MMLTileOverlay` and wire it into `TrackMapView`; (4) restructure `ActivityDetailView` to put the map first. Each task builds on the last and is independently testable and committable.

**Tech Stack:** Swift/SwiftUI, MapKit (`MKTileOverlay`, `MKOverlayRenderer`), XCTest, xcodegen

---

## File Map

| File | Action | What changes |
|------|--------|--------------|
| `PolarMyFlow/Models/ActivityFormatting.swift` | Modify | Add `speedKmh(_:)` formatter |
| `PolarMyFlow/Features/ActivityList/ActivityDetailViewModel.swift` | Modify | Add `speedString` computed property |
| `PolarMyFlowTests/ActivityDetailViewModelTests.swift` | Modify | Add `speedString` tests |
| `PolarMyFlow/Features/Tracks/SpeedColorRamp.swift` | Modify | Darken stops at t=0.00 and t=0.25 |
| `PolarMyFlowTests/SpeedColorRampTests.swift` | Modify | Update endpoint/quarter tests to new colors |
| `PolarMyFlow/Features/Tracks/GlowProfile.swift` | Modify | Retune blur/alpha constants |
| `PolarMyFlowTests/GlowProfileTests.swift` | Modify | Update endpoint assertions to new constants |
| `PolarMyFlow/Features/Tracks/MMLTileOverlay.swift` | **Create** | URL-template builder + `MKTileOverlay` factory |
| `PolarMyFlowTests/MMLTileOverlayTests.swift` | **Create** | Unit-test the URL template |
| `PolarMyFlow/BuildConfig.swift` | Modify | Add `mmlApiKey` |
| `PolarMyFlow/Features/Tracks/TrackMapView.swift` | Modify | Add tile overlay; update renderer branch; add attribution label |
| `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift` | Modify | Map-first layout with `GeometryReader`; compact stat strip; attribution |
| `project.yml` | No change | MapKit already a dependency |

> **After creating `MMLTileOverlay.swift`:** run `xcodegen generate` before building — a stale `.pbxproj` silently skips new files and still reports BUILD SUCCEEDED.

---

## Task 1: Add `speedKmh` formatter and `speedString` view-model property

**Files:**
- Modify: `PolarMyFlow/Models/ActivityFormatting.swift`
- Modify: `PolarMyFlow/Features/ActivityList/ActivityDetailViewModel.swift`
- Modify: `PolarMyFlowTests/ActivityDetailViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `PolarMyFlowTests/ActivityDetailViewModelTests.swift` inside the class body:

```swift
func test_speedString_oneDecimalKmh() {
    // avgSpeed stored as m/s; 10 m/s = 36.0 km/h
    let vm = makeVM(duration: 1000, distance: 10_000) // avgSpeed = 10 m/s
    XCTAssertEqual(vm.speedString, "36.0 km/h")
}

func test_speedString_zeroSpeed() {
    let vm = makeVM(duration: 3600, distance: 0) // avgSpeed = 0
    XCTAssertEqual(vm.speedString, "0.0 km/h")
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/ActivityDetailViewModelTests \
  2>&1 | grep -E "FAILED|error:|speedString"
```

Expected: compile error — `value of type 'ActivityDetailViewModel' has no member 'speedString'`

- [ ] **Step 3: Add `speedKmh` to `ActivityFormatting`**

In `PolarMyFlow/Models/ActivityFormatting.swift`, add after `paceMinPerKm`:

```swift
static func speedKmh(_ metresPerSecond: Double) -> String {
    String(format: "%.1f km/h", metresPerSecond * 3.6)
}
```

- [ ] **Step 4: Add `speedString` to `ActivityDetailViewModel`**

In `PolarMyFlow/Features/ActivityList/ActivityDetailViewModel.swift`, add after `paceString`:

```swift
var speedString: String {
    ActivityFormatting.speedKmh(activity.avgSpeed)
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/ActivityDetailViewModelTests \
  2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add PolarMyFlow/Models/ActivityFormatting.swift \
        PolarMyFlow/Features/ActivityList/ActivityDetailViewModel.swift \
        PolarMyFlowTests/ActivityDetailViewModelTests.swift
git commit -m "feat(detail): add speedKmh formatter and speedString view-model property"
```

---

## Task 2: Darken the cool end of `SpeedColorRamp`

The old stops at t=0.00 (`#BFDBFE` ice-blue) and t=0.25 (`#60A5FA` sky) are near-white on light topo tiles. Replace them with deep blues that contrast on Maastokartta's cream/tan background.

**Files:**
- Modify: `PolarMyFlow/Features/Tracks/SpeedColorRamp.swift`
- Modify: `PolarMyFlowTests/SpeedColorRampTests.swift`

- [ ] **Step 1: Update the failing tests first**

The existing `testColorAtZero_isIceBlue` and `testColorAtQuarter_isSky` tests assert the old values. Update them to the new darker blues in `PolarMyFlowTests/SpeedColorRampTests.swift`:

```swift
func testColorAtZero_isDeepBlue() {
    let c = components(SpeedColorRamp.color(for: 0.0))
    XCTAssertEqual(c.r, 0x25 / 255.0, accuracy: 0.01)  // #2563EB
    XCTAssertEqual(c.g, 0x63 / 255.0, accuracy: 0.01)
    XCTAssertEqual(c.b, 0xEB / 255.0, accuracy: 0.01)
}

func testColorAtQuarter_isMediumBlue() {
    let c = components(SpeedColorRamp.color(for: 0.25))
    XCTAssertEqual(c.r, 0x3B / 255.0, accuracy: 0.01)  // #3B82F6
    XCTAssertEqual(c.g, 0x82 / 255.0, accuracy: 0.01)
    XCTAssertEqual(c.b, 0xF6 / 255.0, accuracy: 0.01)
}
```

Also remove (or rename) the old `testColorAtZero_isIceBlue` and `testColorAtQuarter_isSky` methods, then update `testColorBelowZero_clampsToIceBlue` to use the new name/expectation:

```swift
func testColorBelowZero_clampsToDeepBlue() {
    let atZero = components(SpeedColorRamp.color(for: 0.0))
    let below  = components(SpeedColorRamp.color(for: -1.0))
    XCTAssertEqual(below.r, atZero.r, accuracy: 0.001)
    XCTAssertEqual(below.g, atZero.g, accuracy: 0.001)
    XCTAssertEqual(below.b, atZero.b, accuracy: 0.001)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/SpeedColorRampTests \
  2>&1 | grep -E "PASSED|FAILED|XCTAssert"
```

Expected: `testColorAtZero_isDeepBlue` and `testColorAtQuarter_isMediumBlue` FAIL (wrong color values).

- [ ] **Step 3: Update `SpeedColorRamp.swift`**

Replace the `stops` array in `PolarMyFlow/Features/Tracks/SpeedColorRamp.swift`:

```swift
private static let stops: [(t: Double, r: Double, g: Double, b: Double)] = [
    (0.00, 0x25 / 255.0, 0x63 / 255.0, 0xEB / 255.0),  // #2563EB deep blue (slow)
    (0.25, 0x3B / 255.0, 0x82 / 255.0, 0xF6 / 255.0),  // #3B82F6 medium blue
    (0.50, 0xFB / 255.0, 0xBF / 255.0, 0x24 / 255.0),  // #FBBF24 amber
    (0.75, 0xF9 / 255.0, 0x73 / 255.0, 0x16 / 255.0),  // #F97316 orange
    (1.00, 0xDC / 255.0, 0x26 / 255.0, 0x26 / 255.0),  // #DC2626 red (fast)
]
```

Also update the comment on line 4:

```swift
// A3 colour ramp: deep blue (slow) → medium blue → amber → orange → red (fast)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/SpeedColorRampTests \
  2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Features/Tracks/SpeedColorRamp.swift \
        PolarMyFlowTests/SpeedColorRampTests.swift
git commit -m "feat(tracks): darken cool end of SpeedColorRamp for topo tile contrast"
```

---

## Task 3: Retune `GlowProfile` for neon-bloom character

Replace the steep (exponent 1.8, near-invisible floor) curve with a gentler curve that glows along the whole line.

New constants: `blur = 4 + 16·n^1.2` (range 4…20), `alpha = 0.30 + 0.65·n^1.2` (range 0.30…0.95).

**Files:**
- Modify: `PolarMyFlow/Features/Tracks/GlowProfile.swift`
- Modify: `PolarMyFlowTests/GlowProfileTests.swift`

- [ ] **Step 1: Update tests first**

Replace the body of `PolarMyFlowTests/GlowProfileTests.swift`:

```swift
import XCTest
@testable import PolarMyFlow

final class GlowProfileTests: XCTestCase {
    func testBlurFactorEndpoints() {
        XCTAssertEqual(GlowProfile.blurFactor(0), 4.0,  accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.blurFactor(1), 20.0, accuracy: 1e-9)
    }

    func testAlphaEndpoints() {
        XCTAssertEqual(GlowProfile.alpha(0), 0.30, accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(1), 0.95, accuracy: 1e-9)
    }

    func testMonotonicInSpeed() {
        XCTAssertLessThan(GlowProfile.blurFactor(0.25), GlowProfile.blurFactor(0.75))
        XCTAssertLessThan(GlowProfile.alpha(0.25),      GlowProfile.alpha(0.75))
    }

    func testClampsOutOfRange() {
        XCTAssertEqual(GlowProfile.blurFactor(-1), GlowProfile.blurFactor(0), accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.blurFactor(2),  GlowProfile.blurFactor(1), accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(-1),      GlowProfile.alpha(0),      accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(2),       GlowProfile.alpha(1),      accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/GlowProfileTests \
  2>&1 | grep -E "PASSED|FAILED|XCTAssert"
```

Expected: `testBlurFactorEndpoints` and `testAlphaEndpoints` FAIL (old constants produce 0.5/12.0 and 0.12/0.90).

- [ ] **Step 3: Retune `GlowProfile.swift`**

Replace the entire content of `PolarMyFlow/Features/Tracks/GlowProfile.swift`:

```swift
import Foundation

enum GlowProfile {
    private static let exponent = 1.2

    /// Pre-zoom blur radius factor in 4...20. The renderer divides this by `zoomScale`.
    /// Slow segments get a moderate visible halo; fast segments bloom large and bright.
    static func blurFactor(_ n: Double) -> Double {
        4.0 + 16.0 * pow(clamp(n), exponent)
    }

    /// Glow opacity in 0.30...0.95. Visible along the whole line, hottest on fast.
    static func alpha(_ n: Double) -> Double {
        0.30 + 0.65 * pow(clamp(n), exponent)
    }

    private static func clamp(_ n: Double) -> Double { max(0, min(1, n)) }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/GlowProfileTests \
  2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Features/Tracks/GlowProfile.swift \
        PolarMyFlowTests/GlowProfileTests.swift
git commit -m "feat(tracks): retune GlowProfile to neon-bloom character (exponent 1.2, visible floor)"
```

---

## Task 4: Add white center highlight pass to `SpeedTrackRenderer`

Add a third draw pass: after the crisp colored core, stroke a 1 pt white line at 45% α — the "hot filament." It sits on top of the colored core, so it's always framed by color and reads on any background.

**Files:**
- Modify: `PolarMyFlow/Features/Tracks/TrackMapView.swift`

(Renderer rendering is visual — no unit test; verified in the simulator in Task 8.)

- [ ] **Step 1: Add the white highlight pass**

In `PolarMyFlow/Features/Tracks/TrackMapView.swift`, in `SpeedTrackRenderer.draw(_:zoomScale:in:)`, add a third pass **after** the existing crisp-line pass (after the second `for seg in track.segments` loop):

```swift
// White filament — 1 pt center highlight, rides on top of the colored core.
// Framed by ~1.25 pt of color on each side so it reads on any background.
context.setLineCap(.butt)
context.setLineWidth(1.0 / zoomScale)
context.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
for seg in track.segments {
    guard let path = makePath(seg.coords) else { continue }
    context.addPath(path)
    context.strokePath()
}
```

- [ ] **Step 2: Also update the core line width** from `2.5` to `3.5` in the crisp pass (the second loop, not the glow pass). Find this line in the crisp pass:

```swift
context.setLineWidth(lineWidth)
```

where `lineWidth` is defined at the top of `draw` as:

```swift
let lineWidth = 2.5 / zoomScale
```

Change it to:

```swift
let lineWidth = 3.5 / zoomScale
```

- [ ] **Step 3: Build to verify no compile errors**

```bash
xcodebuild build -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "BUILD|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PolarMyFlow/Features/Tracks/TrackMapView.swift
git commit -m "feat(tracks): 3.5pt colored core + white center highlight pass in SpeedTrackRenderer"
```

---

## Task 5: Add MML API key to `BuildConfig`

**Files:**
- Modify: `PolarMyFlow/BuildConfig.swift`

- [ ] **Step 1: Add the MML key**

In `PolarMyFlow/BuildConfig.swift`, add after the existing Polar credentials (outside the `#if DEBUG` block — the key is the same in both configurations):

```swift
enum BuildConfig {
    #if DEBUG
    static let clientID     = "4b330ffa-0cc6-474f-92a9-f833d1c55d2a"
    static let clientSecret = "19330628-94ec-4ffe-b052-02a9c8750f07"
    #else
    static let clientID     = "c045142a-470a-4d0c-8f44-b8aa1200e975"
    static let clientSecret = "59ccbd6e-aaae-4881-b121-a3b7774ff03b"
    #endif

    static let mmlApiKey    = "5226aad5-8658-4e13-add5-efb53ea36990"
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "BUILD|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/BuildConfig.swift
git commit -m "chore: add MML open-data API key to BuildConfig"
```

---

## Task 6: Create `MMLTileOverlay` with unit tests

A pure URL-template builder + `MKTileOverlay` factory. The URL uses WMTS path order `{z}/{y}/{x}` (TileMatrix / TileRow / TileCol) — **not** the more common `{z}/{x}/{y}` used by XYZ tile services.

**Files:**
- Create: `PolarMyFlow/Features/Tracks/MMLTileOverlay.swift`
- Create: `PolarMyFlowTests/MMLTileOverlayTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PolarMyFlowTests/MMLTileOverlayTests.swift`:

```swift
import XCTest
import MapKit
@testable import PolarMyFlow

final class MMLTileOverlayTests: XCTestCase {
    func testURLTemplate_containsWMTSPathOrder() {
        // WMTS order is {z}/{y}/{x}, NOT {z}/{x}/{y}
        let template = MMLTileOverlay.urlTemplate(apiKey: "test-key")
        let zIdx = template.range(of: "{z}")!.lowerBound
        let yIdx = template.range(of: "{y}")!.lowerBound
        let xIdx = template.range(of: "{x}")!.lowerBound
        XCTAssertLessThan(zIdx, yIdx, "{z} must come before {y}")
        XCTAssertLessThan(yIdx, xIdx, "{y} must come before {x}")
    }

    func testURLTemplate_containsApiKey() {
        let template = MMLTileOverlay.urlTemplate(apiKey: "my-key-123")
        XCTAssertTrue(template.contains("api-key=my-key-123"))
    }

    func testURLTemplate_containsMaastokarttaLayer() {
        let template = MMLTileOverlay.urlTemplate(apiKey: "k")
        XCTAssertTrue(template.contains("maastokartta"))
    }

    func testOverlay_maximumZIs15() {
        let overlay = MMLTileOverlay.make(apiKey: "k")
        XCTAssertEqual(overlay.maximumZ, 15)
    }

    func testOverlay_canReplaceMapContent() {
        let overlay = MMLTileOverlay.make(apiKey: "k")
        XCTAssertTrue(overlay.canReplaceMapContent)
    }
}
```

- [ ] **Step 2: Run xcodegen to register the new test file (before it exists)**

```bash
xcodegen generate 2>&1 | tail -3
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/MMLTileOverlayTests \
  2>&1 | grep -E "FAILED|error:|MMLTileOverlay"
```

Expected: compile error — `cannot find type 'MMLTileOverlay' in scope`

- [ ] **Step 4: Create `MMLTileOverlay.swift`**

Create `PolarMyFlow/Features/Tracks/MMLTileOverlay.swift`:

```swift
import MapKit

enum MMLTileOverlay {
    static func urlTemplate(apiKey: String) -> String {
        "https://avoin-karttakuva.maanmittauslaitos.fi/avoinapi/tiles/wmts/1.0.0" +
        "/maastokartta/default/WGS84_Pseudo-Mercator/{z}/{y}/{x}.png?api-key=\(apiKey)"
    }

    static func make(apiKey: String) -> MKTileOverlay {
        let overlay = MKTileOverlay(urlTemplate: urlTemplate(apiKey: apiKey))
        overlay.canReplaceMapContent = true
        overlay.minimumZ = 0
        overlay.maximumZ = 15
        return overlay
    }
}
```

- [ ] **Step 5: Run xcodegen to register the new source file**

```bash
xcodegen generate 2>&1 | tail -3
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PolarMyFlowTests/MMLTileOverlayTests \
  2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add PolarMyFlow/Features/Tracks/MMLTileOverlay.swift \
        PolarMyFlowTests/MMLTileOverlayTests.swift
git commit -m "feat(tracks): add MMLTileOverlay — Maastokartta WMTS tile source"
```

---

## Task 7: Wire MML tiles into `TrackMapView`

Add the tile overlay below the speed-track overlay, handle its renderer, and add an attribution label. The tile overlay is only added when `BuildConfig.mmlApiKey` is non-empty — empty key falls back to the Apple muted map silently.

**Files:**
- Modify: `PolarMyFlow/Features/Tracks/TrackMapView.swift`

- [ ] **Step 1: Add a stored `tileOverlay` reference to `Coordinator`**

In the `Coordinator` class, add a property to track whether the tile overlay was added (needed to check in `rendererFor`):

```swift
private var tileOverlay: MKTileOverlay?
```

- [ ] **Step 2: Add tile overlay setup in `buildOverlays`**

At the **top** of `Coordinator.buildOverlays(on:routePoints:)`, before adding the speed-track overlay, insert:

```swift
if !BuildConfig.mmlApiKey.isEmpty {
    let tile = MMLTileOverlay.make(apiKey: BuildConfig.mmlApiKey)
    tileOverlay = tile
    mapView.addOverlay(tile, level: .aboveLabels)
}
```

The speed-track overlay is added later in `buildOverlays` at `level: .aboveRoads` — change that level to `.aboveLabels` too, so both share the same level and the speed track (added second) draws on top:

Find:
```swift
mapView.addOverlay(SpeedTrackOverlay(segments: segments), level: .aboveRoads)
```
Replace with:
```swift
mapView.addOverlay(SpeedTrackOverlay(segments: segments), level: .aboveLabels)
```

- [ ] **Step 3: Handle tile overlay renderer in `mapView(_:rendererFor:)`**

Replace the existing `mapView(_:rendererFor:)` implementation:

```swift
func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let tile = overlay as? MKTileOverlay {
        return MKTileOverlayRenderer(tileOverlay: tile)
    }
    guard let track = overlay as? SpeedTrackOverlay else {
        return MKOverlayRenderer(overlay: overlay)
    }
    return SpeedTrackRenderer(track)
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "BUILD|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Features/Tracks/TrackMapView.swift
git commit -m "feat(tracks): wire MML Maastokartta tile overlay into TrackMapView"
```

---

## Task 8: Restructure `ActivityDetailView` — map-first layout

Replace the numbers-first layout with a map-first layout when `hasRoute == true`. Use `GeometryReader` for responsive map height (~55% of viewport, min 360 pt). Compact stat strip replaces the jumbo distance block. Attribution label on the map. The no-route layout is unchanged.

**Files:**
- Modify: `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift`

- [ ] **Step 1: Rewrite `ActivityDetailView.swift`**

Replace the full content of `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift`:

```swift
import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityDetailViewModel
    @State private var scrubFraction: Double = 0.0
    @State private var scrubSpeedKmh: Double = 0.0
    @State private var recenterToken: Int = 0
    @State private var cachedRoutePoints: [RoutePoint]

    init(activity: Activity) {
        _viewModel = State(initialValue: ActivityDetailViewModel(activity: activity))
        _cachedRoutePoints = State(initialValue: activity.hasRoute ? activity.routePoints : [])
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(viewModel)
                    if viewModel.activity.hasRoute {
                        mapFirstLayout(viewModel, geo: geo)
                    } else {
                        numbersFirstLayout(viewModel)
                    }
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
        }
        .polarBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Map-first layout (hasRoute == true)

    private func mapFirstLayout(_ vm: ActivityDetailViewModel, geo: GeometryProxy) -> some View {
        let mapHeight = max(360, geo.size.height * 0.55)
        return VStack(spacing: 12) {
            trackSection(height: mapHeight)
            PolarRule(variant: .full)
            compactStatStrip(vm)
        }
    }

    private func trackSection(height: CGFloat) -> some View {
        TrackMapView(routePoints: cachedRoutePoints,
                     scrubFraction: $scrubFraction,
                     speedKmh: $scrubSpeedKmh,
                     recenterToken: $recenterToken)
            .frame(height: height)
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
            .overlay(alignment: .bottomLeading) {
                if !BuildConfig.mmlApiKey.isEmpty {
                    Text("© Maanmittauslaitos")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.15).opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 3))
                        .padding(6)
                }
            }
            .padding(.horizontal, -Spacing.screenMargin)
        // Scrub row below the map
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

    private func compactStatStrip(_ vm: ActivityDetailViewModel) -> some View {
        HStack(alignment: .top, spacing: 0) {
            statCell(value: vm.distanceString, label: "Distance")
            Spacer()
            statCell(value: vm.durationString, label: "Moving")
            Spacer()
            statCell(value: vm.speedString, label: "Speed")
            if let hr = vm.avgHRString {
                Spacer()
                statCell(value: hr, label: "Avg HR")
            }
        }
    }

    // MARK: - Numbers-first layout (hasRoute == false)

    private func numbersFirstLayout(_ vm: ActivityDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            heroStats(vm)
            PolarRule(variant: .full)
            threeUp(vm)
        }
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

    // MARK: - Shared helpers

    private func header(_ vm: ActivityDetailViewModel) -> some View {
        PolarBackHeader(
            crumb: "Log · \(vm.dateString)",
            title: vm.title,
            titleFont: .displaySmall,
            onDismiss: { dismiss() }
        )
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

> **Note on `trackSection`:** SwiftUI's `@ViewBuilder` doesn't allow mixing a modifier chain and standalone statements in the same builder scope without a `VStack`. Wrap the map + scrub row + slider together in a `VStack(spacing: 12)` inside `trackSection`. The function signature becomes `private func trackSection(height: CGFloat) -> some View` returning a `VStack`. Specifically, place the `.overlay` chain on the `TrackMapView`, then add the scrub row and slider as siblings inside the wrapping `VStack`.

- [ ] **Step 2: Build to verify no compile errors**

```bash
xcodebuild build -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "BUILD|error:"
```

Expected: `** BUILD SUCCEEDED **`

If you see "consecutive statements on a line must be separated by ';'" or "result of call to ... is unused", you have a ViewBuilder scope issue — wrap the map + scrub HStack + Slider in an explicit `VStack(spacing: 12) { ... }` inside `trackSection`.

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Features/ActivityList/ActivityDetailView.swift
git commit -m "feat(detail): map-first hero layout with responsive height and compact stat strip"
```

---

## Task 9: Visual verification in simulator

Run the full test suite, then launch the app and visually confirm all three issues are fixed.

**Files:** None modified.

- [ ] **Step 1: Run the full test suite**

```bash
xcodebuild test -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "PASSED|FAILED|error:" | tail -20
```

Expected: `** TEST SUCCEEDED **` with no failures.

- [ ] **Step 2: Launch the app in the simulator**

```bash
xcodebuild build -scheme PolarMyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "BUILD|error:"
# Then open Simulator and run the app from Xcode or:
open -a Simulator
```

Navigate to an activity with a GPS route.

- [ ] **Step 3: Verify issue #1 — map is the hero**

- The map fills ~55% of the screen height immediately under the header.
- Distance/duration/speed/HR appear as a compact strip *below* the map.
- No jumbo distance block at the top.

- [ ] **Step 4: Verify issue #2 — neon bloom**

- The route has a visible glow along its entire length (not just the fast sections).
- Fast sections bloom brighter and wider.
- A thin bright white filament runs along the center of the line.
- Slow/cool sections read as deep blue (not near-white).

- [ ] **Step 5: Verify issue #3 — MML topo tiles**

- The base map shows topographic contour lines and terrain detail (Maastokartta).
- "© Maanmittauslaitos" attribution is visible at the bottom-left of the map.
- The route renders *above* the topo tiles (not hidden underneath).
- Amber mid-range speed sections are legible on the light-tan tile background.

- [ ] **Step 6: Verify the no-route layout is unchanged**

Open an activity without a GPS route. Confirm: jumbo distance hero at top, pace/HR row, no map, no regression.

- [ ] **Step 7: Final commit if any visual tweaks were made**

If step 5 reveals that amber mid-tones wash out on the topo tiles, add a thin dark casing under the colored core. In `SpeedTrackRenderer.draw`, insert between the glow pass and the crisp pass:

```swift
// Dark casing — only add if amber/mid tones wash out on light topo tiles.
context.setLineCap(.butt)
context.setLineWidth((lineWidth + 1.5) / zoomScale)
for seg in track.segments {
    guard let path = makePath(seg.coords) else { continue }
    context.setStrokeColor(UIColor.black.withAlphaComponent(0.20).cgColor)
    context.addPath(path)
    context.strokePath()
}
```

Commit any tweaks:

```bash
git add -p
git commit -m "fix(tracks): visual tweaks from simulator verification"
```

---

## Self-Review

**Spec coverage:**
- §1 Map-first hero layout → Task 8 ✓
- §1 Responsive map height (GeometryReader, ~55%, min 360) → Task 8 ✓
- §1 Pace → speed in stat strip → Task 1 (formatter) + Task 8 (strip) ✓
- §1 No-route layout unchanged → Task 8 ✓
- §2 Core line width 2.5→3.5 → Task 4 ✓
- §2 GlowProfile retune → Task 3 ✓
- §2 White center highlight → Task 4 ✓
- §2 SpeedColorRamp cool-end darkening → Task 2 ✓
- §3 MMLTileOverlay URL builder → Task 6 ✓
- §3 API key in BuildConfig → Task 5 ✓
- §3 Tile overlay wired below speed track → Task 7 ✓
- §3 Attribution label → Task 8 ✓
- §3 Empty-key fallback → Task 7 ✓
- §4 Source-agnostic render layer → no code change needed ✓
- Build note (xcodegen after new file) → Task 6 steps 2 & 5 ✓
- Visual verification → Task 9 ✓
