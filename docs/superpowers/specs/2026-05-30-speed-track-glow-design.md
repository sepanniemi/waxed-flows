# Speed-Track Glow & Honest Normalizer — Design

**Date:** 2026-05-30
**Branch:** `waxed-flows-refresh`
**Status:** Approved (brainstorm complete)
**Scope:** Render-side track visuals only. Speed *sourcing* for ongoing API sync
is a separate effort — see "Follow-up" below.

## Problem

The GPS track in `ActivityDetailView` colors the route by real device speed
(`RoutePoint.speedKmh`, parsed from the GDPR `SPEED` sample series). The color
ramp works, but the *visual* speed encoding is half-built and three issues
undermine the "highest speed hottest and glowing, lowest speed cool" intent:

1. **Glow is uniform white.** `SpeedTrackRenderer.draw` draws all segments into a
   single transparency layer with one hardcoded white shadow. Fast and slow
   segments get the identical halo, and the white wash dulls the hot reds. The
   glow — the thing that should track speed — is flat.
2. **Normalizer manufactures false contrast.** The per-activity percentile scale
   floors the half-span at `0.001`, so a near-flat run's millimetre speed spread
   gets stretched across the full blue→red ramp. The map lies about how varied
   the effort was.
3. **Nil speeds default to amber and freeze the scrub.** `"NaN"` samples (sensor
   not locked, usually the first seconds) and out-of-range indices render as
   amber (bin 50) and leave the live km/h readout frozen.

Plus a usability gap: the map locks to the auto-fit route bounds with no zoom,
so dense sections can't be inspected.

## Goals

- Glow radiates the segment's own speed color; fast blooms hot, slow stays tight
  and cool — speed is the thing the eye tracks at a glance.
- The relative color scale stays rich on varied routes but tells the truth on
  flat ones.
- Every route point has a real-derived speed (no amber placeholder, no frozen
  readout) wherever a `SPEED` series exists in the stored route.
- The map supports pinch-zoom and pan with a one-tap recenter to the full route.

## Non-Goals

- No absolute/global km/h color scale (sport-dependent; relative-per-route is the
  chosen model).
- No legend (the live scrub readout already gives the precise value).
- Speed is never calculated from distance/time — it remains a real recorded
  `SPEED` series. This spec consumes whatever `speedKmh` is already in the stored
  `routePoints` (GDPR import populates it today); extending the *sources* of that
  speed to the live API is the Follow-up's job, not this spec's.
- No re-import or Core Data migration — all behavior here runs at load/render time
  over already-stored `routePoints`.

## Design

### 1. Per-segment colored glow

`SpeedTrackOverlay.Segment` gains a `normalizedSpeed: Double` field alongside its
existing derived `color`, so the renderer can scale the bloom per segment.

`SpeedTrackRenderer.draw` glow pass changes from one global white shadow to a
per-segment colored, speed-scaled bloom:

- For each segment, inside **its own** transparency layer:
  `setShadow(offset: .zero, blur: speedScaledBlur, color: segmentColor·glowAlpha)`,
  then stroke the segment path with its color (round cap).
- The per-segment layer prevents a segment's line+halo from compounding with
  itself. Adjacent fast→slow boundaries let the fast bloom spill over the slow
  line — the intended "heat radiating from the fast sections" look.
- The existing crisp butt-cap pass on top is unchanged, preserving line
  definition.

**Strong-contrast ramp** (computed in the renderer so it stays zoom-aware),
`n` = segment `normalizedSpeed` in `0...1`:

```
blur      = (0.5 + 11.5 * pow(n, 1.8)) / zoomScale
glowAlpha = 0.12 + 0.78 * pow(n, 1.8)
```

Slow segments → near-hairline blur, near-invisible halo. Fast segments → large
bright bloom. The `1.8` exponent makes the contrast aggressive rather than
linear. These constants are extracted into a pure `GlowProfile` helper:

```
GlowProfile.blurFactor(n: Double) -> Double   // the (0.5 + 11.5*n^1.8) factor, pre-zoom
GlowProfile.alpha(n: Double) -> Double
```

### 2. Honest normalizer

The percentile-+-floor math, currently an anonymous closure in `buildOverlays`,
moves into a pure helper:

```
SpeedNormalizer.make(from speeds: [Double]) -> (Double) -> Double
```

Logic unchanged except the floor:

```
let minSpan = 3.0                       // km/h
let half = max((p90 - p10) / 2, minSpan / 2)
normalize = { s in max(0, min(1, 0.5 + 0.5 * (s - p50) / half)) }
```

A speed must sit ≥1.5 km/h off the median to reach a ramp end. Steady runs stay
clustered near amber; varied runs (large p10→p90) use the full ramp exactly as
before. Fewer-than-two known speeds → constant `0.5` (unchanged).

### 3. Nil-speed interpolation

A pure helper fills the raw optional speeds before any binning or display:

```
SpeedInterpolator.fill(_ speeds: [Double?]) -> [Double]
```

- Interior nils → linear interpolation between the nearest known speed before and
  after.
