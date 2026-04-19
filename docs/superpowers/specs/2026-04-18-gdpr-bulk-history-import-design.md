# GDPR Bulk History Import — Design

**Date:** 2026-04-18
**Status:** Approved (design)
**Depends on:** AccessLink client (shipped)

## Problem

AccessLink's `GET /v3/exercises` only returns exercises uploaded to Flow *after* the user registered with our client. Existing Polar users have years of historical data that AccessLink will never surface. We need a one-shot way to backfill that history.

The previously-prototyped approach — scraping `flow.polar.com` with captured cookies — is undocumented, fragile, and ToS-grey. Polar's GDPR data export is sanctioned, stable, and contains the full history.

## Goals

- Let users import their full Polar history into the app.
- Survive Polar API changes (the import path must not depend on undocumented endpoints).
- Coexist cleanly with ongoing AccessLink sync (no duplicates, no corruption).
- Work within iOS sandboxing and App Store review expectations.

## Non-goals

- Daily activity / step / sleep data. The current `Activity` model covers exercise sessions only; daily data is out of scope.
- Re-importing individual sessions via TCX/GPX. The GDPR bulk export is the single path.
- Automated polling for the export to be ready. Delivery is via email on Polar's side; the user brings the zip back to the app.

## User flow

### Moment 1 — requesting the export

1. User opens **Settings → Import full history**.
2. Taps **"Request data export from Polar"**.
3. App opens `https://account.polar.com/` in an in-app browser (`ASWebAuthenticationSession`). User logs in and requests the export on Polar's page. The app does not intercept or interpret any of this.
4. User dismisses the browser. App shows a one-time info sheet:
   > *"Polar will email you a download link within a few hours to a few days. When it arrives, tap the link and choose PolarMyFlow to share the ZIP into the app."*
5. Sheet dismisses on tap. No persistent "awaiting export" state is stored.

### Moment 2 — importing the zip

Two equivalent entry points, both invoking the same `HistoryImporter.import(zipURL:)`:

- **Share Sheet:** User opens the download link from Mail/Safari, taps Share → **PolarMyFlow**. The app is registered in `Info.plist` as a handler for `public.zip-archive`.
- **Document picker:** User taps **"Import from file…"** in Settings, picks the previously-downloaded zip via `.fileImporter`.

Once a URL is received, Settings switches to the progress view.

## Architecture

### New files

| File | Role |
| --- | --- |
| `PolarMyFlow/Import/HistoryImporter.swift` | `@Observable` orchestrator. Public API: `import(zipURL:) async throws`, `cancel()`. Exposes progress counters. |
| `PolarMyFlow/Import/GDPRTrainingSession.swift` | `Decodable` DTO matching Polar's `training-session-*.json` schema, with a `toActivity()` mapper. |
| `PolarMyFlow/Import/ImportError.swift` | `enum`: `invalidArchive`, `wrongFormat`, `cancelled`, `ioFailure(Error)`. |
| `PolarMyFlow/Features/Settings/SettingsView.swift` | New Settings screen. Hosts both import actions and the progress view. |
| `PolarMyFlow/Features/Settings/ImportProgressView.swift` | Inline progress pill component. |
| `PolarMyFlowTests/HistoryImporterTests.swift` | Import pipeline tests using a small fixture zip. |
| `PolarMyFlowTests/GDPRTrainingSessionTests.swift` | JSON-to-Activity mapping tests. |
| `PolarMyFlowTests/Fixtures/test-export.zip` | Curated fixture: 5 valid sessions + 1 malformed + 1 non-session file. |

### Deleted files

- `PolarMyFlow/API/PolarFlowWebClient.swift`
- `PolarMyFlow/API/PolarFlowWebConstants.swift`
- `PolarMyFlowTests/PolarFlowWebClientTests.swift`

Their removal simplifies the sync surface to AccessLink-only.

### External dependency

- **ZIPFoundation** (SwiftPM). First third-party dependency. Rationale: Foundation has no native zip support on iOS; rolling our own is out of scope and error-prone.

### Info.plist additions

- `CFBundleDocumentTypes` → declare acceptance of `public.zip-archive` so the Share Sheet surfaces the app for zip files.
- Add a brief usage string for document access if required by the target iOS SDK.

### App structure change

