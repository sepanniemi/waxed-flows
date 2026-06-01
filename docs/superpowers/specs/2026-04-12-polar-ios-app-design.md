# Polar MyFlow — iOS App Design Spec

**Date:** 2026-04-12
**Status:** Approved

## Overview

A personal native iOS app (Swift/SwiftUI) that connects to Polar's training data to show seasonal training summaries by sport, with drill-down into individual activities. Built for a single user — no backend, no App Store distribution requirement.

Core v1 feature: training statistics by sport (distance, pace, session count, heart rate, elevation).
Placeholder screens for map view and GPX export (v2).

---

## Architecture

Three layers, no backend:

### 1. Auth Layer
- OAuth 2.0 via `ASWebAuthenticationSession` (Apple's in-app browser)
- Custom URL scheme redirect: `polarflow://auth`
  - Requires updating registered redirect URI in Polar API client from `https://localhost:8080/auth/polar-authorisations` to `polarflow://auth`
- Access token + refresh token stored in iOS Keychain (never in SwiftData)

### 2. Data Layer
- `PolarFlowWebClient` — calls the internal `flow.polar.com` API for historical data import and (in v2) map/GPX data. Endpoints to be discovered by inspecting flow.polar.com network traffic. Documented in code as internal/may change.
- `PolarAccessLinkClient` — uses the official AccessLink API (client ID: `c045142a-470a-4d0c-8f44-b8aa1200e975`) for ongoing activity sync via transaction-based pull.
- `SyncCoordinator` — orchestrates both clients, handles first-launch vs. subsequent launches, deduplicates by activity ID.
- `ActivityRepository` — single SwiftData-backed store that both clients write to. The UI never calls the network directly.
- `SwiftData` — local persistence for offline access and fast filtering.

### 3. Presentation Layer
- SwiftUI views driven by `@Observable` ViewModels
- No third-party dependencies

---

## Navigation Structure

Tab bar with three tabs:

| Tab | Name | v1 Status |
|-----|------|-----------|
| 1 | Dashboard | Functional |
| 2 | Activity List | Functional |
| 3 | Tracks | Placeholder |

### Dashboard Tab
- Seasonal summary cards: one card per detected season (e.g., "Winter 2024–25")
- Each card shows a per-sport breakdown: for each sport logged that season, display total distance, session count, and avg pace
- Seasons are predefined: Winter (Nov–Apr), Summer (May–Sep); labelled with year
- Tap a sport row within a season card → Sport detail screen with adjustable date range picker
- Sport detail → Individual activity detail

### Activity List Tab
- Chronological list of all activities
- Filterable by sport type; sport filter options are populated dynamically from sports present in the local database (no hardcoded list)
- Tap an activity → Activity detail screen (shared with Dashboard drill-down)

### Tracks Tab (placeholder)
- "Coming soon" screen
- Map and GPX export icons shown greyed out

---

## Data Model

### SwiftData Entities

**Activity**
```
id: String              // Polar activity ID (deduplication key)
startTime: Date
duration: TimeInterval
distance: Double        // metres
sport: SportType        // local enum
avgSpeed: Double        // m/s
avgPace: Double         // s/m
avgHeartRate: Int?
maxHeartRate: Int?
ascent: Double?         // metres
descent: Double?        // metres
calories: Int?
hasRoute: Bool          // flag for future map/GPX availability
```

**SyncState**
```
lastSyncedAt: Date?
userID: String
accessLinkRegistered: Bool
historicalImportComplete: Bool
```

**AuthToken** (Keychain only, not SwiftData)
```
accessToken: String
refreshToken: String
expiresAt: Date
```

### SportType Enum
Maps Polar sport type strings (e.g., `"CROSS_COUNTRY_SKIING"`) to a local typed enum with display names and SF Symbol icons. Unknown types fall back to `.other`.

### Season
Not a stored entity — computed from activity dates. Two predefined seasons:
- Winter: November–April (spans two calendar years, e.g., "Winter 2024–25")
- Summer: May–October

Seasons are derived on the fly for the Dashboard view. Only seasons that contain at least one activity are shown.

---

## API Integration

### First Launch Flow
1. User taps "Connect with Polar" → `ASWebAuthenticationSession` opens Polar OAuth
2. Polar redirects to `polarflow://auth?code=...`
3. App exchanges code for access token → stored in Keychain
4. `PolarFlowWebClient` performs one-time historical import (all past activities)
   - Progress shown: "Importing your training history... (N activities)"
5. `PolarAccessLinkClient` registers user with AccessLink (`POST /v3/users`)
6. `SyncCoordinator` marks `historicalImportComplete = true`, `accessLinkRegistered = true`

### Subsequent Launch Flow
1. `PolarAccessLinkClient` fetches new activities via AccessLink transaction (`GET /v3/exercises`)
2. Fetches detail for each new exercise (metrics, heart rate, elevation)
3. Commits transaction after successful fetch
4. `ActivityRepository` deduplicates by activity ID before writing to SwiftData

### AccessLink Transaction Model
- Transactions must be committed after fetching; uncommitted transactions replay on next launch (safe retry, no data loss)
- Token refresh handled automatically; re-login prompt shown if refresh token is revoked

---

## Error Handling

| Scenario | Handling |
|----------|----------|
| Auth token expired | Auto-refresh; re-login prompt if refresh fails |
| No network | App works offline from SwiftData cache; sync status shows last sync time + manual refresh button |
| Historical import in progress | Progress indicator: "Importing your training history... (N activities)" |
| AccessLink transaction mid-failure | Not committed → retried next launch, no data loss |
| Unknown Polar sport type | Mapped to `.other` category, never dropped or crashed |
| Flow web API changes | Graceful error with message "Unable to import history — Polar may have updated their API" |

---

## Testing Strategy

Pragmatic coverage for a personal tool:

**Unit tests**
- `SyncCoordinator`: deduplication logic, first-launch vs. subsequent-launch branching, season boundary calculation
- `SportType` mapping: known types map correctly, unknown types fall back to `.other`
- Date range filtering logic

**API client tests**
- Mock `URLSession` responses to verify correct parsing of AccessLink and Flow web API JSON responses
- No live network calls in tests

**UI tests**
- None for v1 — SwiftUI Previews serve as visual sanity checks

---

## Out of Scope for v1

- Map view of tracks (placeholder only)
- GPX export (placeholder only)
- Multiple Polar accounts
- App Store distribution
- Push notifications / background sync
- watchOS / macOS companion apps

---

## Polar API Client Credentials

- **Client ID:** `c045142a-470a-4d0c-8f44-b8aa1200e975`
- **Client Secret:** `59ccbd6e-aaae-4881-b121-a3b7774ff03b`
- **Redirect URI:** `polarflow://auth` (already registered in Polar API client settings)
- **AccessLink API docs:** https://www.polar.com/accesslink-api/
