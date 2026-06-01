# Track UI Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** (1) Show a live km/h speed that updates as the user scrubs the slider, using the real device-recorded SPEED samples from the GDPR export rather than any computed value; (2) make the map full-width and taller so it is the centrepiece of the view.

**Architecture:** The GDPR export contains `exercise.samples.samples[]` — a series of sample types including `"SPEED"` at 1-second intervals in km/h. Alignment: `speeds[waypoint.elapsedMillis / intervalMillis]`. The plan adds `speedKmh: Double?` to `RoutePoint` (optional so existing imported data degrades gracefully), parses and assigns speed during import, then uses the stored values in `TrackMapView` for both the colour ramp and a binding that feeds the scrub display. The calculated-speed fallback in `TrackMapView` is removed — if speed is absent the track renders with a flat colour.

**Tech Stack:** SwiftUI, MapKit, Swift `Codable`. No new files.

---

## File Map

| File | Change |
|------|--------|
| `PolarMyFlow/Models/RoutePoint.swift` | Add `speedKmh: Double?` |
| `PolarMyFlow/Import/GDPRTrainingSession.swift` | Add `SamplesWrapper` + `SampleSeries` structs, parse SPEED, assign to RoutePoints |
| `PolarMyFlow/Features/Tracks/TrackMapView.swift` | Use `point.speedKmh` for colour ramp; remove computed-speed logic; expose speed via `@Binding var speedKmh` |
| `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift` | Add `@State var scrubSpeedKmh`; pass binding to map; render speed above slider; make map full-width |

---

### Task 1: Add `speedKmh` to RoutePoint

**Files:**
- Modify: `PolarMyFlow/Models/RoutePoint.swift`

- [ ] **Step 1: Add the optional field**

Replace the entire file content:

```swift
import Foundation

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let elapsedMillis: Int
    let speedKmh: Double?
}
```

`Codable` synthesises the optional field automatically with `nil` as default for missing keys, so existing stored `routePointsData` blobs decode without error.

- [ ] **Step 2: Fix the call sites that construct RoutePoint without speedKmh**

`GDPRTrainingSession.swift` line 77–78 constructs `RoutePoint` — it will gain a `speedKmh:` argument in Task 2, so leave it for now. `GPXParser.swift` constructs RoutePoint without speed — add `speedKmh: nil`:

Open `PolarMyFlow/API/GPXParser.swift` and find the `RoutePoint(` call. Add `speedKmh: nil` to it.

- [ ] **Step 3: Build to confirm**

```bash
cd /Users/sepanniemi/codes/polar-myflow
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PolarMyFlow/Models/RoutePoint.swift PolarMyFlow/API/GPXParser.swift
git commit -m "feat(tracks): add optional speedKmh to RoutePoint"
```

---

### Task 2: Parse SPEED samples in GDPRTrainingSession and assign to RoutePoints

The JSON structure is:
```json
exercise.samples          → { "samples": [...] }        (object, not array)
exercise.samples.samples  → [ { "type": "SPEED", "intervalMillis": 1000, "values": [...] }, ... ]
```
Values are JSON strings `"NaN"` or JSON numbers. Non-finite and zero values at the start of a session are treated as `nil` (no valid reading yet).

**Files:**
- Modify: `PolarMyFlow/Import/GDPRTrainingSession.swift`

- [ ] **Step 1: Add `SamplesWrapper` and `SampleSeries` structs inside `GDPRTrainingSession`**

Add these two nested structs after `struct RoutesContainer`:

```swift
struct SamplesWrapper: Decodable {
    let samples: [SampleSeries]?
}

struct SampleSeries: Decodable {
    let type: String
    let intervalMillis: Int
    let values: [Double?]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type           = try c.decode(String.self, forKey: .type)
        intervalMillis = try c.decode(Int.self,    forKey: .intervalMillis)
        var raw = try c.nestedUnkeyedContainer(forKey: .values)
        var decoded: [Double?] = []
        while !raw.isAtEnd {
            if let d = try? raw.decode(Double.self) {
                decoded.append(d.isFinite && d > 0 ? d : nil)
            } else {
                _ = try? raw.decode(String.self)   // consume "NaN" string
                decoded.append(nil)
            }
        }
        values = decoded
    }

    enum CodingKeys: String, CodingKey { case type, intervalMillis, values }
}
```

