# Map View Usability — Design

**Date:** 2026-06-01
**Branch:** `waxed-flows-refresh`
**Status:** Approved (brainstorm complete; pending spec review)
**Scope:** `ActivityDetailView` and the `PolarMyFlow/Features/Tracks/` render layer.
Speed sourcing for AccessLink routes and the v4 API migration are a separate plan.
The Tracks *tab* (`TracksPlaceholderView`) is untouched.

## Problem

The GPS map in `ActivityDetailView` works but isn't usable as a *map*:

1. **The numbers crowd out the map.** The screen leads with a `displayJumbo`
   distance + duration block and a pace/HR row; the 380 pt map only appears after.
   On a phone the stats eat the top half before the route is visible. The view is
   meant to be about the route, but the map is the smallest thing on screen.
2. **The route line is thin and the glow is barely there.** The core is 2.5 pt and
   `GlowProfile`'s steep exponent (1.8) with a low floor (α 0.12, blur 0.5) means
   only the very fastest segments bloom; a steady effort shows almost no halo.
3. **It's the stock Apple map.** `mapType = .mutedStandard` — not the MML
   (Maanmittauslaitos) topographic tiles wanted for an outdoor/terrain feel.
4. **AccessLink routes currently render flat amber** because `GPXParser` stores
   `speedKmh: nil` — the v3 GPX has no documented per-point speed field. Real
   per-point speed for those routes is addressed in the v4 API upgrade plan, not here.

## Goals

- The map is the primary object on the detail screen when a route exists.
- The route reads as a glowing, speed-colored line at a glance — visible halo along
  the whole line, hottest on the fast sections — and stays legible on light topo
  tiles.
- The base map is MML **Maastokartta** topographic tiles.
- The detail screen speaks one speed unit: **km/h** (live scrub value *and* the
  summary stat).
- The render layer colors whatever `RoutePoint.speedKmh` is stored; GDPR routes are
  fully colored today. AccessLink routes degrade gracefully to flat amber until the
  API v4 plan adds real per-point speed for them.

## Non-Goals

- No change to the Tracks tab placeholder.
- No *calculated* speed. The render layer consumes `RoutePoint.speedKmh` as stored;
  this spec doesn't change speed sourcing. AccessLink routes will render flat amber
  until the v4 API upgrade adds real per-point speed for them (separate plan).
- The relative per-route, median-anchored speed normalization is unchanged.
- No new map provider abstraction — a single MML tile overlay, not a pluggable
  tile-source system (YAGNI).
- No re-import or Core Data migration.

## Design

### 1. Map-first hero layout

`ActivityDetailView.body` branches on `viewModel.activity.hasRoute`:

- **Has route → map-first layout:**
  1. `PolarBackHeader` (unchanged)
  2. **Map** (tall, see height below)
  3. Live km/h readout + scrub `Slider`
  4. **Compact stat strip** — one `HStack` of small `statCell`s:
     `distance (km) · moving (duration) · speed (km/h) · avg HR`
  5. Elevation / energy sections (unchanged)

  The `displayJumbo` distance block and the separate pace/HR `threeUp` row are
  removed in this branch; their data moves into the compact strip.

- **No route → current layout unchanged.** With no map to promote, the existing
  numbers-first layout (jumbo distance hero, pace/HR row, elevation, energy) stays.

**Responsive map height.** Wrap the screen in a `GeometryReader` to read the
viewport height and set the map frame to a proportion of it (~`0.55`, clamped to a
sensible minimum ~360 pt), rather than a hardcoded number. This sizes correctly on
iPhone 17 Pro and adapts to any device. The map keeps its `RoundedRectangle(14)`
clip, the `.padding(.horizontal, -screenMargin)` full-bleed, and the recenter
button overlay.

