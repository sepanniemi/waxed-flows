# Waxed Flows — UI Refresh Design Spec

**Date:** 2026-04-20
**Status:** Approved
**Supersedes (visually only):** 2026-04-12 Polar MyFlow iOS App design spec — data model, sync pipeline, and navigation structure from that spec remain authoritative.

## Overview

Rebrand and visual-system refresh for the existing PolarMyFlow iOS app.
Product name changes from **Polar MyFlow** to **Waxed Flows** — a cross-country-skiing-leaning identity inspired by the `polarized-trainings` repo name and the polarized-lens metaphor (cold ↔ effort, north-sky palette, waxed-ski-ready-to-go).

Scope is purely presentation: typography, color, components, icon assets, and per-screen treatment. No changes to data model, sync logic, SwiftData entities, ViewModels' shape, or navigation structure.

---

## Brand Identity

### Name
**Waxed Flows** — the wordmark. Always rendered in the display face (see Typography). On the second line, "Flows." gets the sky-blue accent color and a trailing period.

### Voice
Editorial but chunky. Numbers shout, labels whisper. Short all-caps mono labels for context, oversized condensed display digits for values. Minimal chrome, lots of air.

### Palette (Polaris)

Dark-only — no light theme. All tokens defined in a single Swift `Palette` struct.

| Token | Hex | Usage |
|---|---|---|
| `polarNight` | `#0A1428` | Page background top, tab bar base |
| `polarDeep` | `#142451` | Mid gradient stop |
| `polarRoyal` | `#1E3A8A` | Page background bottom, filled buttons |
| `polarSky` | `#60A5FA` | Primary accent, charts, active states |
| `polarSkyLight` | `#93C5FD` | "Flows" wordmark accent, highlighted chart segments |
| `polarSkyIce` | `#BFDBFE` | Soft chart segments, faint borders |
| `polarAmber` | `#FBBF24` | Warning / effort accent (Z5 zones, ascent emphasis) |
| `ink` | `#FFFFFF` | Primary text on dark |
| `inkMuted` | `rgba(#FFFFFF, 0.7)` | Secondary text |
| `inkFaint` | `rgba(#FFFFFF, 0.45)` | Mono meta labels |
| `surfaceGlass` | `rgba(#FFFFFF, 0.04)` | Card fill |
| `surfaceBorder` | `rgba(#FFFFFF, 0.08)` | Card borders, dividers |
| `ruleSoft` | `rgba(#FFFFFF, 0.14)` | Full-width section rules |

### Background
Every screen uses the same background: a radial glow in the top-right (`polarSky` at 35% alpha) over a vertical gradient `polarNight → polarDeep → polarRoyal`. Defined once as a `PolarBackground` view modifier and applied at the screen root.

### Typography

Three roles, three faces.

| Role | Face | Usage |
|---|---|---|
| **Display** | Anton (bundled, SIL-OFL-1.1) | Wordmark, big numbers, tab labels, section headers, sport names |
| **Body** | SF Pro Text (system) | Descriptive copy, button labels, list content |
| **Meta** | SF Mono (system) | All-caps labels, units, breadcrumbs, timestamps |

**Display sizes** — condensed, uppercase, line-height `0.88`, tracking `+0.01em`. A 2pt offset shadow in `polarNight` at 90% alpha on all shadowed display text:

- `displayJumbo` — 86pt (hero numbers)
- `displayLarge` — 42pt (section numbers)
- `displayMedium` — 34pt (wordmark, screen titles)
- `displaySmall` — 26pt (secondary numbers, sport names)
- `displayTab` — 14pt (tab bar labels, with `+0.05em` tracking)

**Meta sizes** — uppercase, tracking `+0.18em`:

- `metaDefault` — 10pt
- `metaSmall` — 9pt (zone axis labels)

**Body sizes**:

- `bodyDefault` — 13pt
- `bodyCaption` — 11pt

### Dependency
Anton is added as a single `.ttf` in `PolarMyFlow/Resources/Fonts/Anton-Regular.ttf`. Registered via `UIAppFonts` in `Info.plist`. No Swift Package added.

---

## App Icon

**Two tracks carving** — `icon-tracks`.

Two parallel white-to-sky-blue gradient strokes on the Polaris background, angled ~12° counter-clockwise, occupying ~84% of the icon height. Same radial glow in the top-right. No wordmark, no text.

Rendered at every required iOS size from a single 1024×1024 source. `AppIcon.appiconset` added to `Assets.xcassets` (which does not currently exist — see Implementation Notes).

---

## Design System

### Card
- `surfaceGlass` fill
- 1pt `surfaceBorder` stroke
- 14pt corner radius
- Interior padding: 14pt vertical, 16pt horizontal
- Subtle 12pt backdrop blur