App gains a Settings tab (currently no such screen exists). The tab bar becomes: Dashboard · Activities · Tracks · **Settings**. Debug settings (`DebugSettingsView`) move under Settings for consistency.

## Import pipeline

```
URL from picker/share →
  HistoryImporter.import(zipURL:) →
    unzip to FileManager.default.temporaryDirectory (ZIPFoundation, streaming) →
    enumerate training-session-*.json →
    decode GDPRTrainingSession →
    map to Activity →
    batch of 100 →
    backgroundContext.insert + save() →
    update @Observable counters (hop to MainActor) →
    repeat until done or cancelled →
    temp dir cleanup in defer
```

### Deduplication

AccessLink IDs (hex strings like `2AC312F`) and GDPR IDs (numeric) don't match, so ID-based dedup doesn't work across sources. Strategy:

- Round `startTime` to the nearest minute.
- At import start, fetch existing activities' rounded start times once into `Set<Date>`.
- For each incoming activity, skip if its rounded start time is already in the set; otherwise insert and add to the set.

Exact-minute collisions between two genuinely different activities are vanishingly rare for one user. Acceptable loss.

`ActivityRepository.save` continues to dedup by ID as a second line of defence for same-source repeat imports.

### Concurrency

- Import runs on a detached `Task`.
- Uses its own background `ModelContext` tied to the shared `ModelContainer`.
- UI reads progress from `@Observable` properties; writes hop to `@MainActor` as needed.
- No explicit locks. SwiftData serializes saves internally; concurrent AccessLink sync and import writes are both safe, and cross-source duplicates are handled by the minute-precision dedup above.

### Progress and cancellation

`HistoryImporter` exposes:

```swift
@Observable final class HistoryImporter {
    var total: Int
    var processed: Int
    var imported: Int
    var skipped: Int
    var failed: Int
    var isRunning: Bool
    var cancelRequested: Bool
    // …
}
```

- `total` is set after unzip + enumeration.
- Loop checks `cancelRequested` between files.
- Already-committed batches persist after cancellation — no rollback.

### Error handling

| Condition | Behaviour | UI |
| --- | --- | --- |
| Zip won't open | `throw ImportError.invalidArchive` | Toast: "Not a valid Polar export." |
| No `training-session-*.json` found | `throw ImportError.wrongFormat` | Toast: "This doesn't look like a Polar data export." |
| Individual file fails decode/map | Increment `failed`, log in DEBUG, continue | Final summary: "Imported *X* activities. *Y* files couldn't be read." |
| User cancels | `throw ImportError.cancelled` after loop exits | Summary: "Import cancelled. Kept *X* activities." |
| Low disk / IO | `throw ImportError.ioFailure(underlying)` | Toast: "Import failed: <localizedDescription>." |

## Testing

- `HistoryImporterTests`
  - `test_importsValidSessions_fromFixture`
  - `test_malformedFilesCountedAsFailed_restContinue`
  - `test_nonSessionFilesIgnored`
  - `test_dedupAgainstPrepopulatedDB_skipsMinuteMatches`
  - `test_cancellationCommitsPartialProgress`
  - `test_invalidZipThrowsInvalidArchive`
  - `test_zipWithNoSessionsThrowsWrongFormat`
- `GDPRTrainingSessionTests`
  - Missing distance, missing heart rate
  - Sport ID mapping via existing `SportType.from(polarSportId:)`
  - Duration-unit edge cases (milliseconds vs seconds in source schema — verify before implementation)
- No UI tests for `.fileImporter` / Share Sheet. Those are system components.

## Open items for implementation

- Confirm Polar's GDPR export schema. The DTO design assumes JSON structure based on current observation; implementation should verify against an actual export and adjust.
- Confirm whether the GDPR zip is flat or nested (sub-directories per year/month). Enumeration uses a recursive walk to be safe either way.
- Confirm Polar's current export-request URL. `https://account.polar.com/` is the starting point; deeper link may change.

## Risks

- **Polar changes the export schema.** Because this is a one-shot import we can adapt without blocking sync. DTOs are isolated to one file.
- **Very large exports.** Streaming unzip + batched inserts should keep memory bounded, but real-world testing on a multi-year export is required before release.
- **User re-imports same zip.** Dedup covers this. Repeat imports are idempotent.
