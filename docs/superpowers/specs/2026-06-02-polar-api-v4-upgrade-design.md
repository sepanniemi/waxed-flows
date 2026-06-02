# Polar API v4 Upgrade — Design

**Date:** 2026-06-02
**Branch:** TBD (separate branch from `waxed-flows-refresh`)
**Status:** Stub — brainstorm not yet started
**Scope:** Replace `PolarAccessLinkClient` (v3 `/v3/exercises` GPX path) with Polar
Dynamic AccessLink v4 (`auth.polar.com`, `/training-sessions`). Adds real per-point
speed to AccessLink-synced routes.

## Why

- v3 GPX has no documented per-point speed field; AccessLink routes render flat amber.
- v4 exposes `trainingsessionSamples` with a `SPEED` sample series (same shape as the
  GDPR import the app already handles) and `routePoints` with `timeOffsetFromStartMillis`
  for time-alignment — the existing aligner can be reused.
- v4 uses a modern OAuth2 flow on `auth.polar.com` with 12 h tokens + refresh token
  (v3 used a one-time registration flow with no refresh).

## Known facts (from API spec research, 2026-06-02)

- Auth base: `https://auth.polar.com`; data base: `https://www.polaraccesslink.com/v4/data`
- Scope: `training_sessions:read`
- Sessions list: `GET /training-sessions?from=&to=`
- Session detail: `GET /training-sessions/{id}` — embeds `samples[]` and `routePoints[]`
- Route waypoints: `{ location: {longitude, latitude, altitudeMeters}, timeOffsetFromStartMillis }`
- Samples shape: `{ type: "SPEED"|"HEART_RATE"|..., intervalMillis, values: [Double] }`
- **SPEED units: km/h** (confirmed from v4 spec; same as GDPR SPEED series)

## Open items before brainstorm

- Exact `sample-type` → enum name mapping (need a live v4 response or official enum table)
- OAuth2 redirect_uri requirement for mobile (PKCE / custom scheme)
- Whether v3 and v4 exercise IDs are the same (dedup strategy for existing records)
- Whether v3 `PolarAccessLinkClient` should be kept as a fallback or removed

## Relationship to map view usability plan

The map view usability plan (`2026-06-02-map-view-usability.md`) is fully independent —
it makes the render layer source-agnostic. Once this v4 upgrade populates real
`speedKmh` for AccessLink routes, they will automatically get neon coloring with no
further render-layer changes.