- [ ] **Step 2: Add `samples` to `Exercise`**

```swift
struct Exercise: Decodable {
    let ascentMeters: Double?
    let descentMeters: Double?
    let routes: RoutesContainer?
    let samples: SamplesWrapper?
}
```

- [ ] **Step 3: Update `toActivity` to extract SPEED and assign per-waypoint**

In `toActivity`, replace the `routePoints` construction block (currently lines 69–80) with:

```swift
let waypoints = exercises?.first?.routes?.route?.wayPoints ?? []
let speedSeries = exercises?.first?.samples?.samples?.first(where: { $0.type == "SPEED" })

let routePoints: [RoutePoint] = waypoints.enumerated().map { (i, w) in
    let t = w.elapsedMillis ?? (waypoints.count > 1
        ? durationMillis * i / (waypoints.count - 1)
        : 0)
    var speed: Double? = nil
    if let series = speedSeries, series.intervalMillis > 0 {
        let idx = t / series.intervalMillis
        if idx >= 0 && idx < series.values.count {
            speed = series.values[idx]
        }
    }
    return RoutePoint(latitude: w.latitude, longitude: w.longitude,
                      altitude: w.altitude ?? 0, elapsedMillis: t, speedKmh: speed)
}
```

- [ ] **Step 4: Build to confirm**

```bash
cd /Users/sepanniemi/codes/polar-myflow
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Import/GDPRTrainingSession.swift
git commit -m "feat(tracks): parse SPEED samples from GDPR export into RoutePoint.speedKmh"
```

---

### Task 3: Use RoutePoint.speedKmh in TrackMapView

The coordinator currently computes smoothed speed from GPS position + time. Replace that with `point.speedKmh`. If no speed data is present (older imports), segments render with a flat mid-ramp colour (0.5 = amber neutral). Add a `@Binding var speedKmh: Double` so the scrub position's speed is readable by the parent view.

**Files:**
- Modify: `PolarMyFlow/Features/Tracks/TrackMapView.swift`

- [ ] **Step 1: Remove computed-speed helpers from Coordinator**

Delete the following private methods entirely from `Coordinator`:
- `computeRawSpeeds`
- `computeMidTimes`
- `rollingMean`
- `haversine`
- `makePercentileNormalizer`

Also delete the `buildSegments` method — it will be replaced.

- [ ] **Step 2: Add `smoothedSpeedsKmh` storage and rewrite `buildOverlays`**

Add a stored property to `Coordinator`:

```swift
private(set) var speedsKmh: [Double?] = []
```

Rewrite `buildOverlays` to use `point.speedKmh` directly. The normaliser now maps across the non-nil speed values present in this route:

```swift
func buildOverlays(on mapView: MKMapView, routePoints: [RoutePoint]) {
    cachedRoutePoints = routePoints
    guard routePoints.count >= 2 else { return }

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

    // Group consecutive waypoints that share the same colour bin (0–99)
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
    mapView.addOverlay(SpeedTrackOverlay(segments: segments), level: .aboveRoads)

    var rect = MKMapRect.null
    for p in routePoints {
        let pt = MKMapPoint(CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude))
        rect = rect.union(MKMapRect(x: pt.x, y: pt.y, width: 0, height: 0))
    }
    let fitRect = rect
    DispatchQueue.main.async {
        mapView.setVisibleMapRect(fitRect,
            edgePadding: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
            animated: false)
    }

    scrubAnnotation.coordinate = CLLocationCoordinate2D(
        latitude: routePoints[0].latitude,
        longitude: routePoints[0].longitude)
    mapView.addAnnotation(scrubAnnotation)
}
```

