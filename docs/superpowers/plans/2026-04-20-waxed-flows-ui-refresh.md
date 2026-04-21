# Waxed Flows UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand `PolarMyFlow` to `Waxed Flows` with a new dark-only visual system — Polaris palette, bundled Anton display font, custom app icon + sport glyph assets, and every screen restyled to match the spec in `docs/superpowers/specs/2026-04-20-waxed-flows-ui-refresh-design.md`.

**Architecture:** Introduce a `PolarMyFlow/Design/` layer with token primitives (`Palette`, `Typography`), a `PolarBackground` view modifier applied at every screen root, and ~8 reusable SwiftUI components (`PolarCard`, `PolarBadge`, `PolarRule`, `PolarTabBar`, `HRZoneChart`, `SportGlyph`, `PolarEmptyState`, `PolarActionIcon`). Each existing screen is restyled in isolation to reuse those components — no ViewModel, data, or navigation changes.

**Tech Stack:** SwiftUI (iOS 17+), SwiftData (untouched), XcodeGen (`project.yml`), XCTest (for palette / typography / SportType unit tests only — no SwiftUI snapshot framework is introduced).

---

## Known limitations acknowledged up-front

1. **HR zone data doesn't exist in the current `Activity` model** (only `avgHeartRate` / `maxHeartRate`). The spec describes a Z1–Z5 bar chart. This plan **builds the `HRZoneChart` component to spec** but **does not wire it into `ActivityDetailView`** — zone-time breakdown requires a data-model change that's out of scope. The detail screen stops at the three-up stat row. A `FIXME` comment in `ActivityDetailView` documents this.
2. **App icon needs to be rendered to PNG** — the SVG source is inline in Task 6, and the plan assumes Xcode 15+'s single-size AppIcon support (`Assets.xcassets` `AppIcon` can accept just a 1024×1024 PNG).
3. **Anton font is a binary .ttf** — the plan includes an exact `curl` command to download it from Google Fonts' GitHub mirror (SIL OFL 1.1 licensed).
4. **SwiftUI views are not unit-tested** — the project has no snapshot test framework and the spec excludes introducing one. Verification is: Xcode builds + a manual simulator smoke test + grep-based success criteria at the end.

---

## File structure — what this plan creates or touches

### New files (under `PolarMyFlow/Design/`)