**Pace → speed.** The summary stat changes from pace (min/km) to average speed
(km/h). `Activity.avgSpeed` already exists (m/s); add
`ActivityFormatting.speedKmh(_ metresPerSecond:) -> String` (`* 3.6`, one decimal)
and a `viewModel.speedString`. `paceString` stays in the view model (unused by the
new layout, still available) to avoid churn elsewhere.

### 2. Neon-bloom speed-colored route

Render-side only — no change to overlay/segment architecture.

- **Core line width:** `2.5 → 3.5` (still `/ zoomScale`) in `SpeedTrackRenderer`.
- **Bloom present along the whole line, hottest on fast.** Retune `GlowProfile`
  with a bigger floor and a gentler exponent so steady segments also glow:

  ```
  blur  = (4 + 16 * pow(n, 1.2)) / zoomScale     // was (0.5 + 11.5 * pow(n, 1.8))
  alpha = 0.30 + 0.65 * pow(n, 1.2)              // was  0.12 + 0.78 * pow(n, 1.8)
  ```

  `n` = segment `normalizedSpeed` in `0...1`. Slow → moderate soft halo (not
  invisible); fast → large bright bloom. The per-segment colored-shadow mechanism
  in `SpeedTrackRenderer.draw` is unchanged; only the profile numbers and the core
  width change.

- **Bright white center highlight.** A third pass adds a 1 pt white stroke at
  ~45% α centered over the crisp colored core — the neon "hot filament." It sits
  *on* the colored core (not directly on the tiles), so it stays framed by ~1.25 pt
  of color on each side and reads against any background. Draw order per segment:
  neon bloom (shadow) → colored core (3.5 pt, butt cap) → white highlight (1 pt).
- **Darken the cool end of `SpeedColorRamp`** so slow segments read as a deep blue
  instead of near-white on the light tiles:
  `0.00 #BFDBFE → #2563EB`, `0.25 #60A5FA → #3B82F6`; amber/orange/red
  (`0.50/0.75/1.00`) unchanged (they already contrast on light tiles). Exact hexes
  confirmed during visual verification.

### 3. MML Maastokartta topographic tiles

- **New `MMLTileOverlay.swift`** in `Features/Tracks/`:
  - A pure URL-template builder (unit-testable) producing:
    ```
    https://avoin-karttakuva.maanmittauslaitos.fi/avoinapi/tiles/wmts/1.0.0/
      maastokartta/default/WGS84_Pseudo-Mercator/{z}/{y}/{x}.png?api-key=<key>
    ```
    Note the WMTS path order is `{z}/{y}/{x}` (TileMatrix / TileRow / TileCol), not
    the usual `{z}/{x}/{y}`.
  - A factory returning a configured `MKTileOverlay`: `maximumZ = 15`,
    `minimumZ = 0`, `canReplaceMapContent = true` (so MapKit doesn't draw Apple
    tiles or labels underneath).
- **API key** in `BuildConfig.swift`: `static let mmlApiKey = "5226aad5-…"`, matching
  the existing committed Polar-secret precedent in that file.
- **`TrackMapView`:**
  - `makeUIView` keeps `mapType = .mutedStandard` as a fallback base.
  - The coordinator adds the **tile overlay first**, then the speed-track overlay
    (added later ⇒ drawn on top), both at `level: .aboveLabels`.
  - **Only add the tile overlay when `mmlApiKey` is non-empty.** Empty key ⇒ no tile
    overlay ⇒ graceful fall back to the Apple muted map.
  - `mapView(_:rendererFor:)` branches: `MKTileOverlayRenderer` for the tile overlay,
    `SpeedTrackRenderer` for the track.
- **Attribution (required).** MML open data is CC BY 4.0 — show a small
  "© Maanmittauslaitos" label on the map (SwiftUI overlay, bottom-leading). Only
  shown when the tile overlay is active.
- **No ATS change** — the endpoint is HTTPS with a valid certificate.

### 4. Speed source — render-layer only (source-agnostic)