- Leading nils → the first known speed.
- Trailing nils → the last known speed.
- All-nil → return an empty array, signaling the caller to fall back to flat amber
  (current behavior for routes with no recorded speed).

Runs at load time in the `Coordinator` over the stored `routePoints`, so it works
for already-imported activities with no re-import. The filled `[Double]` feeds
both the color binning and the scrub readout, so the live km/h shows a real value
everywhere and never freezes.

### 4. Pinch-zoom + pan with recenter

In `TrackMapView.makeUIView`:

- `isZoomEnabled = true`, `isScrollEnabled = true`.
- `isPitchEnabled = false`, `isRotateEnabled = false` (clean north-up map).

A small circular "recenter" control overlays the map bottom-trailing (SwiftUI
overlay in `trackSection`). Tapping it re-runs the auto-fit to the full route
bounds. Mechanism: the recenter action calls back into the coordinator (e.g. via
a stored `MKMapView` reference or a `Binding`-driven trigger) to
`setVisibleMapRect` the cached route bounds.

Initial-load auto-fit is unchanged. Scrubbing still moves the dot but no longer
force-recenters the map, so a manual zoom isn't yanked away mid-inspection.

## Components & Responsibilities

| Unit | Responsibility |
|------|----------------|
| `SpeedInterpolator.fill` | `[Double?]` → fully-populated `[Double]` (or empty if all-nil) |
| `SpeedNormalizer.make` | `[Double]` → percentile-with-floor normalize closure |
| `GlowProfile` | `normalizedSpeed` → pre-zoom blur factor + glow alpha |
| `SpeedTrackOverlay.Segment` | carries coords, color, and `normalizedSpeed` |
| `SpeedTrackRenderer` | per-segment colored speed-scaled glow + crisp pass |
| `TrackMapView.Coordinator` | builds filled speeds, segments, overlays; recenter |
| `ActivityDetailView.trackSection` | map frame, recenter button overlay, scrub UI |

## Data Flow

```
routePoints (stored, speedKmh: Double? — populated at import)
  → Coordinator.buildOverlays
      → SpeedInterpolator.fill([speedKmh])  →  filledSpeeds: [Double]
      → SpeedNormalizer.make(filledSpeeds)  →  normalize
      → per-point bin → segments (coords, color, normalizedSpeed)
      → SpeedTrackOverlay → SpeedTrackRenderer (colored speed-scaled glow)
  → updateUIView: filledSpeeds[idx] → scrub km/h readout (never frozen)
```

## Testing

Pure helpers are unit-tested (if a test target exists; otherwise verified by
build + on-device inspection and noted as such):

- `SpeedInterpolator.fill`: interior gap, leading gap, trailing gap, all-nil →
  empty, no-nil passthrough.
- `SpeedNormalizer.make`: flat input (all within ±1 km/h) keeps values near 0.5;
  varied input maps p50→~0.5, p90→~1.0, p10→~0.0; <2 known → constant 0.5.
- `GlowProfile`: blur and alpha monotonic in `n`; endpoints `n=0` and `n=1`
  match the spec constants.

Renderer pixel output and the zoom/recenter interaction are verified visually in
the iOS Simulator (iPhone 17 Pro) and on device.

## Risks

- **Per-segment glow seams.** Earlier work moved to a single transparency layer to
  kill per-segment alpha blobs. Per-segment layers reintroduce overlap at shared
  vertices; mitigated because adjacent segments share a hue family and the crisp
  pass re-establishes definition. Verify visually; if seams appear, fall back to
  grouping segments into a few bloom tiers drawn in shared layers.
- **Recenter wiring.** Passing the map-fit trigger from SwiftUI button to the
  `MKMapView` cleanly (without retain cycles or stale references) needs care.

## Follow-up (separate spec): unify ongoing sync on Polar API v4

Sourcing real speed for *new* activities (not from the GDPR file) is its own
sub-project, to be brainstormed separately. Investigation on 2026-05-30 confirmed
that **Polar API v4 (`auth.polar.com` / Dynamic AccessLink v4) returns the same
data model as the GDPR export**:

- `GET /training-sessions?from=&to=` lists completed sessions over a date range.
- A session embeds `trainingsessionSamples` as `{type, intervalMillis, values}`
  with an `IntervalValuesSampleType` enum including **SPEED**, ALTITUDE, DISTANCE,
  HEART_RATE, CADENCE — the same `"type"` strings the app already matches.
- The route is `domainstrainingsessionRoute` → `wayPoints[]` of
  `{longitude, latitude, altitude, elapsedMillis}` — identical to the GDPR
  `WayPoint`.

So the existing `GDPRTrainingSession` decoders (`SampleSeries`, `WayPoint`) and a
shared time-aligner would serve both file import and live sync, replacing the v3
`PolarAccessLinkClient` GPX+samples path. Cost: an OAuth2 auth rework
(`auth.polar.com`, 12 h tokens + refresh, `training_sessions:read` scope). Open
verify-first item: the exact **units** of v4 SPEED values (km/h vs m/s). This is
captured here only so the research isn't lost; the design itself will be worked
out in its own brainstorm.