| File | Responsibility |
|---|---|
| `Design/Palette.swift` | Color tokens. One `enum Palette` with `static let` SwiftUI `Color` values. |
| `Design/Typography.swift` | `Font` factory. Extension on `Font` returning display / meta / body faces at fixed sizes. |
| `Design/PolarBackground.swift` | `ViewModifier` + `polarBackground()` extension applying radial-glow-over-gradient. |
| `Design/Components/PolarCard.swift` | Glass card container (`surfaceGlass` + `surfaceBorder`). |
| `Design/Components/PolarBadge.swift` | Outline pill with meta-mono text. Two styles: `.outline`, `.filled`. |
| `Design/Components/PolarRule.swift` | Two rule variants: `softRule` (under header meta), `fullRule` (full-width). |
| `Design/Components/PolarTabBar.swift` | Custom bottom tab bar replacing default `TabView` chrome. |
| `Design/Components/HRZoneChart.swift` | 5-bar zone-time chart. Accepts `[Double]` of 5 fractions. |
| `Design/Components/SportGlyph.swift` | `View` wrapping the per-sport asset image + tint. |
| `Design/Components/PolarEmptyState.swift` | Empty-state layout with two-tracks mark + title + description. |
| `Design/Components/PolarActionIcon.swift` | Small helper wrapping one of the five allow-listed SF Symbols with a `polarSkyLight` tint. |
| `Resources/Fonts/Anton-Regular.ttf` | Bundled font binary (downloaded from Google Fonts). |
| `Assets.xcassets/Contents.json` | Root asset catalog. |
| `Assets.xcassets/AppIcon.appiconset/Contents.json` | App icon manifest. |
| `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | 1024×1024 app icon PNG. |
| `Assets.xcassets/Sports/*.imageset/Contents.json` + `.svg` | 10 sport glyph assets (one imageset per `SportType`). |
| `Assets.xcassets/Tracks/Contents.json` + `.svg` | Two-tracks mark used by empty state + Tracks placeholder. |

### Modified files

| File | Change |
|---|---|
| `project.yml` | Resource inclusion for fonts + assets; target display name. |
| `PolarMyFlow/Info.plist` | Add `UIAppFonts` entry, `CFBundleDisplayName`. |
| `PolarMyFlow/ContentView.swift` | Rebuild `LoginView` + `MainTabView` against new design system. |
| `PolarMyFlow/Models/SportType.swift` | Remove `symbolName`, add `iconName` and `dotColor`. |
| `PolarMyFlowTests/SportTypeTests.swift` | Replace `symbolName` tests with `iconName` + `dotColor` tests. |
| `PolarMyFlow/Features/Dashboard/DashboardView.swift` | Header strip, wordmark, scroll container on PolarBackground. |
| `PolarMyFlow/Features/Dashboard/SeasonCardView.swift` | Replace card chrome + row chrome with Polar components. |
| `PolarMyFlow/Features/Dashboard/SportDetailView.swift` | Rebuild without `List`/`Section` — scroll + cards. |
| `PolarMyFlow/Features/ActivityList/ActivityListView.swift` | Replace `List` with `LazyVStack`, filter badges. |
| `PolarMyFlow/Features/ActivityList/ActivityRowView.swift` | New layout with sport glyph + dot + rule divider. |
| `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift` | Replace `List`/`LabeledContent` with custom scroll. |
| `PolarMyFlow/Features/Tracks/TracksPlaceholderView.swift` | New content on PolarBackground. |
| `PolarMyFlow/Features/Settings/SettingsView.swift` | Replace `List`/`Form` with custom grouped sections. |
| `PolarMyFlow/Features/Settings/ImportProgressView.swift` | Card overlay + zone-palette status icons. |

---

## Working agreement for every task

- Commit message convention: `feat(design): …`, `refactor(design): …`, `style(design): …`. The design-system rebrand is a presentation-layer change, so `refactor(design)` / `style(design)` are most common.
- After each task's final step, run `xcodegen` if `project.yml` was touched and then build the scheme `PolarMyFlow` in Xcode (`xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' build`) to verify it compiles. Do this before committing.
- Existing tests (`PolarMyFlowTests`) must keep passing. Run `xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 15' test` after any change that touches model / ViewModel code.
- Never commit the binary `.ttf`, `.png`, or image assets with any content other than what this plan specifies. The `.ttf` is licensed under SIL OFL 1.1; include the license text as `Resources/Fonts/OFL.txt`.

---

## Task 1: Bundle Anton font and register in Info.plist

**Why this is first:** Every `displayN` font token returns `Font.custom("Anton-Regular", …)`. If the file isn't bundled, every screen renders in a fallback system font and the whole visual system looks wrong. Get this right once, for every subsequent task.

**Files:**
- Create: `PolarMyFlow/Resources/Fonts/Anton-Regular.ttf`
- Create: `PolarMyFlow/Resources/Fonts/OFL.txt`
- Modify: `project.yml` (add `resources:`)
- Modify: `PolarMyFlow/Info.plist` (add `UIAppFonts`, `CFBundleDisplayName`)

- [ ] **Step 1: Download Anton-Regular.ttf from Google Fonts' official mirror**

Run:

```bash
mkdir -p PolarMyFlow/Resources/Fonts
curl -L -o PolarMyFlow/Resources/Fonts/Anton-Regular.ttf \
  https://raw.githubusercontent.com/google/fonts/main/ofl/anton/Anton-Regular.ttf
curl -L -o PolarMyFlow/Resources/Fonts/OFL.txt \
  https://raw.githubusercontent.com/google/fonts/main/ofl/anton/OFL.txt
```

Expected: `PolarMyFlow/Resources/Fonts/Anton-Regular.ttf` is non-empty (should be ~50 KB) and `OFL.txt` starts with `Copyright 2011 The Anton Project Authors`.

- [ ] **Step 2: Verify the font file is valid**

Run:
```bash
file PolarMyFlow/Resources/Fonts/Anton-Regular.ttf
```

Expected: `PolarMyFlow/Resources/Fonts/Anton-Regular.ttf: TrueType Font data, …`

- [ ] **Step 3: Add `UIAppFonts` and `CFBundleDisplayName` to `Info.plist`**

Edit `PolarMyFlow/Info.plist` — add these two `<key>` / `<value>` pairs inside the root `<dict>` (anywhere, but keep alphabetical-ish order near the `CFBundle*` entries):

```xml
	<key>CFBundleDisplayName</key>
	<string>Waxed Flows</string>
	<key>UIAppFonts</key>
	<array>
		<string>Anton-Regular.ttf</string>
	</array>
```

- [ ] **Step 4: Add a `resources:` section to the `PolarMyFlow` target in `project.yml`**

Edit `project.yml`. Under `targets.PolarMyFlow`, add a `resources:` key at the same indent level as `sources:`:

```yaml
  PolarMyFlow:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - PolarMyFlow
    resources:
      - path: PolarMyFlow/Resources
        buildPhase:
          copyFiles:
            destination: resources
```

Note: XcodeGen's default for files under `sources:` is to treat `.ttf` and `Assets.xcassets` as resources, but explicit `resources:` removes ambiguity. If this causes duplication errors, remove the `resources:` block — XcodeGen will pick them up from the `PolarMyFlow` sources scan.

- [ ] **Step 5: Regenerate the Xcode project**

Run:
```bash
xcodegen generate
```

Expected: `Created project at PolarMyFlow.xcodeproj`. No errors.

- [ ] **Step 6: Build to verify font resource is copied into the bundle**

Run:
```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`. Check that the font is in the built bundle:
```bash
find build -name "Anton-Regular.ttf" -path "*/PolarMyFlow.app/*"
```

Expected: at least one match under `build/Build/Products/Debug-iphonesimulator/PolarMyFlow.app/`.

- [ ] **Step 7: Commit**

```bash
git add PolarMyFlow/Resources/Fonts project.yml PolarMyFlow/Info.plist PolarMyFlow.xcodeproj
git commit -m "feat(design): bundle Anton display font and set display name to Waxed Flows"
```

---

## Task 2: Palette — color tokens

**Files:**
- Create: `PolarMyFlow/Design/Palette.swift`
- Create: `PolarMyFlowTests/PaletteTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PolarMyFlowTests/PaletteTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import PolarMyFlow

final class PaletteTests: XCTestCase {
    func test_polarNight_matchesSpecHex() {
        XCTAssertEqual(Palette.polarNight.hexString, "#0A1428")
    }
    func test_polarSky_matchesSpecHex() {
        XCTAssertEqual(Palette.polarSky.hexString, "#60A5FA")
    }
    func test_polarAmber_matchesSpecHex() {
        XCTAssertEqual(Palette.polarAmber.hexString, "#FBBF24")
    }
    func test_allTokensExist() {
        // If this compiles, all tokens are defined.
        _ = Palette.polarNight
        _ = Palette.polarDeep
        _ = Palette.polarRoyal
        _ = Palette.polarSky
        _ = Palette.polarSkyLight
        _ = Palette.polarSkyIce
        _ = Palette.polarAmber
        _ = Palette.ink
        _ = Palette.inkMuted
        _ = Palette.inkFaint
        _ = Palette.surfaceGlass
        _ = Palette.surfaceBorder
        _ = Palette.ruleSoft
    }
}

// Test helper — converts SwiftUI Color back to hex for assertion.
private extension Color {
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)),
                      Int(round(g * 255)),
                      Int(round(b * 255)))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:PolarMyFlowTests/PaletteTests -quiet test
```

Expected: compile error — `Palette` is not defined.

- [ ] **Step 3: Implement `Palette.swift`**

Create `PolarMyFlow/Design/Palette.swift`:

```swift
import SwiftUI

enum Palette {
    static let polarNight   = Color(red: 0x0A / 255, green: 0x14 / 255, blue: 0x28 / 255)
    static let polarDeep    = Color(red: 0x14 / 255, green: 0x24 / 255, blue: 0x51 / 255)
    static let polarRoyal   = Color(red: 0x1E / 255, green: 0x3A / 255, blue: 0x8A / 255)
    static let polarSky     = Color(red: 0x60 / 255, green: 0xA5 / 255, blue: 0xFA / 255)
    static let polarSkyLight = Color(red: 0x93 / 255, green: 0xC5 / 255, blue: 0xFD / 255)
    static let polarSkyIce  = Color(red: 0xBF / 255, green: 0xDB / 255, blue: 0xFE / 255)
    static let polarAmber   = Color(red: 0xFB / 255, green: 0xBF / 255, blue: 0x24 / 255)

    static let ink       = Color.white
    static let inkMuted  = Color.white.opacity(0.70)
    static let inkFaint  = Color.white.opacity(0.45)

    static let surfaceGlass  = Color.white.opacity(0.04)
    static let surfaceBorder = Color.white.opacity(0.08)
    static let ruleSoft      = Color.white.opacity(0.14)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:PolarMyFlowTests/PaletteTests -quiet test
```

Expected: PASS — all 4 tests green.

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Design/Palette.swift PolarMyFlowTests/PaletteTests.swift
git commit -m "feat(design): add Palette color tokens for Polaris palette"
```

---

## Task 3: Typography — font tokens

**Files:**
- Create: `PolarMyFlow/Design/Typography.swift`
- Create: `PolarMyFlowTests/TypographyTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PolarMyFlowTests/TypographyTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import PolarMyFlow

final class TypographyTests: XCTestCase {
    func test_antonFontIsRegistered() {
        let font = UIFont(name: "Anton-Regular", size: 42)
        XCTAssertNotNil(font, "Anton-Regular should be bundled and registered via UIAppFonts")
    }

    func test_typographyFactoryProducesAllRoles() {
        // Compile-time check — if these identifiers exist, the API is in place.
        _ = Font.displayJumbo
        _ = Font.displayLarge
        _ = Font.displayMedium
        _ = Font.displaySmall
        _ = Font.displayTab
        _ = Font.metaDefault
        _ = Font.metaSmall
        _ = Font.bodyDefault
        _ = Font.bodyCaption
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:PolarMyFlowTests/TypographyTests -quiet test
```

Expected: compile error — `displayJumbo` etc. not defined.

- [ ] **Step 3: Implement `Typography.swift`**

Create `PolarMyFlow/Design/Typography.swift`:

```swift
import SwiftUI

extension Font {
    // Display face — Anton, condensed, uppercase
    static let displayJumbo  = Font.custom("Anton-Regular", size: 86)
    static let displayLarge  = Font.custom("Anton-Regular", size: 42)
    static let displayMedium = Font.custom("Anton-Regular", size: 34)
    static let displaySmall  = Font.custom("Anton-Regular", size: 26)
    static let displayTab    = Font.custom("Anton-Regular", size: 14)

    // Meta — SF Mono, uppercase, wide tracking (caller applies .tracking/.textCase)
    static let metaDefault = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let metaSmall   = Font.system(size:  9, weight: .medium, design: .monospaced)

    // Body — SF Pro Text
    static let bodyDefault = Font.system(size: 13, weight: .regular)
    static let bodyCaption = Font.system(size: 11, weight: .regular)
}

/// Common meta-label styling: uppercase, tracked, faint ink.
struct MetaLabel: ViewModifier {
    var size: Font = .metaDefault
    var color: Color = Palette.inkFaint
    func body(content: Content) -> some View {
        content
            .font(size)
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    func metaLabel(_ size: Font = .metaDefault, color: Color = Palette.inkFaint) -> some View {
        modifier(MetaLabel(size: size, color: color))
    }
}

/// Display text with the 2pt offset shadow in polarNight at 90% alpha.
struct DisplayShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Palette.polarNight.opacity(0.9), radius: 0, x: 2, y: 2)
    }
}

extension View {
    func displayShadow() -> some View { modifier(DisplayShadow()) }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:PolarMyFlowTests/TypographyTests -quiet test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Design/Typography.swift PolarMyFlowTests/TypographyTests.swift
git commit -m "feat(design): add Typography tokens and meta/display view modifiers"
```

---

## Task 4: PolarBackground view modifier

**Files:**
- Create: `PolarMyFlow/Design/PolarBackground.swift`

- [ ] **Step 1: Create `PolarBackground.swift`**

```swift
import SwiftUI

struct PolarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Palette.polarNight, Palette.polarDeep, Palette.polarRoyal],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    RadialGradient(
                        colors: [Palette.polarSky.opacity(0.35), .clear],
                        center: UnitPoint(x: 1.0, y: 0.0),
                        startRadius: 0,
                        endRadius: 420
                    )
                    .blendMode(.screen)
                    .ignoresSafeArea()
                }
            }
            .foregroundStyle(Palette.ink)
            .preferredColorScheme(.dark)
    }
}

extension View {
    func polarBackground() -> some View { modifier(PolarBackground()) }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Design/PolarBackground.swift
git commit -m "feat(design): add PolarBackground view modifier with radial glow gradient"
```

---

## Task 5: Assets.xcassets scaffold + AppIcon

**Files:**
- Create: `PolarMyFlow/Assets.xcassets/Contents.json`
- Create: `PolarMyFlow/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `PolarMyFlow/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Create: `PolarMyFlow/Assets.xcassets/AppIcon.appiconset/AppIcon-source.svg` (reference only, not bundled)

- [ ] **Step 1: Create the root catalog**

```bash
mkdir -p PolarMyFlow/Assets.xcassets/AppIcon.appiconset
cat > PolarMyFlow/Assets.xcassets/Contents.json <<'EOF'
{
  "info": { "author": "xcode", "version": 1 }
}
EOF
```

- [ ] **Step 2: Create the AppIcon manifest (single-size, Xcode 15+)**

```bash
cat > PolarMyFlow/Assets.xcassets/AppIcon.appiconset/Contents.json <<'EOF'
{
  "images": [
    {
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024",
      "filename": "AppIcon-1024.png"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
EOF
```

- [ ] **Step 3: Save the SVG source for the icon**

Create `PolarMyFlow/Assets.xcassets/AppIcon.appiconset/AppIcon-source.svg` with:

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#0A1428"/>
      <stop offset="55%" stop-color="#142451"/>
      <stop offset="100%" stop-color="#1E3A8A"/>
    </linearGradient>
    <radialGradient id="glow" cx="85%" cy="8%" r="55%">
      <stop offset="0%" stop-color="#60A5FA" stop-opacity="0.55"/>
      <stop offset="100%" stop-color="#60A5FA" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="track" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#93C5FD"/>
    </linearGradient>
  </defs>
  <!-- background -->
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <rect width="1024" height="1024" fill="url(#glow)"/>
  <!-- hollow moon, top-right -->
  <g transform="translate(760,180)">
    <circle cx="0" cy="0" r="78" fill="none" stroke="#BFDBFE" stroke-width="10" opacity="0.8"/>
    <circle cx="22" cy="-8" r="70" fill="#0A1428"/>
  </g>
  <!-- two tracks carving, angled -12° counter-clockwise, ~74% of height -->
  <g transform="rotate(-12 512 512)">
    <rect x="356" y="135" width="72" height="754" rx="36" fill="url(#track)"/>
    <rect x="596" y="135" width="72" height="754" rx="36" fill="url(#track)"/>
  </g>
</svg>
```

- [ ] **Step 4: Render the SVG to a 1024×1024 PNG**

Install rsvg-convert if not present, then render:

```bash
brew list librsvg >/dev/null 2>&1 || brew install librsvg
rsvg-convert -w 1024 -h 1024 \
  PolarMyFlow/Assets.xcassets/AppIcon.appiconset/AppIcon-source.svg \
  -o PolarMyFlow/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

Expected: `AppIcon-1024.png` exists and is ~50–150 KB. Confirm:
```bash
file PolarMyFlow/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

Expected output: `PNG image data, 1024 x 1024, …`

- [ ] **Step 5: Remove any legacy `AppIcon` setting from `project.yml` and rebuild**

Verify `project.yml` has no `ASSETCATALOG_COMPILER_APPICON_NAME` override. If present, remove it. Then regenerate + build:

```bash
xcodegen generate
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add PolarMyFlow/Assets.xcassets PolarMyFlow.xcodeproj
git commit -m "feat(design): add Assets.xcassets with Waxed Flows two-tracks app icon"
```

---

## Task 6: Sport icon assets (SVG imagesets) + two-tracks mark

**Files:**
- Create: `PolarMyFlow/Assets.xcassets/Sports/<sport>.imageset/Contents.json` + `.svg` — 10 imagesets
- Create: `PolarMyFlow/Assets.xcassets/Tracks/tracksMark.imageset/Contents.json` + `.svg`

- [ ] **Step 1: Create a helper script to scaffold one imageset**

All 10 sport imagesets share the same `Contents.json`. Run from repo root:

```bash
make_imageset() {
  local name="$1"
  local dir="PolarMyFlow/Assets.xcassets/Sports/${name}.imageset"
  mkdir -p "$dir"
  cat > "$dir/Contents.json" <<EOF
{
  "images": [
    { "idiom": "universal", "filename": "${name}.svg" }
  ],
  "info": { "author": "xcode", "version": 1 },
  "properties": { "preserves-vector-representation": true, "template-rendering-intent": "template" }
}
EOF
}
```

Save this function to a shell session (do not commit as a script — one-shot use).

- [ ] **Step 2: Create each sport imageset's `Contents.json`**

Run:
```bash
for s in sport-xc-skiing sport-running sport-cycling sport-swimming sport-hiking \
         sport-strength sport-rowing sport-mountain-biking sport-walking sport-other; do
  make_imageset "$s"
done
```

Expected: `PolarMyFlow/Assets.xcassets/Sports/` has 10 `.imageset/` directories, each with `Contents.json`.

- [ ] **Step 3: Write each sport's SVG glyph**

All SVGs are 64×64, `fill="currentColor"` so the template-rendering tint applies.

`sport-xc-skiing.svg` (two parallel angled strokes — classic tracks):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none">
  <g transform="rotate(-18 32 32)" fill="currentColor">
    <rect x="18" y="8"  width="6" height="48" rx="3"/>
    <rect x="40" y="8"  width="6" height="48" rx="3"/>
  </g>
</svg>
```

`sport-running.svg` (forward-leaning slash + baseline):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="currentColor">
  <rect x="22" y="6" width="7" height="44" rx="3" transform="rotate(-20 25 28)"/>
  <rect x="10" y="50" width="44" height="5" rx="2"/>
</svg>
```

`sport-cycling.svg` (two circles joined by a diagonal):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round">
  <circle cx="16" cy="46" r="11"/>
  <circle cx="48" cy="46" r="11"/>
  <line x1="20" y1="18" x2="44" y2="46"/>
</svg>
```

`sport-swimming.svg` (three stacked waves):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round">
  <path d="M6 22 Q18 12, 32 22 T58 22"/>
  <path d="M6 34 Q18 24, 32 34 T58 34"/>
  <path d="M6 46 Q18 36, 32 46 T58 46"/>
</svg>
```

`sport-hiking.svg` (two triangles — larger behind smaller):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="currentColor">
  <polygon points="4,56 28,14 50,56"/>
  <polygon points="30,56 46,26 60,56" opacity="0.75"/>
</svg>
```

`sport-strength.svg` (solid bar with flanking squares — dumbbell):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="currentColor">
  <rect x="6" y="22" width="10" height="20" rx="2"/>
  <rect x="48" y="22" width="10" height="20" rx="2"/>
  <rect x="16" y="29" width="32" height="6" rx="1"/>
</svg>
```

`sport-rowing.svg` (horizontal stroke + two oars):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round">
  <line x1="8" y1="32" x2="56" y2="32"/>
  <line x1="20" y1="12" x2="28" y2="32"/>
  <line x1="44" y1="52" x2="36" y2="32"/>
</svg>
```

`sport-mountain-biking.svg` (cycling glyph + small triangle behind):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round">
  <polygon points="6,48 24,20 40,48" fill="currentColor" opacity="0.55" stroke="none"/>
  <circle cx="18" cy="50" r="9"/>
  <circle cx="46" cy="50" r="9"/>
  <line x1="22" y1="26" x2="42" y2="50"/>
</svg>
```

`sport-walking.svg` (a lighter forward slash):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="currentColor">
  <rect x="24" y="8" width="5" height="46" rx="2" transform="rotate(-10 26 30)"/>
</svg>
```

`sport-other.svg` (plus mark):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="currentColor">
  <rect x="28" y="10" width="8" height="44" rx="2"/>
  <rect x="10" y="28" width="44" height="8" rx="2"/>
</svg>
```

Write each file to its matching imageset directory (e.g. `Sports/sport-xc-skiing.imageset/sport-xc-skiing.svg`).

- [ ] **Step 4: Create the Tracks mark (empty state + Tracks placeholder decoration)**

```bash
mkdir -p PolarMyFlow/Assets.xcassets/Tracks/tracksMark.imageset
cat > PolarMyFlow/Assets.xcassets/Tracks/tracksMark.imageset/Contents.json <<'EOF'
{
  "images": [
    { "idiom": "universal", "filename": "tracksMark.svg" }
  ],
  "info": { "author": "xcode", "version": 1 },
  "properties": { "preserves-vector-representation": true, "template-rendering-intent": "template" }
}
EOF
```

And the SVG (`PolarMyFlow/Assets.xcassets/Tracks/tracksMark.imageset/tracksMark.svg`):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120" fill="currentColor">
  <g transform="rotate(-12 60 60)">
    <rect x="34" y="14" width="10" height="92" rx="5"/>
    <rect x="76" y="14" width="10" height="92" rx="5"/>
  </g>
</svg>
```

- [ ] **Step 5: Build to verify asset catalog compiles**

```bash
xcodegen generate
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`, no asset-catalog warnings.

- [ ] **Step 6: Commit**

```bash
git add PolarMyFlow/Assets.xcassets
git commit -m "feat(design): add 10 custom sport glyphs and the two-tracks mark"
```

---

## Task 7: Update `SportType` to expose `iconName` and `dotColor`

**Files:**
- Modify: `PolarMyFlow/Models/SportType.swift`
- Modify: `PolarMyFlowTests/SportTypeTests.swift`

- [ ] **Step 1: Replace the two `symbolName` tests with `iconName` and `dotColor` tests**

Edit `PolarMyFlowTests/SportTypeTests.swift`. Replace the `test_symbolName_xcSkiing` and `test_symbolName_other_isValid` methods with:

```swift
    func test_iconName_xcSkiing() {
        XCTAssertEqual(SportType.xcSkiing.iconName, "sport-xc-skiing")
    }

    func test_iconName_allCasesNonEmpty() {
        for sport in SportType.allCases {
            XCTAssertFalse(sport.iconName.isEmpty, "\(sport) has empty iconName")
        }
    }

    func test_dotColor_allCasesDefined() {
        // Compile-time guarantee — switch exhaustiveness enforces this.
        for sport in SportType.allCases {
            _ = sport.dotColor
        }
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:PolarMyFlowTests/SportTypeTests -quiet test
```

Expected: compile errors for `iconName` and `dotColor`.

- [ ] **Step 3: Update `SportType.swift`**

Replace the `symbolName` computed property in `PolarMyFlow/Models/SportType.swift` with these two (and add an `import SwiftUI`):

```swift
import SwiftUI

extension SportType {
    var iconName: String {
        switch self {
        case .xcSkiing:       return "sport-xc-skiing"
        case .running:        return "sport-running"
        case .cycling:        return "sport-cycling"
        case .swimming:       return "sport-swimming"
        case .hiking:         return "sport-hiking"
        case .strength:       return "sport-strength"
        case .rowing:         return "sport-rowing"
        case .mountainBiking: return "sport-mountain-biking"
        case .walking:        return "sport-walking"
        case .other:          return "sport-other"
        }
    }

    var dotColor: Color {
        switch self {
        case .xcSkiing:       return Palette.polarSkyLight
        case .running:        return Palette.polarAmber
        case .cycling:        return Color(red: 0xFC / 255, green: 0xD3 / 255, blue: 0x4D / 255)
        case .swimming:       return Palette.polarSkyIce
        case .hiking:         return Color(red: 0x6E / 255, green: 0xE7 / 255, blue: 0xB7 / 255)
        case .strength:       return Color(red: 0xF8 / 255, green: 0x71 / 255, blue: 0x71 / 255)
        case .rowing:         return Color(red: 0xA7 / 255, green: 0x8B / 255, blue: 0xFA / 255)
        case .mountainBiking: return Color(red: 0xFB / 255, green: 0x92 / 255, blue: 0x3C / 255)
        case .walking:        return Palette.polarSkyIce
        case .other:          return Palette.inkMuted
        }
    }
}
```

And **remove** the existing `symbolName` computed property block (lines 57–80 in the current file).

Note: Since `SportType` is defined in a single `.swift` file, `import SwiftUI` at the file top is enough — remove the standalone `extension SportType` if you prefer and put `iconName`/`dotColor` directly in the original enum body.

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:PolarMyFlowTests/SportTypeTests -quiet test
```

Expected: all `SportTypeTests` green.

- [ ] **Step 5: Verify dependent files compile**

The old `symbolName` was used in:
- `ContentView.swift` — only via `.tabItem { Label(..., systemImage: ...) }` (system symbols, unrelated to `SportType`)
- `SeasonCardView.swift` — `Image(systemName: summary.sport.symbolName)`
- `ActivityRowView.swift` — `Image(systemName: activity.sportType.symbolName)`
- `ActivityListView.swift` — `Label(sport.displayName, systemImage: sport.symbolName)`

These will now fail to compile. Temporarily replace each `systemName: X.symbolName` with `systemName: "circle"` (placeholder) in the three files so the build passes for now — Tasks 13–15 will rebuild those views properly.

Run:
```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add PolarMyFlow/Models/SportType.swift PolarMyFlowTests/SportTypeTests.swift \
        PolarMyFlow/Features/Dashboard/SeasonCardView.swift \
        PolarMyFlow/Features/ActivityList/ActivityRowView.swift \
        PolarMyFlow/Features/ActivityList/ActivityListView.swift
git commit -m "refactor(design): replace SportType.symbolName with iconName + dotColor"
```

---

## Task 8: Shared components — PolarCard, PolarBadge, PolarRule

**Files:**
- Create: `PolarMyFlow/Design/Components/PolarCard.swift`
- Create: `PolarMyFlow/Design/Components/PolarBadge.swift`
- Create: `PolarMyFlow/Design/Components/PolarRule.swift`

- [ ] **Step 1: Create `PolarCard.swift`**

```swift
import SwiftUI

struct PolarCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.surfaceGlass, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Palette.surfaceBorder, lineWidth: 1)
            )
    }
}
```

- [ ] **Step 2: Create `PolarBadge.swift`**

```swift
import SwiftUI

struct PolarBadge: View {
    enum Style { case outline, filled }

    let text: String
    var style: Style = .outline

    var body: some View {
        Text(text)
            .font(.metaDefault)
            .tracking(1.8)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(style == .filled ? Palette.polarNight : Palette.ink)
            .background {
                Capsule().fill(style == .filled ? Palette.polarSky : Color.clear)
            }
            .overlay {
                Capsule().strokeBorder(Palette.surfaceBorder, lineWidth: style == .outline ? 1 : 0)
            }
    }
}
```

- [ ] **Step 3: Create `PolarRule.swift`**

```swift
import SwiftUI

struct PolarRule: View {
    enum Variant { case soft, full }
    var variant: Variant = .full

    var body: some View {
        switch variant {
        case .soft:
            Rectangle()
                .fill(LinearGradient(
                    colors: [Palette.ink.opacity(0.6), .clear],
                    startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        case .full:
            Rectangle()
                .fill(Palette.ruleSoft)
                .frame(height: 1)
        }
    }
}
```

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Design/Components/PolarCard.swift \
        PolarMyFlow/Design/Components/PolarBadge.swift \
        PolarMyFlow/Design/Components/PolarRule.swift
git commit -m "feat(design): add PolarCard, PolarBadge, PolarRule components"
```

---

## Task 9: Shared components — SportGlyph, PolarEmptyState, PolarActionIcon

**Files:**
- Create: `PolarMyFlow/Design/Components/SportGlyph.swift`
- Create: `PolarMyFlow/Design/Components/PolarEmptyState.swift`
- Create: `PolarMyFlow/Design/Components/PolarActionIcon.swift`

- [ ] **Step 1: Create `SportGlyph.swift`**

```swift
import SwiftUI

struct SportGlyph: View {
    let sport: SportType
    var size: CGFloat = 24
    var tint: Color = Palette.polarSkyLight

    var body: some View {
        Image(sport.iconName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }
}
```

- [ ] **Step 2: Create `PolarEmptyState.swift`**

```swift
import SwiftUI

struct PolarEmptyState: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("tracksMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(Palette.ink.opacity(0.4))

            Text(title)
                .font(.displayMedium)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Palette.ink)
                .displayShadow()

            Text(description)
                .font(.bodyDefault)
                .foregroundStyle(Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: Create `PolarActionIcon.swift`**

```swift
import SwiftUI

/// One of the five allow-listed chrome SF Symbols with a standard tint.
/// Allowed: checkmark.circle, arrow.triangle.2.circlepath, exclamationmark.triangle,
/// square.and.arrow.down, arrow.down.doc.
struct PolarActionIcon: View {
    let systemName: String
    var size: CGFloat = 14
    var tint: Color = Palette.polarSkyLight

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(tint)
    }
}
```

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add PolarMyFlow/Design/Components/SportGlyph.swift \
        PolarMyFlow/Design/Components/PolarEmptyState.swift \
        PolarMyFlow/Design/Components/PolarActionIcon.swift
git commit -m "feat(design): add SportGlyph, PolarEmptyState, PolarActionIcon components"
```

---

## Task 10: Shared component — PolarTabBar

**Files:**
- Create: `PolarMyFlow/Design/Components/PolarTabBar.swift`

- [ ] **Step 1: Create `PolarTabBar.swift`**

```swift
import SwiftUI

enum PolarTab: Int, CaseIterable, Identifiable {
    case dash, log, tracks, settings
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .dash:     return "Dash"
        case .log:      return "Log"
        case .tracks:   return "Tracks"
        case .settings: return "Set"
        }
    }

    var glyph: String {
        switch self {
        case .dash:     return "◆"
        case .log:      return "≡"
        case .tracks:   return "△"
        case .settings: return "⚙"
        }
    }
}

struct PolarTabBar: View {
    @Binding var selection: PolarTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PolarTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    tabContent(tab)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Palette.polarNight.opacity(0.88)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.surfaceBorder)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: PolarTab) -> some View {
        let isActive = tab == selection
        VStack(spacing: 6) {
            Text(tab.glyph)
                .font(.system(size: 20))
            Text(tab.label)
                .font(.displayTab)
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .foregroundStyle(isActive ? Palette.polarSkyLight : Palette.ink.opacity(0.55))
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .fill(Palette.polarSkyLight)
                    .frame(height: 2)
                    .padding(.horizontal, 24)
                    .offset(y: 8)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Design/Components/PolarTabBar.swift
git commit -m "feat(design): add PolarTabBar component with chunky display labels"
```

---

## Task 11: Shared component — HRZoneChart

**Files:**
- Create: `PolarMyFlow/Design/Components/HRZoneChart.swift`

Per "Known limitations" at the top: this component is built to spec but not wired to `ActivityDetailView` — zone breakdown isn't in the `Activity` model.

- [ ] **Step 1: Create `HRZoneChart.swift`**

```swift
import SwiftUI

/// Renders Z1-Z5 bars as fractions (0…1). Fractions above 1 clamp to 1.
///
/// Not currently wired to any screen — the Activity model does not expose
/// zone-time data. Kept here so a future data-model extension can drop it in.
struct HRZoneChart: View {
    /// Five values in Z1…Z5 order, each 0…1 of max height.
    let fractions: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(fractions.prefix(5).enumerated()), id: \.offset) { index, raw in
                    let v = max(0, min(raw, 1))
                    Rectangle()
                        .fill(Self.color(for: index))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(2, 56 * CGFloat(v)))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(height: 56, alignment: .bottom)

            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Text("Z\(index + 1)")
                        .font(.metaSmall)
                        .tracking(1.2)
                        .foregroundStyle(Palette.inkFaint)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private static func color(for index: Int) -> Color {
        switch index {
        case 0, 1: return Palette.polarSky
        case 2:    return Palette.polarSkyLight
        case 3:    return Palette.polarSkyIce
        case 4:    return Palette.polarAmber
        default:   return Palette.polarSky
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Design/Components/HRZoneChart.swift
git commit -m "feat(design): add HRZoneChart component (not yet wired — needs zone data)"
```

---

## Task 12: Restyle `ContentView` — LoginView + MainTabView

**Files:**
- Modify: `PolarMyFlow/ContentView.swift`

- [ ] **Step 1: Rewrite `ContentView.swift`**

Replace the entire file with:

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    let syncMessage: String?
    let isSyncing: Bool

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView(syncMessage: syncMessage, isSyncing: isSyncing)
            } else {
                LoginView()
            }
        }
        .polarBackground()
    }
}

struct MainTabView: View {
    let syncMessage: String?
    let isSyncing: Bool
    @State private var selection: PolarTab = .dash

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .padding(.bottom, 80)  // room for custom tab bar

            VStack(spacing: 0) {
                if isSyncing || syncMessage != nil {
                    syncPill
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }
                Spacer()
                PolarTabBar(selection: $selection)
            }
        }
    }

    @ViewBuilder private var tabContent: some View {
        switch selection {
        case .dash:     DashboardView()
        case .log:      ActivityListView()
        case .tracks:   TracksPlaceholderView()
        case .settings: SettingsView()
        }
    }

    @ViewBuilder private var syncPill: some View {
        HStack(spacing: 8) {
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Palette.polarSkyLight)
            }
            if let syncMessage {
                Text(syncMessage)
                    .font(.metaSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Palette.surfaceGlass, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.surfaceBorder, lineWidth: 1))
    }
}

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                (Text("Waxed\n").foregroundStyle(Palette.ink)
                 + Text("Flows.").foregroundStyle(Palette.polarSkyLight))
                    .font(.displayMedium)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-4)
                    .displayShadow()

                Text("Your season · your line")
                    .metaLabel()
            }

            PolarRule(variant: .soft)
                .frame(maxWidth: 220)

            Text("Connect your Polar account to view your training history.")
                .font(.bodyDefault)
                .foregroundStyle(Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let errorMessage {
                Text(errorMessage)
                    .font(.bodyCaption)
                    .foregroundStyle(Palette.polarAmber)
            }

            Button {
                Task {
                    isAuthenticating = true
                    errorMessage = nil
                    do { try await authManager.authenticate() }
                    catch { errorMessage = error.localizedDescription }
                    isAuthenticating = false
                }
            } label: {
                Group {
                    if isAuthenticating {
                        ProgressView().tint(Palette.polarNight)
                    } else {
                        Text("Connect")
                            .font(.displayTab)
                            .tracking(0.8)
                            .textCase(.uppercase)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Palette.polarNight)
                .background(Palette.polarSky, in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isAuthenticating)
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`. (Screens still use old chrome underneath — they'll be rebuilt in Tasks 13–19.)

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/ContentView.swift
git commit -m "refactor(design): restyle Login + MainTabView with PolarBackground and PolarTabBar"
```

---

## Task 13: Restyle Dashboard + SeasonCardView

**Files:**
- Modify: `PolarMyFlow/Features/Dashboard/DashboardView.swift`
- Modify: `PolarMyFlow/Features/Dashboard/SeasonCardView.swift`

- [ ] **Step 1: Rewrite `SeasonCardView.swift`**

```swift
import SwiftUI

struct SeasonCardView: View {
    let summary: SeasonSummary
    let onTapSport: (SportType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(summary.season.label)
                .metaLabel(.metaDefault, color: Palette.inkMuted)

            VStack(spacing: 10) {
                ForEach(summary.sportSummaries) { sport in
                    Button {
                        onTapSport(sport.sport)
                    } label: {
                        SportRowView(summary: sport)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct SportRowView: View {
    let summary: SportSummary

    var body: some View {
        PolarCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(summary.sport.dotColor)
                        .frame(width: 6, height: 6)
                    Text(summary.sport.displayName)
                        .metaLabel(.metaDefault, color: Palette.ink)
                        .tracking(1.4)
                    Spacer()
                    PolarBadge(text: "\(summary.sessionCount) Sessions")
                }

                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(ActivityFormatting.distanceKm(summary.totalDistance))
                            .font(.displayLarge)
                            .foregroundStyle(Palette.ink)
                            .displayShadow()
                        Text("km")
                            .font(.bodyCaption)
                            .foregroundStyle(Palette.inkMuted)
                    }
                    Spacer()
                    Text("Avg \(ActivityFormatting.paceMinPerKm(summary.avgPace))")
                        .font(.bodyCaption)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Rewrite `DashboardView.swift`**

```swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var navigationPath = NavigationPath()
    @State private var selectedSport: SportType?
    @State private var selectedSeason: Season?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .polarBackground()
                .navigationBarHidden(true)
                .navigationDestination(for: String.self) { _ in
                    if let sport = selectedSport, let season = selectedSeason {
                        SportDetailView(sport: sport, season: season)
                    }
                }
        }
        .task {
            let repo = ActivityRepository(context: modelContext)
            let vm = DashboardViewModel(repository: repo)
            viewModel = vm
            await vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .debugResetSync)) { _ in
            Task {
                let repo = ActivityRepository(context: modelContext)
                let vm = DashboardViewModel(repository: repo)
                viewModel = vm
                await vm.load()
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let vm = viewModel {
            if vm.isLoading {
                ProgressView().tint(Palette.polarSkyLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.seasons.isEmpty {
                PolarEmptyState(
                    title: "No Sessions Yet",
                    description: "Sync your Polar account to see your training history."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        ForEach(vm.seasons) { season in
                            SeasonCardView(summary: season) { sport in
                                selectedSport = sport
                                selectedSeason = season.season
                                navigationPath.append("sport-detail")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 48)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dashboard · Seasons")
                .metaLabel()
            PolarRule(variant: .soft)
            (Text("Waxed\n").foregroundStyle(Palette.ink)
             + Text("Flows.").foregroundStyle(Palette.polarSkyLight))
                .font(.displayMedium)
                .lineSpacing(-4)
                .displayShadow()
        }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add PolarMyFlow/Features/Dashboard/DashboardView.swift \
        PolarMyFlow/Features/Dashboard/SeasonCardView.swift
git commit -m "refactor(design): restyle Dashboard and SeasonCardView with Polar components"
```

---

## Task 14: Restyle SportDetailView

**Files:**
- Modify: `PolarMyFlow/Features/Dashboard/SportDetailView.swift`

- [ ] **Step 1: Rewrite `SportDetailView.swift`**

```swift
import SwiftUI
import SwiftData

struct SportDetailView: View {
    let sport: SportType
    let season: Season
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SportDetailViewModel?

    var body: some View {
        content
            .polarBackground()
            .navigationBarHidden(true)
            .task {
                let repo = ActivityRepository(context: modelContext)
                let vm = SportDetailViewModel(sport: sport, season: season, repository: repo)
                viewModel = vm
                await vm.load()
            }
    }

    @ViewBuilder private var content: some View {
        if let vm = viewModel {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryRow(vm)
                    datePickerBlock(vm)
                    activitiesBlock(vm)
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { dismiss() } label: {
                Text("◂ Dash · \(season.label)")
                    .metaLabel()
            }
            .buttonStyle(.plain)
            PolarRule(variant: .soft)
            Text(sport.displayName)
                .font(.displayMedium)
                .textCase(.uppercase)
                .foregroundStyle(Palette.polarSkyLight)
                .displayShadow()
        }
    }

    private func summaryRow(_ vm: SportDetailViewModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            statBlock(value: vm.totalDistance, unit: "Total")
            Spacer()
            statBlock(value: vm.sessionCount, unit: "Sessions")
        }
    }

    private func statBlock(value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.displaySmall)
                .foregroundStyle(Palette.ink)
                .displayShadow()
            Text(unit).metaLabel()
        }
    }

    private func datePickerBlock(_ vm: SportDetailViewModel) -> some View {
        PolarCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Date Range").metaLabel()
                DatePicker("From", selection: Binding(
                    get: { vm.startDate },
                    set: { vm.startDate = $0; Task { await vm.load() } }
                ), displayedComponents: .date)
                    .font(.bodyDefault)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.polarSky)
                DatePicker("To", selection: Binding(
                    get: { vm.endDate },
                    set: { vm.endDate = $0; Task { await vm.load() } }
                ), displayedComponents: .date)
                    .font(.bodyDefault)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.polarSky)
            }
        }
    }

    @ViewBuilder
    private func activitiesBlock(_ vm: SportDetailViewModel) -> some View {
        Text("Sessions").metaLabel()
        if vm.activities.isEmpty {
            Text("No activities in this range")
                .font(.bodyDefault)
                .foregroundStyle(Palette.inkMuted)
        } else {
            VStack(spacing: 0) {
                ForEach(vm.activities, id: \.id) { activity in
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        ActivityRowView(activity: activity)
                    }
                    .buttonStyle(.plain)
                    PolarRule(variant: .full)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Features/Dashboard/SportDetailView.swift
git commit -m "refactor(design): restyle SportDetailView — custom scroll on PolarBackground"
```

---

## Task 15: Restyle ActivityListView + ActivityRowView

**Files:**
- Modify: `PolarMyFlow/Features/ActivityList/ActivityListView.swift`
- Modify: `PolarMyFlow/Features/ActivityList/ActivityRowView.swift`

- [ ] **Step 1: Rewrite `ActivityRowView.swift`**

```swift
import SwiftUI

struct ActivityRowView: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                SportGlyph(sport: activity.sportType, size: 24)
                Circle()
                    .fill(activity.sportType.dotColor)
                    .frame(width: 6, height: 6)
                    .offset(x: 2, y: 2)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.sportType.displayName)
                    .font(.displaySmall)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.ink)
                Text(activity.startTime.formatted(date: .abbreviated, time: .shortened))
                    .metaLabel()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ActivityFormatting.distanceKm(activity.distance))
                    .font(.displaySmall)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                if let hr = activity.avgHeartRate {
                    Text("\(hr) bpm")
                        .font(.bodyCaption)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 2: Rewrite `ActivityListView.swift`**

```swift
import SwiftUI
import SwiftData

struct ActivityListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ActivityListViewModel?

    var body: some View {
        NavigationStack {
            content
                .polarBackground()
                .navigationBarHidden(true)
        }
        .task {
            if viewModel == nil {
                let repo = ActivityRepository(context: modelContext)
                viewModel = ActivityListViewModel(repository: repo)
            }
            await viewModel?.load()
        }
        .onAppear {
            Task { await viewModel?.load() }
        }
    }

    @ViewBuilder private var content: some View {
        if let vm = viewModel {
            VStack(alignment: .leading, spacing: 0) {
                header
                if !vm.availableSports.isEmpty {
                    filterRow(vm)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }
                if vm.activities.isEmpty {
                    PolarEmptyState(
                        title: "No Sessions Found",
                        description: "Try a different sport filter or sync your Polar account."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.activities, id: \.id) { activity in
                                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                    ActivityRowView(activity: activity)
                                }
                                .buttonStyle(.plain)
                                PolarRule(variant: .full)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.top, 48)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Log · All Sessions")
                .metaLabel()
            PolarRule(variant: .soft)
        }
        .padding(.horizontal, 20)
    }

    private func filterRow(_ vm: ActivityListViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterBadge(
                    text: "All",
                    selected: vm.selectedSport == nil,
                    action: { vm.selectedSport = nil }
                )
                ForEach(vm.availableSports, id: \.self) { sport in
                    filterBadge(
                        text: sport.displayName,
                        selected: vm.selectedSport == sport,
                        action: { vm.selectedSport = sport }
                    )
                }
            }
        }
    }

    private func filterBadge(text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PolarBadge(text: text, style: selected ? .filled : .outline)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add PolarMyFlow/Features/ActivityList/ActivityListView.swift \
        PolarMyFlow/Features/ActivityList/ActivityRowView.swift
git commit -m "refactor(design): restyle ActivityList + row with sport glyph, badges, empty state"
```

---

## Task 16: Restyle ActivityDetailView

**Files:**
- Modify: `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift`

- [ ] **Step 1: Rewrite `ActivityDetailView.swift`**

```swift
import SwiftUI

struct ActivityDetailView: View {
    let activity: Activity
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityDetailViewModel?

    var body: some View {
        content
            .polarBackground()
            .navigationBarHidden(true)
            .onAppear { viewModel = ActivityDetailViewModel(activity: activity) }
    }

    @ViewBuilder private var content: some View {
        if let vm = viewModel {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(vm)
                    heroStats(vm)
                    PolarRule(variant: .full)
                    threeUp(vm)
                    // FIXME: HR zone chart not wired — Activity model has no zone-time data.
                    if vm.ascentString != nil || vm.descentString != nil {
                        PolarRule(variant: .full)
                        elevation(vm)
                    }
                    if let calories = vm.caloriesString {
                        PolarRule(variant: .full)
                        energy(calories)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
            }
        }
    }

    private func header(_ vm: ActivityDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { dismiss() } label: {
                Text("◂ Log · \(vm.dateString)")
                    .metaLabel()
            }
            .buttonStyle(.plain)
            PolarRule(variant: .soft)
            Text(vm.title)
                .font(.displaySmall)
                .textCase(.uppercase)
                .foregroundStyle(Palette.polarSkyLight)
                .displayShadow()
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
                Spacer()
            }
            if let asc = vm.ascentString {
                statCell(value: asc, label: "Ascent m")
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

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Features/ActivityList/ActivityDetailView.swift
git commit -m "refactor(design): rebuild ActivityDetailView as custom scroll with display stats"
```

---

## Task 17: Restyle TracksPlaceholderView

**Files:**
- Modify: `PolarMyFlow/Features/Tracks/TracksPlaceholderView.swift`

- [ ] **Step 1: Rewrite `TracksPlaceholderView.swift`**

```swift
import SwiftUI

struct TracksPlaceholderView: View {
    var body: some View {
        ZStack {
            Image("tracksMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 220)
                .foregroundStyle(Palette.ink.opacity(0.08))

            VStack(spacing: 12) {
                Text("Tracks")
                    .font(.displayMedium)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                Text("Coming · 2026 · Summer")
                    .metaLabel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .polarBackground()
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Features/Tracks/TracksPlaceholderView.swift
git commit -m "refactor(design): restyle TracksPlaceholderView with tracks mark watermark"
```

---

## Task 18: Restyle SettingsView

**Files:**
- Modify: `PolarMyFlow/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Rewrite `SettingsView.swift`**

```swift
import SwiftUI
import SwiftData
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @State private var importer: HistoryImporter?
    @State private var showExportInstructions = false
    @State private var showFileImporter = false
    @State private var errorMessage: String?
    @State private var completionMessage: String?
    @AppStorage("com.personal.polarmyflow.importYearsBack") private var storedYearsBack: Int = 4

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    importHistorySection
                    #if DEBUG
                    debugSection
                    #endif
                    accountSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
                .padding(.bottom, 40)
            }
            .polarBackground()
            .navigationBarHidden(true)
            .alert("Export requested", isPresented: $showExportInstructions) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("Polar will email you a download link within a few hours to a few days. When it arrives, tap the link and choose Waxed Flows to share the ZIP into the app. By default Waxed Flows only imports the last 4 years — change Import window above if you want more or fewer years.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .importZipReceived)) { note in
                guard let url = note.object as? URL else { return }
                Task { await runImport(url: url) }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.zip]
            ) { result in
                switch result {
                case .success(let url): Task { await runImport(url: url) }
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings").metaLabel()
            PolarRule(variant: .soft)
        }
    }

    private var importHistorySection: some View {
        settingsGroup(title: "Import History") {
            actionRow(systemIcon: "arrow.down.doc", title: "Request data export from Polar") {
                openPolarExportPage()
            }

            pickerRow(title: "Import Window", selection: $storedYearsBack, options: [
                (2, "Last 2 years"),
                (4, "Last 4 years"),
                (-1, "All time"),
            ])
            .disabled(importer?.isRunning == true)

            actionRow(systemIcon: "square.and.arrow.down", title: "Import from file…") {
                showFileImporter = true
            }
            .disabled(importer?.isRunning == true)

            if let importer, importer.isRunning || importer.processed > 0 {
                ImportProgressView(importer: importer)
            }
            if let completionMessage {
                Text(completionMessage)
                    .font(.bodyCaption)
                    .foregroundStyle(Palette.inkMuted)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.bodyCaption)
                    .foregroundStyle(Palette.polarAmber)
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        settingsGroup(title: "Debug") {
            NavigationLink {
                DebugSettingsView()
                    .polarBackground()
            } label: {
                rowShell {
                    Text("Debug settings")
                        .font(.bodyDefault)
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text("›")
                        .font(.bodyDefault)
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    private var accountSection: some View {
        settingsGroup(title: "Account") {
            Button {
                try? authManager.signOut()
            } label: {
                rowShell {
                    Text("Sign out")
                        .font(.bodyDefault)
                        .foregroundStyle(Palette.polarAmber)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).metaLabel()
            PolarCard {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
            }
        }
    }

    private func actionRow(systemIcon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowShell {
                PolarActionIcon(systemName: systemIcon)
                Text(title)
                    .font(.bodyDefault)
                    .foregroundStyle(Palette.ink)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func pickerRow<Value: Hashable>(
        title: String,
        selection: Binding<Value>,
        options: [(Value, String)]
    ) -> some View {
        HStack {
            Text(title)
                .font(.bodyDefault)
                .foregroundStyle(Palette.ink)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options, id: \.0) { opt in
                    Text(opt.1).tag(opt.0)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.polarSkyLight)
        }
    }

    @ViewBuilder
    private func rowShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .contentShape(Rectangle())
    }

    private func openPolarExportPage() {
        let url = URL(string: "https://account.polar.com/")!
        Task { @MainActor in
            UIApplication.shared.open(url) { _ in
                showExportInstructions = true
            }
        }
    }

    @MainActor
    func runImport(url: URL) async {
        errorMessage = nil
        completionMessage = nil
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let imp = HistoryImporter(context: ModelContext(modelContext.container))
        importer = imp
        do {
            let years: Int? = storedYearsBack >= 0 ? storedYearsBack : nil
            try await imp.importHistory(from: url, yearsBack: years)
            completionMessage = "Imported \(imp.imported) activities. "
                + "\(imp.skipped) duplicates skipped, \(imp.failed) files couldn't be read."
        } catch ImportError.cancelled {
            completionMessage = "Import cancelled. Kept \(imp.imported) activities."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Features/Settings/SettingsView.swift
git commit -m "refactor(design): rebuild SettingsView as custom grouped sections on PolarBackground"
```

---

## Task 19: Restyle ImportProgressView

**Files:**
- Modify: `PolarMyFlow/Features/Settings/ImportProgressView.swift`

- [ ] **Step 1: Rewrite `ImportProgressView.swift`**

```swift
import SwiftUI

struct ImportProgressView: View {
    @Bindable var importer: HistoryImporter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(progressFraction * 100))%")
                    .font(.displaySmall)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                Spacer()
                Text("\(importer.processed) / \(importer.total) Files")
                    .metaLabel()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surfaceBorder)
                    Capsule()
                        .fill(Palette.polarSky)
                        .frame(width: proxy.size.width * progressFraction)
                }
            }
            .frame(height: 2)

            HStack(spacing: 14) {
                statusChip(
                    systemName: "checkmark.circle",
                    text: "\(importer.imported)",
                    tint: Palette.polarSky
                )
                if importer.skipped > 0 {
                    statusChip(
                        systemName: "arrow.triangle.2.circlepath",
                        text: "\(importer.skipped) dup",
                        tint: Palette.polarSkyIce
                    )
                }
                if importer.failed > 0 {
                    statusChip(
                        systemName: "exclamationmark.triangle",
                        text: "\(importer.failed) err",
                        tint: Palette.polarAmber
                    )
                }
                Spacer()
                Button("Cancel") { importer.cancel() }
                    .font(.metaDefault)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.polarSkyLight)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.surfaceGlass, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Palette.surfaceBorder, lineWidth: 1)
        )
    }

    private var progressFraction: Double {
        guard importer.total > 0 else { return 0 }
        return min(1, Double(importer.processed) / Double(importer.total))
    }

    private func statusChip(systemName: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            PolarActionIcon(systemName: systemName, size: 12, tint: tint)
            Text(text)
                .font(.metaDefault)
                .tracking(1.2)
                .foregroundStyle(tint)
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme PolarMyFlow -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -quiet build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add PolarMyFlow/Features/Settings/ImportProgressView.swift
git commit -m "refactor(design): restyle ImportProgressView with polar chips and sky progress bar"
```

---

## Task 20: Run full test suite to confirm ViewModels/formatters still pass

**Files:** None modified — this is a verification-only task.

- [ ] **Step 1: Run all tests**

```bash
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 15' \
  -quiet test
```

Expected: all tests green. Specifically:
- `PaletteTests` — 4 pass
- `TypographyTests` — 2 pass
- `SportTypeTests` — all pass with new `iconName` / `dotColor` tests
- All other existing tests (ActivityRepository, DashboardViewModel, GDPRTrainingSession, HistoryImporter, Keychain, PolarAccessLinkClient, Season, SyncCoordinator, ActivityDetailViewModel) — all pass

If any fail: do not commit until they're green. The refresh is supposed to be presentation-only, so any non-presentation failure is a bug this plan introduced.

- [ ] **Step 2: No commit** (no files changed).

---

## Task 21: Manual simulator smoke test

**Files:** None modified — this is a verification-only task.

- [ ] **Step 1: Boot simulator and launch app**

```bash
xcrun simctl boot "iPhone 15" 2>/dev/null || true
open -a Simulator
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 15' \
  -derivedDataPath build -quiet build
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/PolarMyFlow.app
xcrun simctl launch booted com.personal.polarmyflow
```

- [ ] **Step 2: Walk through every screen and confirm**

| Screen | Confirm |
|---|---|
| Home screen (springboard) | New two-tracks icon; app name below icon reads "Waxed Flows" |
| Login | Waxed Flows wordmark in Anton; "Flows." in sky blue; "CONNECT" button filled sky |
| Dashboard | Empty state shows the two-tracks mark at 40% + "No Sessions Yet" — OR season cards with sport rows if data exists |
| Activity List | Filter badges across top; rows use sport glyph + dot; thin rules between rows |
| Activity Detail | Large display distance; meta "KM" label; three-up stats; no `List` chrome |
| Sport Detail | Sport name in sky blue; date-range card; sessions list |
| Tracks | Faint two-tracks watermark behind "TRACKS · COMING · 2026 · SUMMER" |
| Settings | Grouped cards; action rows with left icons; sign out in amber |
| Import Progress (trigger if Polar export available) | % number, sky progress bar, chips with sky/ice/amber status |

- [ ] **Step 3: Verify Anton loaded**

In the Xcode console during launch, there must be no `NoSuch font` warnings. (SwiftUI silently falls back to system; the test added in Task 3 protects against this but double-check manually.)

- [ ] **Step 4: No commit** (no files changed).

---

## Task 22: Grep-based success-criteria audit

**Files:** None modified — this is a verification-only task.

- [ ] **Step 1: Confirm no stray default SwiftUI styling in view code**

Run:
```bash
grep -rn --include="*.swift" \
  -E '(\.foregroundStyle\(\.(red|blue|green|orange|secondary|tertiary)\b)|\.background\(\.bar\b' \
  PolarMyFlow/Features PolarMyFlow/ContentView.swift
```

Expected: zero lines of output.

- [ ] **Step 2: Confirm only the five allow-listed SF Symbols appear**

Run:
```bash
grep -rn --include="*.swift" 'systemName:' \
  PolarMyFlow/Features PolarMyFlow/ContentView.swift PolarMyFlow/Design
```

Expected: every line references one of:
- `checkmark.circle`
- `arrow.triangle.2.circlepath`
- `exclamationmark.triangle`
- `square.and.arrow.down`
- `arrow.down.doc`

No `figure.*`, no `map`, no `list.bullet`, no `chart.bar.fill`, no `gear`, no `dumbbell`.

- [ ] **Step 3: Confirm `symbolName` is gone from SportType and all callers**

Run:
```bash
grep -rn --include="*.swift" 'symbolName' PolarMyFlow
```

Expected: zero output.

- [ ] **Step 4: Confirm the font file is bundled**

```bash
find build -name "Anton-Regular.ttf" -path "*/PolarMyFlow.app/*"
```

Expected: at least one match.

- [ ] **Step 5: If all greps are clean, commit an empty audit marker** (optional)

Skip if you prefer — the success of the audit is recorded in task completion, not a commit.

---

## Self-review notes

- **Spec coverage** — each design-spec section has at least one task:
  - Palette → Task 2
  - Typography → Task 3
  - PolarBackground → Task 4
  - App icon → Task 5
  - Sport icon set + SportType remap → Tasks 6 & 7
  - Card / Badge / Rule → Task 8
  - SportGlyph / PolarEmptyState / PolarActionIcon → Task 9
  - Tab bar → Task 10
  - HR zone bars → Task 11 (documented as not wired — see Known Limitations)
  - Login + MainTabView → Task 12
  - Dashboard + SeasonCard → Task 13
  - SportDetail → Task 14
  - ActivityList + Row → Task 15
  - ActivityDetail → Task 16
  - Tracks placeholder → Task 17
  - Settings → Task 18
  - Import progress → Task 19
  - Success-criteria grep → Task 22

- **Type / API consistency** — `Palette.polarSkyLight`, `SportType.iconName`, `SportType.dotColor`, `Font.displayMedium`, `metaLabel()`, `displayShadow()`, `polarBackground()`, `PolarTab` enum, and the 5 SF Symbol allow-list are referenced identically across all tasks.

- **No placeholders** — each step has exact code, commands, and expected outputs.

---

Plan complete and saved to `docs/superpowers/plans/2026-04-20-waxed-flows-ui-refresh.md`.