### Section rule
- Soft: 1pt, linear gradient from `ink` 60% to transparent 0%, used under screen-title meta label
- Full: 1pt solid `ruleSoft`, full content width, used between major sections within a screen

### Badge
- 1pt `surfaceBorder` stroke, no fill
- 20pt pill radius
- Padding 4pt × 8pt
- Meta-mono 10pt, uppercase, `+0.18em` tracking

### Sport dot
- 6pt × 6pt circle
- Colors assigned per sport type (see Sport Icon Set below)

### Tab Bar
- Fixed bottom bar, `polarNight` at 88% alpha, 14pt backdrop blur
- 1pt `surfaceBorder` top border
- Four tabs: Dash, Log, Tracks, Set
- Each tab: glyph (20pt) + display-tab label (14pt) stacked, 6pt gap
- Inactive: 55% opacity `ink`
- Active: `polarSkyLight` + 2pt underline rule of same color, `border-radius: 2`, from 20% to 80% of tab width

### HR Zone Bars
- Five vertical bars, 3pt gaps, 56pt max height
- Z1–Z2: `polarSky`
- Z3: `polarSkyLight`
- Z4: `polarSkyIce`
- Z5: `polarAmber`
- Axis labels in meta-small below each bar

---

## Sport Icon Set

Ten custom glyphs, one per `SportType` case, matching the chunky display face. All delivered as SF-Symbol-compatible SVG + PDF, added to `Assets.xcassets` as SVG asset entries. Rendered as `Image(.sportXcSkiing)` etc., tinted with `foregroundStyle(.polarSkyLight)`.

Glyphs are minimal geometry — a thick single stroke where possible, so they read at 28pt (list rows) through 40pt (sport detail hero) without detail loss.

| Sport type | Glyph concept | Sport dot color |
|---|---|---|
| `xcSkiing` | Two parallel angled strokes (classic tracks) | `polarSkyLight` |
| `running` | Forward-leaning slash with baseline | `polarAmber` |
| `cycling` | Two circles joined by a diagonal stroke | `#FCD34D` (amber light) |
| `swimming` | Three stacked shallow waves | `polarSkyIce` |
| `hiking` | Two triangles, larger behind smaller | `#6EE7B7` (teal) |
| `strength` | Solid bar with two flanking squares | `#F87171` (coral) |
| `rowing` | Horizontal stroke with two perpendicular oars | `#A78BFA` (violet) |
| `mountainBiking` | Cycling glyph + small triangle behind | `#FB923C` (orange) |
| `walking` | Forward slash (lighter than running) | `polarSkyIce` |
| `other` | Plus mark | `inkMuted` |

These replace all current `symbolName: String` SF Symbol references. `SportType.symbolName` is removed; a new `SportType.iconName` returns the asset name, and a new `SportType.dotColor` returns a `Color`.

---

## Screen-By-Screen Treatment

### Login screen (`ContentView.LoginView`)
- Full `PolarBackground`
- Centered vertical stack, top: `displayMedium` "Waxed Flows." with offset shadow, "Flows." in `polarSkyLight`
- Below wordmark: single line of meta-default text, `polarInkMuted`, "YOUR SEASON · YOUR LINE"
- 24pt gap, then rule-soft divider, then body-default description "Connect your Polar account to view your training history."
- Button: `displayTab` label "CONNECT", filled `polarSky` with `polarNight` text, 10pt corner radius, full-width minus 32pt side padding
- No SF Symbol hero — the wordmark is the hero

### Main tab shell (`MainTabView`)
- Replace default `TabView` chrome with a custom `PolarTabBar` view (reuses `TabView` selection state; pure chrome replacement)
- Four tabs: Dash (◆), Log (≡), Tracks (△), Set (⚙)
- Sync pill at top stays but restyled: `surfaceGlass` fill, `surfaceBorder` stroke, 20pt pill radius, meta-small text, `polarSkyLight` spinner tint

### Dashboard (`DashboardView` + `SeasonCardView`)
- Screen header strip: meta-default breadcrumb "0N · SEASON · {SEASON LABEL}", rule-soft below
- Wordmark "Waxed Flows." at top of scroll content, `displayMedium`, shadowed
- 28pt gap
- Season total: meta-default "TOTAL · {SEASON LABEL}" over `displayJumbo` number + unit-meta label row (e.g. "214 km · ski")
- Full rule
- Per-sport cards (replace current `SeasonCardView` row chrome):
  - Top: sport dot + meta-default sport name + `badge` "{N} SESSIONS"
  - Bottom: `displayLarge` km number with small unit, right-aligned body-caption secondary stat (avg pace, avg speed, or avg HR depending on sport)