The render layer consumes `RoutePoint.speedKmh` as already stored — it does not
change how speed is sourced. GDPR-imported routes carry real per-point speed today;
AccessLink-synced routes set `speedKmh: nil` per point (GPX only has lat/lon/ele/time)
and will render flat amber until speed sourcing for those routes is tackled separately
in the API v4 upgrade plan.

This separation is intentional: speed sourcing for AccessLink routes requires
confirming the v4 samples API shape (`training_sessions:read` scope, sample-type enum,
units), which is non-trivial and belongs in its own plan. The render layer here is
correct for both paths — it colors whatever speed is stored, and degrades gracefully to
amber when none is available.

## Components & Responsibilities

| Unit | Responsibility |
|------|----------------|
| `ActivityDetailView` | `hasRoute` layout branch; responsive map height; compact stat strip |
| `ActivityDetailViewModel.speedString` | `avgSpeed (m/s)` → "X.X" km/h |
| `ActivityFormatting.speedKmh` | m/s → km/h display string |
| `MMLTileOverlay` | pure URL-template builder + configured `MKTileOverlay` factory |
| `SpeedColorRamp` | darkened cool end; warm end unchanged |
| `GlowProfile` | retuned blur/alpha (bigger floor, gentler exponent) |
| `SpeedTrackRenderer` | neon bloom + 3.5 pt colored core + 1 pt white center highlight |
| `TrackMapView.Coordinator` | adds tile overlay below track; tile/track renderer branch |

## Data Flow

```
Activity (avgSpeed m/s, routePoints) 
  → ViewModel.speedString → compact stat strip (km/h)
routePoints.speedKmh
  → SpeedInterpolator.fill → SpeedNormalizer.make → per-segment normalizedSpeed
  → SpeedColorRamp.color (darkened cool end) + GlowProfile (retuned)
  → SpeedTrackRenderer (3.5 pt core + neon bloom), drawn above MML tiles
BuildConfig.mmlApiKey → MMLTileOverlay → MKTileOverlay (Maastokartta) → tile renderer
```

## Testing

- **Unit:**
  - `MMLTileOverlay` template builder: `{z}/{y}/{x}` placed in WMTS order and
    `api-key=<key>` appended for a given key.
  - `GlowProfile`: blur/alpha monotonic in `n`; endpoints match the new constants
    (`n=0 → blur 4, α 0.30`; `n=1 → blur 20, α 0.95`).
  - `SpeedColorRamp`: endpoint/stop colors match the darkened ramp; midpoint stays
    amber.
- **Visual (iPhone 17 Pro simulator + device):** map-first layout proportion, real
  Maastokartta tiles loading with the key, neon bloom legibility on light tiles,
  cool-end contrast, whether a dark casing is needed, attribution label placement,
  km/h stat + live readout agreement.

## Risks

- **Slow/mid tones on light tiles.** The cool end is the weak spot; mitigated by
  darkening it. The white filament stays legible because it rides on the colored
  core, not the tiles. Confirm amber mid-tones hold up at visual verification.
- **Tile order vs speed track.** The track must draw above the tile overlay; ensured
  by add-order at the same overlay level. Verify the track isn't hidden by tiles.
- **`GeometryReader` in `ScrollView`.** Reading viewport height for the map
  proportion needs the reader placed outside the `ScrollView`; verify it doesn't
  cause layout feedback loops.
- **Missing/expired key.** Empty-key fallback to the Apple muted map is handled;
  a *wrong* key yields blank tiles over the muted base — acceptable, surfaced
  visually during testing.
- **AccessLink routes render flat amber.** Per-point speed for AccessLink-synced
  routes is `nil` until the v4 API upgrade. This is intentional and documented — not
  a bug introduced here.

## Build Note

`MMLTileOverlay.swift` is a new source file — run `xcodegen generate` after adding
it. A stale `.pbxproj` silently drops new files and still reports BUILD SUCCEEDED
(known project trap).