- [ ] **Step 3: Add `@Binding var speedKmh: Double` to TrackMapView and wire updateUIView**

Add the binding to the struct:

```swift
struct TrackMapView: UIViewRepresentable {
    let routePoints: [RoutePoint]
    @Binding var scrubFraction: Double
    @Binding var speedKmh: Double
    // ...
}
```

Update `updateUIView`:

```swift
func updateUIView(_ mapView: MKMapView, context: Context) {
    context.coordinator.rebuildIfNeeded(on: mapView, routePoints: routePoints)
    context.coordinator.moveScrubDot(on: mapView, routePoints: routePoints, fraction: scrubFraction)
    let speeds = context.coordinator.speedsKmh
    guard !speeds.isEmpty else { return }
    let idx = max(0, min(speeds.count - 1, Int(scrubFraction * Double(speeds.count - 1))))
    if let s = speeds[idx] {
        let rounded = (s * 10).rounded() / 10
        if abs(rounded - speedKmh) > 0.05 {
            DispatchQueue.main.async { speedKmh = rounded }
        }
    }
}
```

The `abs` guard breaks the re-render loop: the binding write triggers `updateUIView` again, but since `speedKmh` now equals `rounded`, the condition is false and no further write occurs.

- [ ] **Step 4: Build to confirm**

```bash
cd /Users/sepanniemi/codes/polar-myflow
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

(Will fail on ActivityDetailView call site — fixed in Task 4.)

- [ ] **Step 5: Commit after Task 4 completes the build**

Hold commit until Task 4 is done.

---

### Task 4: Wire speed display and fix map layout in ActivityDetailView

**Files:**
- Modify: `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift`

- [ ] **Step 1: Add `@State var scrubSpeedKmh`**

```swift
@State private var scrubSpeedKmh: Double = 0.0
```

- [ ] **Step 2: Rewrite `trackSection()`**

Replace the entire existing `trackSection()`:

```swift
private func trackSection() -> some View {
    VStack(spacing: 12) {
        TrackMapView(routePoints: cachedRoutePoints,
                     scrubFraction: $scrubFraction,
                     speedKmh: $scrubSpeedKmh)
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: 14))
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

Map layout: `PolarCard` removed, `.padding(.horizontal, -Spacing.screenMargin)` cancels the parent's 20 pt margin to make the map edge-to-edge, height raised from 260 → 380 pt.

Speed display: shows `0.0` until the binding is populated on first render. When the user scrubs, the value updates from the real device-recorded speed at that timestamp.

- [ ] **Step 3: Build both files**

```bash
cd /Users/sepanniemi/codes/polar-myflow
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit Tasks 3 and 4 together**

```bash
git add PolarMyFlow/Features/Tracks/TrackMapView.swift \
        PolarMyFlow/Features/ActivityList/ActivityDetailView.swift
git commit -m "feat(tracks): real device speed on scrub, full-width 380pt map"
```

---

## Self-Review

**Spec coverage:**
- ✅ Speed comes from the device-recorded `SPEED` samples in the GDPR export, not computed from GPS position/time
- ✅ Unit is km/h (confirmed: GDPR export values are in km/h; max ~31 is consistent with cycling)
- ✅ Speed updates live as slider is dragged
- ✅ Map is full-width and 380 pt tall, no card wrapper
- ✅ Existing imported sessions (no speedKmh) decode cleanly; track renders with flat amber colour; speed shows `0.0`

**Placeholder scan:** None.

**Type consistency:**
- `RoutePoint.speedKmh: Double?` defined in Task 1, used in Tasks 2 and 3 ✅
- `speedsKmh: [Double?]` stored in Coordinator (Task 3), read in `updateUIView` (Task 3) ✅
- `@Binding var speedKmh: Double` on `TrackMapView` (Task 3), passed as `$scrubSpeedKmh` from `ActivityDetailView` (Task 4) ✅
- `Spacing.screenMargin` is `CGFloat = 20` (`PolarMyFlow/Design/Spacing.swift`) ✅