- Tap whole card → Sport detail

### Sport Detail (`SportDetailView`)
- Same header strip with back breadcrumb "◂ DASH"
- Screen title: `displayMedium` sport name in `polarSkyLight`
- Below: meta-default date-range label
- Summary numbers row: three `displaySmall` stats (distance, sessions, avg pace)
- Date range picker: reuses existing picker but restyled to match badge (outline pill)
- Activity list rendered using the new `ActivityRowView` (see below)

### Activity List (`ActivityListView` + `ActivityRowView`)
- Header strip: "LOG · ALL ACTIVITIES"
- Sport filter: horizontal scrolling badge row; selected badge filled `polarSky` + `polarNight` text
- List: no `List` chrome, custom `LazyVStack` on the `PolarBackground`
- Row:
  - Left: sport glyph (24pt) + sport dot (6pt) in a 40pt frame
  - Middle: sport name in `displaySmall`, date in meta-default underneath
  - Right: distance `displaySmall` + avg HR or avg pace in body-caption
  - Thin `ruleSoft` below each row, no row background

### Activity Detail (`ActivityDetailView`)
Reshape from `List` + `LabeledContent` to a scrolling custom layout:
- Header strip: "◂ LOG · {DATE}"
- `displaySmall` sport name in `polarSkyLight`
- Meta-default: location name (if any) + time
- Hero row: `displayJumbo` distance + unit; right side `displaySmall` moving time + meta "MOVING"
- Full rule
- Three-up stat row: pace, avg HR, ascent — each `displaySmall` + meta unit label
- Full rule
- HR zones bar chart (component above)
- Full rule (only if elevation data present)
- Energy / calories as a single `displaySmall` number + unit
- All sections render conditionally — missing data → section is omitted (no empty "—" rows)

### Activity Row within Dashboard drill-down
Same row component as Activity List, reused verbatim.

### Tracks placeholder (`TracksPlaceholderView`)
- `PolarBackground`
- Centered `displayMedium` "TRACKS"
- Below: meta-default "COMING · 2026 · SUMMER"
- Faint outline of the tracks-icon mark at 50% opacity as a decorative background behind the text, not interactive

### Empty states
Two screens have empty states that currently render `ContentUnavailableView` with `systemImage: "figure.run"`:
- `DashboardView` — no training data yet
- `ActivityListView` — no activities match the current filter

Both replaced with a custom `PolarEmptyState` component:
- `PolarBackground`
- Centered: two-tracks icon mark (same geometry as the app icon), rendered as an `Image` asset at 120pt, 40% opacity
- Below: `displayMedium` title, e.g. "NO SESSIONS YET"
- Below: body-default description in `inkMuted`

### Settings (`SettingsView`)
- `PolarBackground`
- Custom grouped sections (not `Form`, not `List`):
  - Section title in meta-default
  - Rows of label + value using body-default + meta-default
  - Action rows (Import history, Download GDPR export) show an SF Symbol glyph on the left — `square.and.arrow.down` for import, `arrow.down.doc` for GDPR export — tinted `polarSkyLight`. Same chrome-indicator rationale as Import Progress.
  - Destructive / error copy uses `polarAmber` label (replaces current `.red`)
  - Completion / success copy uses `inkMuted` (replaces current `.secondary`)
- Import progress modal uses the same card chrome with a `polarSky` progress bar and `displaySmall` percentage

### Import Progress (`ImportProgressView`)
- Card overlay on `PolarBackground` (replaces current `.bar` background)
- `displayLarge` percentage centered
- Meta-default "{processed} / {total} FILES"
- Polar-sky progress bar (2pt height, `surfaceBorder` track, `polarSky` fill)
- Status row in meta-default:
  - `checkmark.circle` (SF Symbol) + count imported, tinted `polarSky`
  - `arrow.triangle.2.circlepath` + count skipped, tinted `polarSkyIce`
  - `exclamationmark.triangle` + count failed, tinted `polarAmber`
- These three status glyphs are the only SF Symbols allowed in the refresh — they're chrome indicators, not brand marks, and custom artwork would add churn without identity payoff

---

## Implementation Notes

