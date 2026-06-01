# Waxed Flows

An iOS app for viewing your Polar training history — seasons, activities, and
speed-coloured GPS tracks — built with SwiftUI.

> Xcode target: `PolarMyFlow` · display name: **Waxed Flows** · iOS 17+

## Features

- **Dashboard** — training grouped by season and sport, with per-sport distance,
  session count, and average pace.
- **Activity log** — a chronological list of activities; tap one for detail
  (distance, duration, pace, heart rate, ascent/descent, calories).
- **Speed-coloured GPS tracks** — for activities with a route, the map draws the
  line coloured by recorded speed: a per-segment glow that blooms hot/bright for
  fast sections and stays tight/cool for slow ones. A scrubber moves a dot along
  the route and shows the real device speed (km/h) at that point. The map
  supports pinch-zoom/pan with a recenter button.
- **Pinch-to-zoom map** with a recenter-to-route control.

## Data sources

The app reads your data two ways:

1. **Polar AccessLink API** — connect your Polar account (OAuth via
   `AuthenticationServices`); recent activities sync automatically, including GPX
   routes.
2. **GDPR data export** — import the ZIP you can download from Polar Flow
   (Account → Export data). This is the source of full history and of the
   per-second `SPEED` samples used to colour tracks by real recorded speed.

Activities are de-duplicated by id and by start-minute, and a GPS route is merged
into an existing record that lacks one (so an AccessLink route can fill in a
GDPR-imported activity, and vice-versa).

## Tech stack

- **SwiftUI** UI, **SwiftData** persistence
- **MapKit** for the track map and the custom speed-glow overlay renderer
- **AuthenticationServices** (OAuth) + **Security** (Keychain token storage)
- **ZIPFoundation** for reading the GDPR export
- Project generated with **[XcodeGen](https://github.com/yonaskolb/XcodeGen)**
  from `project.yml` (the `.xcodeproj` is not committed)

## Project structure

```
PolarMyFlow/
  PolarMyFlowApp.swift        app entry point
  ContentView.swift           auth gate + tab bar (Dash / Log / Tracks / Settings)
  API/                        Polar AccessLink client + GPX parser
  Auth/                       OAuth + Keychain
  Data/                       SwiftData repository
  Import/                     GDPR export import pipeline
  Models/                     Activity, RoutePoint, …
  Features/                   Dashboard, ActivityList, Tracks, Settings
  Design/                     design system (palette, type, components)
PolarMyFlowTests/             XCTest unit tests
project.yml                   XcodeGen project definition
```

## Building & running

Requires Xcode (iOS 17 SDK) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
# generate the Xcode project (re-run after adding/removing source files)
xcodegen generate

# open in Xcode
open PolarMyFlow.xcodeproj

# …or build/test from the command line
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme PolarMyFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

> After adding a new `.swift` file, run `xcodegen generate` before building, or
> the new file is silently excluded from the build.

## Privacy

Your Polar GDPR export contains personal health data. Keep it out of version
control — the repo's `.gitignore` excludes a top-level `/data/` directory for
local exports. All data stays on-device (SwiftData); the app talks only to
Polar's API.