### New files
- `PolarMyFlow/Design/Palette.swift` — color tokens as `static let` on a `Palette` enum, each returning `Color(…)` literals
- `PolarMyFlow/Design/Typography.swift` — `Font` extensions: `.displayJumbo`, `.displayLarge`, `.displayMedium`, `.displaySmall`, `.displayTab`, `.metaDefault`, `.metaSmall`, `.bodyDefault`, `.bodyCaption`
- `PolarMyFlow/Design/PolarBackground.swift` — `ViewModifier` applying the radial-glow-over-gradient to any view
- `PolarMyFlow/Design/Components/PolarCard.swift`
- `PolarMyFlow/Design/Components/PolarBadge.swift`
- `PolarMyFlow/Design/Components/PolarRule.swift` (soft + full variants)
- `PolarMyFlow/Design/Components/PolarTabBar.swift`
- `PolarMyFlow/Design/Components/HRZoneChart.swift`
- `PolarMyFlow/Design/Components/SportGlyph.swift` — thin wrapper that returns the asset image for a given `SportType`
- `PolarMyFlow/Design/Components/PolarEmptyState.swift` — empty-state layout with two-tracks mark + display title + body description
- `PolarMyFlow/Resources/Fonts/Anton-Regular.ttf`

### Existing file changes (presentation only)
- `ContentView.swift` — `LoginView` and `MainTabView` restyled
- `Features/Dashboard/DashboardView.swift` — header, wordmark, scroll container
- `Features/Dashboard/SeasonCardView.swift` — replaced chrome
- `Features/Dashboard/SportDetailView.swift` — restyled
- `Features/ActivityList/ActivityListView.swift` — list chrome replaced, filter badges
- `Features/ActivityList/ActivityRowView.swift` — new layout
- `Features/ActivityList/ActivityDetailView.swift` — replace `List`/`LabeledContent` with custom scrolling layout
- `Features/Tracks/TracksPlaceholderView.swift` — new content
- `Features/Settings/SettingsView.swift` — custom grouped sections
- `Features/Settings/ImportProgressView.swift` — card overlay
- `Models/SportType.swift` — `symbolName` removed, `iconName` and `dotColor` added

### Assets
- `PolarMyFlow/Assets.xcassets` does not exist today. Create it and add:
  - `AppIcon.appiconset` with the two-tracks icon at all iOS sizes (single 1024×1024 source, downscaled via Xcode)
  - One SVG asset per `SportType` case under `Sports/`: `sport-xc-skiing.svg`, `sport-running.svg`, etc.

### Fonts
- Add `Anton-Regular.ttf` to `project.yml` under `sources`
- Add `UIAppFonts` array to `Info.plist` with `Anton-Regular.ttf`
- Verify at app launch by attempting `UIFont(name: "Anton-Regular", size: 12)` and logging a warning if nil (no runtime fallback — font is bundled)

### Not changed
- All ViewModels (`DashboardViewModel`, `ActivityListViewModel`, `ActivityDetailViewModel`, `SportDetailViewModel`)
- `AuthManager`, `SyncCoordinator`, `PolarAccessLinkClient`, `HistoryImporter`
- SwiftData schema (`Activity`, `SyncState`, etc.)
- Navigation path structure
- `ActivityFormatting` formatters — their outputs are reused verbatim

### Product / target metadata
- Xcode target display name changes from "PolarMyFlow" to "Waxed Flows"
- Bundle identifier stays unchanged (personal app, one user)
- Internal type names (`PolarMyFlowApp`, `ContentView`, module name `PolarMyFlow`) stay unchanged — these aren't user-visible and renaming is pure churn

---

## Out of Scope

- Light mode theme
- Haptics / animation choreography beyond what SwiftUI gives for free
- Custom chart rendering beyond the HR zone bars (no route maps, no elevation graph — Tracks tab is still the placeholder)
- Onboarding flow beyond the existing single "Connect with Polar" button
- Localization — English/Finnish handled by system formatters where already present; copy changes are English-only
- Watch app / widget / Live Activity
- Accessibility audit beyond preserving existing Dynamic Type behavior for body copy (Display face uses fixed sizes; meta labels use fixed sizes)

---

## Success Criteria

- App launches with the new two-tracks icon on home screen
- Login screen shows the Waxed Flows wordmark in the display face; Connect button styled
- Dashboard, Activity List, Activity Detail, Tracks, Settings all render with the `PolarBackground` and updated typography
- All ten sport types show a custom glyph (not an SF Symbol)
- HR zone bar chart renders on activities that have HR data
- Empty states use the `PolarEmptyState` component with the two-tracks mark (not `figure.run`)
- No default SwiftUI styling remains in `Features/**` or `ContentView.swift`: zero occurrences of `.red`, `.blue`, `.green`, `.orange`, `.secondary`, `.tertiary`, `.bar`, or `systemImage:` — except for the five explicitly allowed chrome indicators (`checkmark.circle`, `arrow.triangle.2.circlepath`, `exclamationmark.triangle`, `square.and.arrow.down`, `arrow.down.doc`)
- Anton font loads; fallback warning does not fire
