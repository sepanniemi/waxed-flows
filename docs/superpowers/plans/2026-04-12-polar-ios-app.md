# Polar MyFlow iOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI iOS app displaying Polar training history by season and sport, syncing new activities via AccessLink and importing history via the Polar Flow web API.

**Architecture:** SwiftUI frontend with @Observable ViewModels; SwiftData for local persistence; two API clients (PolarAccessLinkClient for ongoing sync, PolarFlowWebClient for historical import) coordinated by SyncCoordinator; OAuth 2.0 via ASWebAuthenticationSession with tokens in Keychain. No backend, no third-party dependencies.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, XCTest, ASWebAuthenticationSession, Security framework (Keychain), URLSession

---

## File Structure

```
PolarMyFlow/
├── PolarMyFlowApp.swift                      # App entry point; SwiftData container; sync on launch
├── ContentView.swift                         # Root TabView: Dashboard / Activities / Tracks
│
├── Models/
│   ├── SportType.swift                       # Enum mapping Polar sport strings → typed cases + display
│   ├── Season.swift                          # Season enum + date range logic (not stored)
│   ├── Activity.swift                        # SwiftData @Model for a training session
│   └── SyncState.swift                       # SwiftData @Model for sync metadata
│
├── Auth/
│   ├── AuthToken.swift                       # Codable value type: tokens + expiry
│   ├── TokenStore.swift                      # Protocol: save/load/delete AuthToken
│   ├── KeychainStore.swift                   # TokenStore impl using Security framework
│   └── AuthManager.swift                     # OAuth flow via ASWebAuthenticationSession; token refresh
│
├── API/
│   ├── APIError.swift                        # Shared error enum for both API clients
│   ├── PolarAccessLinkClient.swift           # AccessLink: register user, transaction pull, commit
│   └── PolarFlowWebClient.swift              # flow.polar.com internal API: historical activity import
│
├── Data/
│   ├── ActivityRepository.swift             # SwiftData queries/writes; deduplication by id
│   └── SyncCoordinator.swift                # First-launch vs. subsequent-launch orchestration
│
└── Features/
    ├── Dashboard/
    │   ├── DashboardViewModel.swift          # Loads seasons + sport summaries from repository
    │   ├── DashboardView.swift               # Season cards list
    │   ├── SeasonCardView.swift              # One card: season name + per-sport rows
    │   ├── SportDetailViewModel.swift        # Filters activities by sport + date range
    │   └── SportDetailView.swift             # Date range picker + activity list for one sport
    ├── ActivityList/
    │   ├── ActivityListViewModel.swift       # All activities; available sports for filter
    │   ├── ActivityListView.swift            # Chronological list + sport filter picker
    │   ├── ActivityDetailViewModel.swift     # Formats single activity for display
    │   └── ActivityDetailView.swift          # Full metrics for one activity
    └── Tracks/
        └── TracksPlaceholderView.swift       # "Coming soon" with greyed map/GPX icons

PolarMyFlowTests/
├── Helpers/
│   ├── MockURLProtocol.swift                 # URLProtocol subclass for mocking network
│   └── TestHelpers.swift                     # makeTestContext(), InMemoryTokenStore
├── SportTypeTests.swift
├── SeasonTests.swift
├── ActivityRepositoryTests.swift
├── PolarAccessLinkClientTests.swift
├── PolarFlowWebClientTests.swift
└── SyncCoordinatorTests.swift
```

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `PolarMyFlow/` (Xcode project)
- Create: `.gitignore`

- [ ] **Step 1: Create the Xcode project**

  In Xcode: File → New → Project → iOS → App
  - Product Name: `PolarMyFlow`
  - Team: your personal team (or "None" for simulator-only)
  - Bundle Identifier: `com.personal.polarmyflow`
  - Interface: SwiftUI
  - Language: Swift
  - Storage: **SwiftData** (check this box)
  - Include Tests: ✓

  Save to `/Users/sepanniemi/codes/polar-myflow/`

- [ ] **Step 2: Set deployment target to iOS 17.0**

  In Xcode: Click the project root → select the `PolarMyFlow` target → General → Minimum Deployments → iOS 17.0

- [ ] **Step 3: Register the custom URL scheme**

  In Xcode: Select the `PolarMyFlow` target → Info tab → URL Types → click `+`
  - URL Schemes: `polarflow`
  - Identifier: `com.personal.polarmyflow`

- [ ] **Step 4: Create the folder structure**

  In Xcode's file navigator, create groups (not folders — right-click → New Group):
  `Models`, `Auth`, `API`, `Data`, `Features/Dashboard`, `Features/ActivityList`, `Features/Tracks`

  In the test target, create group: `Helpers`

- [ ] **Step 5: Delete the Xcode-generated boilerplate**

  Delete `Item.swift` (Xcode generates this for SwiftData projects — we'll create our own models).
  Keep `ContentView.swift` and `PolarMyFlowApp.swift` but clear their contents.

- [ ] **Step 6: Create .gitignore**

  At the project root (`/Users/sepanniemi/codes/polar-myflow/`), create `.gitignore`:

  ```
  # Xcode
  .DS_Store
  build/
  *.xcuserdata/
  xcuserdata/
  *.xcworkspace/workspace.xcshareddata/swpm/
  DerivedData/
  *.moved-aside
  *.pbxuser
  !default.pbxuser
  *.mode1v3
  !default.mode1v3
  *.mode2v3
  !default.mode2v3
  *.perspectivev3
  !default.perspectivev3
  *.xccheckout
  *.xcscmblueprint

  # Superpowers visual companion
  .superpowers/
  ```

- [ ] **Step 7: Initialise git and make first commit**

  ```bash
  cd /Users/sepanniemi/codes/polar-myflow
  git init
  git add PolarMyFlow.xcodeproj PolarMyFlow/ PolarMyFlowTests/ .gitignore
  git commit -m "chore: initial Xcode project scaffold"
  ```

---

## Task 2: SportType Enum

**Files:**
- Create: `PolarMyFlow/Models/SportType.swift`
- Create: `PolarMyFlowTests/SportTypeTests.swift`

- [ ] **Step 1: Write the failing test**

  Create `PolarMyFlowTests/SportTypeTests.swift`:

  ```swift
  import XCTest
  @testable import PolarMyFlow

  final class SportTypeTests: XCTestCase {

      func test_knownSport_xcSkiing() {
          XCTAssertEqual(SportType(polarString: "CROSS_COUNTRY_SKIING"), .xcSkiing)
      }

      func test_knownSport_running() {
          XCTAssertEqual(SportType(polarString: "RUNNING"), .running)
      }

      func test_knownSport_cycling() {
          XCTAssertEqual(SportType(polarString: "CYCLING"), .cycling)
      }

      func test_knownSport_swimming() {
          XCTAssertEqual(SportType(polarString: "SWIMMING"), .swimming)
      }

      func test_unknownSport_fallsBackToOther() {
          XCTAssertEqual(SportType(polarString: "UNDERWATER_HOCKEY"), .other)
          XCTAssertEqual(SportType(polarString: ""), .other)
      }

      func test_displayName_xcSkiing() {
          XCTAssertEqual(SportType.xcSkiing.displayName, "XC Skiing")
      }

      func test_symbolName_xcSkiing() {
          XCTAssertEqual(SportType.xcSkiing.symbolName, "figure.skiing.crosscountry")
      }

      func test_symbolName_other_isValid() {
          // Ensures all cases have a non-empty symbol name
          for sport in SportType.allCases {
              XCTAssertFalse(sport.symbolName.isEmpty, "\(sport) has empty symbolName")
          }
      }
  }
  ```

- [ ] **Step 2: Run the test to confirm it fails**

  In Xcode: Cmd+U. Expected: compile error — `SportType` not defined. That's correct.

- [ ] **Step 3: Implement SportType**

  Create `PolarMyFlow/Models/SportType.swift`:

  ```swift
  enum SportType: String, Codable, CaseIterable, Equatable {
      case xcSkiing    = "CROSS_COUNTRY_SKIING"
      case running     = "RUNNING"
      case cycling     = "CYCLING"
      case swimming    = "SWIMMING"
      case hiking      = "HIKING"
      case strength    = "STRENGTH_TRAINING"
      case rowing      = "ROWING"
      case other       = "OTHER"

      init(polarString: String) {
          self = SportType(rawValue: polarString) ?? .other
      }

      var displayName: String {
          switch self {
          case .xcSkiing:  return "XC Skiing"
          case .running:   return "Running"
          case .cycling:   return "Cycling"
          case .swimming:  return "Swimming"
          case .hiking:    return "Hiking"
          case .strength:  return "Strength"
          case .rowing:    return "Rowing"
          case .other:     return "Other"
          }
      }

      var symbolName: String {
          switch self {
          case .xcSkiing:  return "figure.skiing.crosscountry"
          case .running:   return "figure.run"
          case .cycling:   return "figure.outdoor.cycle"
          case .swimming:  return "figure.pool.swim"
          case .hiking:    return "figure.hiking"
          case .strength:  return "dumbbell"
          case .rowing:    return "figure.rowing"
          case .other:     return "figure.mixed.cardio"
          }
      }
  }
  ```

- [ ] **Step 4: Run the tests and verify they pass**

  Cmd+U. Expected: all `SportTypeTests` pass.

- [ ] **Step 5: Commit**

  ```bash
  git add PolarMyFlow/Models/SportType.swift PolarMyFlowTests/SportTypeTests.swift
  git commit -m "feat: add SportType enum with Polar string mapping"
  ```

---

## Task 3: Season Logic

**Files:**
- Create: `PolarMyFlow/Models/Season.swift`
- Create: `PolarMyFlowTests/SeasonTests.swift`

- [ ] **Step 1: Write the failing test**

  Create `PolarMyFlowTests/SeasonTests.swift`:

  ```swift
  import XCTest
  @testable import PolarMyFlow

  final class SeasonTests: XCTestCase {
      private let cal = Calendar(identifier: .gregorian)

      private func date(year: Int, month: Int, day: Int = 1) -> Date {
          cal.date(from: DateComponents(year: year, month: month, day: day))!
      }

      // Season classification
      func test_november_isWinter() {
          XCTAssertEqual(Season.containing(date(year: 2024, month: 11)), .winter(startYear: 2024))
      }

      func test_january_isWinter() {
          XCTAssertEqual(Season.containing(date(year: 2025, month: 1)), .winter(startYear: 2024))
      }

      func test_april_isWinter() {
          XCTAssertEqual(Season.containing(date(year: 2025, month: 4)), .winter(startYear: 2024))
      }

      func test_may_isSummer() {
          XCTAssertEqual(Season.containing(date(year: 2025, month: 5)), .summer(year: 2025))
      }

      func test_october_isSummer() {
          XCTAssertEqual(Season.containing(date(year: 2024, month: 10)), .summer(year: 2024))
      }

      // Labels
      func test_winterLabel() {
          XCTAssertEqual(Season.winter(startYear: 2024).label, "Winter 2024–25")
      }

      func test_summerLabel() {
          XCTAssertEqual(Season.summer(year: 2025).label, "Summer 2025")
      }

      // Date range
      func test_winterDateRange_2024() {
          let season = Season.winter(startYear: 2024)
          let range = season.dateRange
          XCTAssertEqual(cal.component(.month, from: range.lowerBound), 11)
          XCTAssertEqual(cal.component(.year, from: range.lowerBound), 2024)
          XCTAssertEqual(cal.component(.month, from: range.upperBound), 4)
          XCTAssertEqual(cal.component(.year, from: range.upperBound), 2025)
      }

      func test_summerDateRange_2024() {
          let season = Season.summer(year: 2024)
          let range = season.dateRange
          XCTAssertEqual(cal.component(.month, from: range.lowerBound), 5)
          XCTAssertEqual(cal.component(.month, from: range.upperBound), 10)
          XCTAssertEqual(cal.component(.year, from: range.lowerBound), 2024)
      }

      // Sorting
      func test_olderSeasonSortsFirst() {
          let w2023 = Season.winter(startYear: 2023)
          let w2024 = Season.winter(startYear: 2024)
          XCTAssertLessThan(w2023, w2024)
      }
  }
  ```

- [ ] **Step 2: Run test to confirm it fails**

  Cmd+U. Expected: compile error — `Season` not defined.

- [ ] **Step 3: Implement Season**

  Create `PolarMyFlow/Models/Season.swift`:

  ```swift
  import Foundation

  enum Season: Equatable, Comparable, Hashable {
      case winter(startYear: Int)  // Nov startYear – Apr (startYear+1)
      case summer(year: Int)       // May – Oct year

      // Returns the Season containing a given date
      static func containing(_ date: Date) -> Season {
          var cal = Calendar(identifier: .gregorian)
          cal.timeZone = TimeZone(identifier: "UTC")!
          let month = cal.component(.month, from: date)
          let year  = cal.component(.year,  from: date)

          // Winter: Nov (11), Dec (12) → startYear = current year
          //         Jan (1) – Apr (4) → startYear = year - 1
          switch month {
          case 11, 12: return .winter(startYear: year)
          case 1...4:  return .winter(startYear: year - 1)
          default:     return .summer(year: year)  // May–Oct
          }
      }

      var label: String {
          switch self {
          case .winter(let y): return "Winter \(y)–\(String(y + 1).suffix(2))"
          case .summer(let y): return "Summer \(y)"
          }
      }

      // Half-open date range [start, endExclusive)
      var dateRange: Range<Date> {
          var cal = Calendar(identifier: .gregorian)
          cal.timeZone = TimeZone(identifier: "UTC")!
          switch self {
          case .winter(let startYear):
              let start = cal.date(from: DateComponents(year: startYear, month: 11, day: 1))!
              let end   = cal.date(from: DateComponents(year: startYear + 1, month: 5, day: 1))!
              return start..<end
          case .summer(let year):
              let start = cal.date(from: DateComponents(year: year, month: 5, day: 1))!
              let end   = cal.date(from: DateComponents(year: year, month: 11, day: 1))!
              return start..<end
          }
      }

      // Comparable: sort by the start of the date range
      static func < (lhs: Season, rhs: Season) -> Bool {
          lhs.dateRange.lowerBound < rhs.dateRange.lowerBound
      }
  }
  ```

- [ ] **Step 4: Run tests and verify they pass**

  Cmd+U. Expected: all `SeasonTests` pass.

- [ ] **Step 5: Commit**

  ```bash
  git add PolarMyFlow/Models/Season.swift PolarMyFlowTests/SeasonTests.swift
  git commit -m "feat: add Season enum with Winter/Summer classification and date ranges"
  ```

---

## Task 4: SwiftData Models

**Files:**
- Create: `PolarMyFlow/Models/Activity.swift`
- Create: `PolarMyFlow/Models/SyncState.swift`

No unit tests for model schemas — behaviour is tested through ActivityRepository in Task 5.

- [ ] **Step 1: Create Activity model**

  Create `PolarMyFlow/Models/Activity.swift`:

  ```swift
  import Foundation
  import SwiftData

  @Model
  final class Activity {
      @Attribute(.unique) var id: String
      var startTime: Date
      var duration: TimeInterval      // seconds
      var distance: Double            // metres
      var sportRawValue: String       // Polar sport string e.g. "CROSS_COUNTRY_SKIING"
      var avgSpeed: Double            // m/s
      var avgPace: Double             // s/m (seconds per metre; display as min/km)
      var avgHeartRate: Int?
      var maxHeartRate: Int?
      var ascent: Double?             // metres gained
      var descent: Double?            // metres lost
      var calories: Int?
      var hasRoute: Bool

      var sportType: SportType { SportType(polarString: sportRawValue) }

      init(
          id: String,
          startTime: Date,
          duration: TimeInterval,
          distance: Double,
          sportRawValue: String,
          avgSpeed: Double,
          avgPace: Double,
          avgHeartRate: Int? = nil,
          maxHeartRate: Int? = nil,
          ascent: Double? = nil,
          descent: Double? = nil,
          calories: Int? = nil,
          hasRoute: Bool = false
      ) {
          self.id = id
          self.startTime = startTime
          self.duration = duration
          self.distance = distance
          self.sportRawValue = sportRawValue
          self.avgSpeed = avgSpeed
          self.avgPace = avgPace
          self.avgHeartRate = avgHeartRate
          self.maxHeartRate = maxHeartRate
          self.ascent = ascent
          self.descent = descent
          self.calories = calories
          self.hasRoute = hasRoute
      }
  }
  ```

- [ ] **Step 2: Create SyncState model**

  Create `PolarMyFlow/Models/SyncState.swift`:

  ```swift
  import Foundation
  import SwiftData

  @Model
  final class SyncState {
      var userID: String
      var lastSyncedAt: Date?
      var accessLinkRegistered: Bool
      var historicalImportComplete: Bool

      init(userID: String) {
          self.userID = userID
          self.lastSyncedAt = nil
          self.accessLinkRegistered = false
          self.historicalImportComplete = false
      }
  }
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add PolarMyFlow/Models/Activity.swift PolarMyFlow/Models/SyncState.swift
  git commit -m "feat: add Activity and SyncState SwiftData models"
  ```

---

## Task 5: Test Helpers + ActivityRepository

**Files:**
- Create: `PolarMyFlowTests/Helpers/TestHelpers.swift`
- Create: `PolarMyFlow/Data/ActivityRepository.swift`
- Create: `PolarMyFlowTests/ActivityRepositoryTests.swift`

- [ ] **Step 1: Create test helpers**

  Create `PolarMyFlowTests/Helpers/TestHelpers.swift`:

  ```swift
  import Foundation
  import SwiftData
  @testable import PolarMyFlow

  func makeTestContext() throws -> ModelContext {
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(
          for: Activity.self, SyncState.self,
          configurations: config
      )
      return ModelContext(container)
  }

  func makeActivity(
      id: String = "act-1",
      startTime: Date = Date(),
      duration: TimeInterval = 3600,
      distance: Double = 10000,
      sport: String = "RUNNING",
      avgSpeed: Double = 2.78,
      avgPace: Double = 0.36
  ) -> Activity {
      Activity(
          id: id,
          startTime: startTime,
          duration: duration,
          distance: distance,
          sportRawValue: sport,
          avgSpeed: avgSpeed,
          avgPace: avgPace
      )
  }
  ```

- [ ] **Step 2: Write the failing tests**

  Create `PolarMyFlowTests/ActivityRepositoryTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import PolarMyFlow

  final class ActivityRepositoryTests: XCTestCase {
      var context: ModelContext!
      var repo: ActivityRepository!

      override func setUpWithError() throws {
          context = try makeTestContext()
          repo = ActivityRepository(context: context)
      }

      func test_save_insertsActivity() throws {
          let act = makeActivity(id: "a1")
          try repo.save(act)
          let all = try repo.fetchAll()
          XCTAssertEqual(all.count, 1)
          XCTAssertEqual(all.first?.id, "a1")
      }

      func test_save_deduplicatesByID() throws {
          let act1 = makeActivity(id: "a1", distance: 5000)
          let act2 = makeActivity(id: "a1", distance: 9000)
          try repo.save(act1)
          try repo.save(act2)  // same id — should not insert again
          let all = try repo.fetchAll()
          XCTAssertEqual(all.count, 1)
          XCTAssertEqual(all.first?.distance, 5000)  // original preserved
      }

      func test_fetchBySport_filtersCorrectly() throws {
          try repo.save(makeActivity(id: "r1", sport: "RUNNING"))
          try repo.save(makeActivity(id: "s1", sport: "CROSS_COUNTRY_SKIING"))
          let runners = try repo.fetch(sport: .running)
          XCTAssertEqual(runners.count, 1)
          XCTAssertEqual(runners.first?.id, "r1")
      }

      func test_fetchByDateRange_filtersCorrectly() throws {
          var cal = Calendar(identifier: .gregorian)
          cal.timeZone = TimeZone(identifier: "UTC")!
          let jan = cal.date(from: DateComponents(year: 2025, month: 1, day: 15))!
          let mar = cal.date(from: DateComponents(year: 2025, month: 3, day: 15))!
          let jun = cal.date(from: DateComponents(year: 2025, month: 6, day: 15))!

          try repo.save(makeActivity(id: "jan", startTime: jan))
          try repo.save(makeActivity(id: "mar", startTime: mar))
          try repo.save(makeActivity(id: "jun", startTime: jun))

          let winterRange = Season.winter(startYear: 2024).dateRange
          let winterActs = try repo.fetch(in: winterRange)
          XCTAssertEqual(winterActs.count, 2)
          XCTAssertTrue(winterActs.map(\.id).contains("jan"))
          XCTAssertTrue(winterActs.map(\.id).contains("mar"))
      }

      func test_availableSports_returnsOnlySportsWithActivities() throws {
          try repo.save(makeActivity(id: "r1", sport: "RUNNING"))
          try repo.save(makeActivity(id: "r2", sport: "RUNNING"))
          try repo.save(makeActivity(id: "s1", sport: "CROSS_COUNTRY_SKIING"))
          let sports = try repo.availableSports()
          XCTAssertEqual(Set(sports), [.running, .xcSkiing])
      }

      func test_syncState_createdIfAbsent() throws {
          let state = try repo.syncState(forUserID: "user-1")
          XCTAssertEqual(state.userID, "user-1")
          XCTAssertFalse(state.accessLinkRegistered)
          XCTAssertFalse(state.historicalImportComplete)
      }

      func test_syncState_returnsSameInstance() throws {
          let s1 = try repo.syncState(forUserID: "user-1")
          s1.accessLinkRegistered = true
          try context.save()
          let s2 = try repo.syncState(forUserID: "user-1")
          XCTAssertTrue(s2.accessLinkRegistered)
      }
  }
  ```

- [ ] **Step 3: Run tests to confirm they fail**

  Cmd+U. Expected: compile error — `ActivityRepository` not defined.

- [ ] **Step 4: Implement ActivityRepository**

  Create `PolarMyFlow/Data/ActivityRepository.swift`:

  ```swift
  import Foundation
  import SwiftData

  final class ActivityRepository {
      private let context: ModelContext

      init(context: ModelContext) {
          self.context = context
      }

      // Insert only if ID not already present
      func save(_ activity: Activity) throws {
          let id = activity.id
          let descriptor = FetchDescriptor<Activity>(
              predicate: #Predicate { $0.id == id }
          )
          let existing = try context.fetch(descriptor)
          guard existing.isEmpty else { return }
          context.insert(activity)
          try context.save()
      }

      func fetchAll() throws -> [Activity] {
          let descriptor = FetchDescriptor<Activity>(
              sortBy: [SortDescriptor(\.startTime, order: .reverse)]
          )
          return try context.fetch(descriptor)
      }

      func fetch(sport: SportType) throws -> [Activity] {
          let raw = sport.rawValue
          let descriptor = FetchDescriptor<Activity>(
              predicate: #Predicate { $0.sportRawValue == raw },
              sortBy: [SortDescriptor(\.startTime, order: .reverse)]
          )
          return try context.fetch(descriptor)
      }

      func fetch(in range: Range<Date>) throws -> [Activity] {
          let start = range.lowerBound
          let end   = range.upperBound
          let descriptor = FetchDescriptor<Activity>(
              predicate: #Predicate { $0.startTime >= start && $0.startTime < end },
              sortBy: [SortDescriptor(\.startTime, order: .reverse)]
          )
          return try context.fetch(descriptor)
      }

      func fetch(sport: SportType, in range: Range<Date>) throws -> [Activity] {
          let raw   = sport.rawValue
          let start = range.lowerBound
          let end   = range.upperBound
          let descriptor = FetchDescriptor<Activity>(
              predicate: #Predicate {
                  $0.sportRawValue == raw &&
                  $0.startTime >= start &&
                  $0.startTime < end
              },
              sortBy: [SortDescriptor(\.startTime, order: .reverse)]
          )
          return try context.fetch(descriptor)
      }

      func availableSports() throws -> [SportType] {
          let all = try fetchAll()
          let unique = Set(all.map { SportType(polarString: $0.sportRawValue) })
          return unique.sorted { $0.displayName < $1.displayName }
      }

      // Returns existing SyncState for user, or creates and saves a new one
      func syncState(forUserID userID: String) throws -> SyncState {
          let descriptor = FetchDescriptor<SyncState>(
              predicate: #Predicate { $0.userID == userID }
          )
          if let existing = try context.fetch(descriptor).first {
              return existing
          }
          let state = SyncState(userID: userID)
          context.insert(state)
          try context.save()
          return state
      }

      func saveSyncState() throws {
          try context.save()
      }
  }
  ```

- [ ] **Step 5: Run tests and verify they pass**

  Cmd+U. Expected: all `ActivityRepositoryTests` pass.

- [ ] **Step 6: Commit**

  ```bash
  git add PolarMyFlowTests/Helpers/TestHelpers.swift \
          PolarMyFlow/Data/ActivityRepository.swift \
          PolarMyFlowTests/ActivityRepositoryTests.swift
  git commit -m "feat: add ActivityRepository with SwiftData persistence and deduplication"
  ```

---

## Task 6: AuthToken + TokenStore Protocol + KeychainStore

**Files:**
- Create: `PolarMyFlow/Auth/AuthToken.swift`
- Create: `PolarMyFlow/Auth/TokenStore.swift`
- Create: `PolarMyFlow/Auth/KeychainStore.swift`
- Modify: `PolarMyFlowTests/Helpers/TestHelpers.swift` — add `InMemoryTokenStore`

- [ ] **Step 1: Create AuthToken**

  Create `PolarMyFlow/Auth/AuthToken.swift`:

  ```swift
  import Foundation

  struct AuthToken: Codable, Equatable {
      let accessToken: String
      let refreshToken: String
      let expiresAt: Date

      var isExpired: Bool { expiresAt <= Date() }

      // expiresIn: seconds until expiry, as returned by Polar token endpoint
      init(accessToken: String, refreshToken: String, expiresIn: Int) {
          self.accessToken = accessToken
          self.refreshToken = refreshToken
          self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
      }
  }
  ```

- [ ] **Step 2: Create TokenStore protocol**

  Create `PolarMyFlow/Auth/TokenStore.swift`:

  ```swift
  protocol TokenStore {
      func save(_ token: AuthToken) throws
      func load() throws -> AuthToken?
      func delete() throws
  }
  ```

- [ ] **Step 3: Add InMemoryTokenStore to test helpers**

  Append to `PolarMyFlowTests/Helpers/TestHelpers.swift`:

  ```swift
  class InMemoryTokenStore: TokenStore {
      private var stored: AuthToken?

      func save(_ token: AuthToken) throws { stored = token }
      func load() throws -> AuthToken? { stored }
      func delete() throws { stored = nil }
  }
  ```

- [ ] **Step 4: Create KeychainStore**

  Create `PolarMyFlow/Auth/KeychainStore.swift`:

  ```swift
  import Foundation
  import Security

  enum KeychainError: Error {
      case saveFailed(OSStatus)
      case loadFailed(OSStatus)
      case deleteFailed(OSStatus)
      case decodeFailed
  }

  struct KeychainStore: TokenStore {
      private static let service = "com.personal.polarmyflow"
      private static let account = "polar-auth-token"

      func save(_ token: AuthToken) throws {
          let data = try JSONEncoder().encode(token)
          let query: [String: Any] = [
              kSecClass as String:       kSecClassGenericPassword,
              kSecAttrService as String: Self.service,
              kSecAttrAccount as String: Self.account,
              kSecValueData as String:   data
          ]
          SecItemDelete(query as CFDictionary)
          let status = SecItemAdd(query as CFDictionary, nil)
          guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
      }

      func load() throws -> AuthToken? {
          let query: [String: Any] = [
              kSecClass as String:       kSecClassGenericPassword,
              kSecAttrService as String: Self.service,
              kSecAttrAccount as String: Self.account,
              kSecReturnData as String:  true,
              kSecMatchLimit as String:  kSecMatchLimitOne
          ]
          var result: AnyObject?
          let status = SecItemCopyMatching(query as CFDictionary, &result)
          if status == errSecItemNotFound { return nil }
          guard status == errSecSuccess, let data = result as? Data else {
              throw KeychainError.loadFailed(status)
          }
          guard let token = try? JSONDecoder().decode(AuthToken.self, from: data) else {
              throw KeychainError.decodeFailed
          }
          return token
      }

      func delete() throws {
          let query: [String: Any] = [
              kSecClass as String:       kSecClassGenericPassword,
              kSecAttrService as String: Self.service,
              kSecAttrAccount as String: Self.account
          ]
          let status = SecItemDelete(query as CFDictionary)
          guard status == errSecSuccess || status == errSecItemNotFound else {
              throw KeychainError.deleteFailed(status)
          }
      }
  }
  ```

- [ ] **Step 5: Write Keychain round-trip test**

  Note: Keychain works in the iOS Simulator. Add to a new file `PolarMyFlowTests/KeychainStoreTests.swift`:

  ```swift
  import XCTest
  @testable import PolarMyFlow

  final class KeychainStoreTests: XCTestCase {
      var store: KeychainStore!

      override func setUp() {
          store = KeychainStore()
          try? store.delete() // clean slate
      }

      override func tearDown() {
          try? store.delete()
      }

      func test_saveAndLoad_roundtrip() throws {
          let token = AuthToken(accessToken: "access", refreshToken: "refresh", expiresIn: 3600)
          try store.save(token)
          let loaded = try store.load()
          XCTAssertEqual(loaded?.accessToken, "access")
          XCTAssertEqual(loaded?.refreshToken, "refresh")
      }

      func test_load_returnsNilWhenEmpty() throws {
          let result = try store.load()
          XCTAssertNil(result)
      }

      func test_delete_removesToken() throws {
          let token = AuthToken(accessToken: "x", refreshToken: "y", expiresIn: 100)
          try store.save(token)
          try store.delete()
          let result = try store.load()
          XCTAssertNil(result)
      }

      func test_isExpired_falseForFutureToken() {
          let token = AuthToken(accessToken: "a", refreshToken: "b", expiresIn: 3600)
          XCTAssertFalse(token.isExpired)
      }

      func test_isExpired_trueForPastToken() {
          let token = AuthToken(accessToken: "a", refreshToken: "b", expiresIn: -1)
          XCTAssertTrue(token.isExpired)
      }
  }
  ```

- [ ] **Step 6: Run tests and verify they pass**

  Cmd+U. Expected: all `KeychainStoreTests` pass.

- [ ] **Step 7: Commit**

  ```bash
  git add PolarMyFlow/Auth/AuthToken.swift \
          PolarMyFlow/Auth/TokenStore.swift \
          PolarMyFlow/Auth/KeychainStore.swift \
          PolarMyFlowTests/Helpers/TestHelpers.swift \
          PolarMyFlowTests/KeychainStoreTests.swift
  git commit -m "feat: add AuthToken, TokenStore protocol, and KeychainStore"
  ```

---

## Task 7: AuthManager

**Files:**
- Create: `PolarMyFlow/Auth/AuthManager.swift`

AuthManager wraps ASWebAuthenticationSession which cannot be unit tested (requires UI context). No unit tests. Behaviour is verified by running the app manually.

- [ ] **Step 1: Create AuthManager**

  Create `PolarMyFlow/Auth/AuthManager.swift`:

  ```swift
  import Foundation
  import AuthenticationServices

  enum AuthError: Error {
      case noCallbackURL
      case noAuthCode
      case tokenExchangeFailed(Error)
      case notAuthenticated
  }

  @MainActor
  @Observable
  final class AuthManager: NSObject {
      private(set) var isAuthenticated: Bool = false
      private(set) var currentUserID: String?
      private(set) var currentToken: AuthToken?

      private let tokenStore: TokenStore
      private let session: URLSession

      // Polar API constants
      static let clientID     = "c045142a-470a-4d0c-8f44-b8aa1200e975"
      static let clientSecret = "59ccbd6e-aaae-4881-b121-a3b7774ff03b"
      static let redirectURI  = "polarflow://auth"
      static let authURLBase  = "https://flow.polar.com/oauth2/authorization"
      static let tokenURL     = "https://polarremote.com/v2/oauth2/token"

      init(tokenStore: TokenStore = KeychainStore(), session: URLSession = .shared) {
          self.tokenStore = tokenStore
          self.session = session
      }

      // Call on app launch to restore session
      func restoreSession() {
          guard let token = try? tokenStore.load() else { return }
          currentToken = token
          isAuthenticated = true
      }

      // Opens Polar OAuth in ASWebAuthenticationSession
      func authenticate() async throws {
          var components = URLComponents(string: Self.authURLBase)!
          components.queryItems = [
              URLQueryItem(name: "response_type", value: "code"),
              URLQueryItem(name: "client_id",     value: Self.clientID),
              URLQueryItem(name: "redirect_uri",  value: Self.redirectURI),
              URLQueryItem(name: "scope",         value: "accesslink.read_all")
          ]
          let authURL = components.url!

          let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
              let webSession = ASWebAuthenticationSession(
                  url: authURL,
                  callbackURLScheme: "polarflow"
              ) { url, error in
                  if let error { continuation.resume(throwing: error); return }
                  guard let url else { continuation.resume(throwing: AuthError.noCallbackURL); return }
                  continuation.resume(returning: url)
              }
              webSession.presentationContextProvider = self
              webSession.prefersEphemeralWebBrowserSession = false
              webSession.start()
          }

          guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
              .queryItems?.first(where: { $0.name == "code" })?.value
          else { throw AuthError.noAuthCode }

          let token = try await exchangeCode(code)
          try tokenStore.save(token)
          currentToken = token
          isAuthenticated = true
      }

      // Refresh expired token using refresh token
      func refreshIfNeeded() async throws {
          guard let token = currentToken, token.isExpired else { return }
          let refreshed = try await refreshToken(token.refreshToken)
          try tokenStore.save(refreshed)
          currentToken = refreshed
      }

      func signOut() throws {
          try tokenStore.delete()
          currentToken = nil
          isAuthenticated = false
          currentUserID = nil
      }

      func setUserID(_ id: String) {
          currentUserID = id
      }

      // MARK: - Private

      private func exchangeCode(_ code: String) async throws -> AuthToken {
          var request = URLRequest(url: URL(string: Self.tokenURL)!)
          request.httpMethod = "POST"
          request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
          let credentials = Data("\(Self.clientID):\(Self.clientSecret)".utf8).base64EncodedString()
          request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
          request.httpBody = "grant_type=authorization_code&code=\(code)&redirect_uri=\(Self.redirectURI)"
              .data(using: .utf8)

          let (data, _) = try await session.data(for: request)
          return try decodeTokenResponse(data)
      }

      private func refreshToken(_ refreshToken: String) async throws -> AuthToken {
          var request = URLRequest(url: URL(string: Self.tokenURL)!)
          request.httpMethod = "POST"
          request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
          let credentials = Data("\(Self.clientID):\(Self.clientSecret)".utf8).base64EncodedString()
          request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
          request.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)"
              .data(using: .utf8)

          let (data, _) = try await session.data(for: request)
          return try decodeTokenResponse(data)
      }

      private func decodeTokenResponse(_ data: Data) throws -> AuthToken {
          struct Response: Decodable {
              let access_token: String
              let refresh_token: String
              let expires_in: Int
          }
          let r = try JSONDecoder().decode(Response.self, from: data)
          return AuthToken(accessToken: r.access_token, refreshToken: r.refresh_token, expiresIn: r.expires_in)
      }
  }

  extension AuthManager: ASWebAuthenticationPresentationContextProviding {
      func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
          UIApplication.shared.connectedScenes
              .compactMap { $0 as? UIWindowScene }
              .flatMap { $0.windows }
              .first { $0.isKeyWindow } ?? UIWindow()
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add PolarMyFlow/Auth/AuthManager.swift
  git commit -m "feat: add AuthManager with OAuth2 flow and token refresh"
  ```

---

## Task 8: Discover Polar Flow Web API Endpoints (Research)

**Files:**
- Create: `PolarMyFlow/API/PolarFlowWebConstants.swift` (you fill this in based on findings)

This task has no automated tests. You are discovering the internal API that flow.polar.com uses. Its shape is not publicly documented and must be found by inspection.

- [ ] **Step 1: Open browser DevTools on flow.polar.com**

  1. Open Chrome or Safari
  2. Navigate to https://flow.polar.com and log in
  3. Open DevTools: Chrome → F12 / Cmd+Option+I; Safari → Develop → Show Web Inspector
  4. Go to the **Network** tab
  5. Filter by **Fetch/XHR**

- [ ] **Step 2: Navigate to the training list and capture the list endpoint**

  Navigate to https://flow.polar.com/diary/training-list

  In the Network tab, look for requests to URLs containing `/api/` or `/training/`. You are looking for the request that returns a list of training sessions. Record:
  - Full URL and query parameters (pagination, date range, etc.)
  - Response JSON shape (array of sessions with what fields?)
  - Authentication header used (Bearer token? Cookie?)

- [ ] **Step 3: Click an individual training session and capture the detail endpoint**

  Click into one activity. Record:
  - The detail endpoint URL
  - Response JSON shape — particularly: id, startTime, duration, distance, sport, speed, heart rate (avg/max), ascent, descent, calories, hasRoute

- [ ] **Step 4: Capture authentication method**

  Check whether requests use:
  - `Authorization: Bearer <token>` (same OAuth token as AccessLink)
  - Session cookies (set during web login — different mechanism)
  - Something else

  This determines how `PolarFlowWebClient` will authenticate.

- [ ] **Step 5: Document findings in PolarFlowWebConstants.swift**

  Create `PolarMyFlow/API/PolarFlowWebConstants.swift` and fill in your findings:

  ```swift
  // IMPORTANT: These are internal Polar Flow web API endpoints.
  // They are undocumented and may change without notice.
  // Discovered by inspecting flow.polar.com network traffic on 2026-04-12.

  enum PolarFlowWebConstants {
      // Replace these with the actual discovered values:
      static let baseURL        = "https://flow.polar.com"
      static let trainingListPath = "/api/DISCOVERED_PATH"   // e.g. /api/training/getCalendarEvents
      static let trainingDetailPath = "/api/DISCOVERED_PATH" // e.g. /api/training/{id}

      // Authentication method discovered (fill in one):
      // "bearer"  — uses same OAuth access token as AccessLink (Authorization: Bearer)
      // "cookie"  — uses web session cookie from browser login
      static let authMethod = "bearer_or_cookie"

      // Pagination: how many activities per request?
      static let pageSize = 20  // update if different
  }
  ```

- [ ] **Step 6: Commit your findings**

  ```bash
  git add PolarMyFlow/API/PolarFlowWebConstants.swift
  git commit -m "chore: document discovered Polar Flow web API endpoints"
  ```

---

## Task 9: MockURLProtocol + APIError + PolarFlowWebClient

**Files:**
- Create: `PolarMyFlowTests/Helpers/MockURLProtocol.swift`
- Create: `PolarMyFlow/API/APIError.swift`
- Create: `PolarMyFlow/API/PolarFlowWebClient.swift`
- Create: `PolarMyFlowTests/PolarFlowWebClientTests.swift`

> Before starting this task, complete Task 8. The JSON shapes in the tests below use placeholder field names — update them to match what you discovered in Task 8.

- [ ] **Step 1: Create MockURLProtocol**

  Create `PolarMyFlowTests/Helpers/MockURLProtocol.swift`:

  ```swift
  import Foundation

  class MockURLProtocol: URLProtocol {
      static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

      override class func canInit(with request: URLRequest) -> Bool { true }
      override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

      override func startLoading() {
          guard let handler = MockURLProtocol.requestHandler else {
              client?.urlProtocol(self, didFailWithError: URLError(.unknown))
              return
          }
          do {
              let (response, data) = try handler(request)
              client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
              client?.urlProtocol(self, didLoad: data)
              client?.urlProtocolDidFinishLoading(self)
          } catch {
              client?.urlProtocol(self, didFailWithError: error)
          }
      }

      override func stopLoading() {}
  }

  func makeMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [MockURLProtocol.self]
      return URLSession(configuration: config)
  }
  ```

- [ ] **Step 2: Create APIError**

  Create `PolarMyFlow/API/APIError.swift`:

  ```swift
  import Foundation

  enum APIError: Error, Equatable {
      case httpError(statusCode: Int)
      case decodingFailed
      case networkUnavailable
      case apiChanged(String)   // internal API broke — shows user-facing message
  }
  ```

- [ ] **Step 3: Write failing tests for PolarFlowWebClient**

  Create `PolarMyFlowTests/PolarFlowWebClientTests.swift`:

  > Update the JSON in these tests to match the actual response shape you discovered in Task 8.

  ```swift
  import XCTest
  @testable import PolarMyFlow

  final class PolarFlowWebClientTests: XCTestCase {
      var client: PolarFlowWebClient!

      override func setUp() {
          client = PolarFlowWebClient(session: makeMockSession(), accessToken: "test-token")
      }

      func test_fetchActivities_parsesResponseCorrectly() async throws {
          // UPDATE this JSON to match the actual response shape from Task 8
          let json = """
          {
            "sessions": [
              {
                "id": "abc123",
                "startTime": "2025-01-15T09:00:00Z",
                "duration": 5400,
                "distance": 15000.0,
                "sport": "CROSS_COUNTRY_SKIING",
                "avgSpeed": 2.78,
                "avgHeartRate": 142,
                "maxHeartRate": 170,
                "ascent": 120.0,
                "descent": 115.0,
                "calories": 800,
                "hasRoute": true
              }
            ]
          }
          """.data(using: .utf8)!

          MockURLProtocol.requestHandler = { _ in
              let response = HTTPURLResponse(
                  url: URL(string: "https://flow.polar.com")!,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: nil
              )!
              return (response, json)
          }

          let activities = try await client.fetchAllActivities()
          XCTAssertEqual(activities.count, 1)
          let act = activities[0]
          XCTAssertEqual(act.id, "abc123")
          XCTAssertEqual(act.distance, 15000.0)
          XCTAssertEqual(act.sportRawValue, "CROSS_COUNTRY_SKIING")
          XCTAssertEqual(act.avgHeartRate, 142)
          XCTAssertEqual(act.ascent, 120.0)
      }

      func test_fetchActivities_throwsOnHTTPError() async throws {
          MockURLProtocol.requestHandler = { _ in
              let response = HTTPURLResponse(
                  url: URL(string: "https://flow.polar.com")!,
                  statusCode: 401,
                  httpVersion: nil,
                  headerFields: nil
              )!
              return (response, Data())
          }
          do {
              _ = try await client.fetchAllActivities()
              XCTFail("Expected error")
          } catch APIError.httpError(let code) {
              XCTAssertEqual(code, 401)
          }
      }
  }
  ```

- [ ] **Step 4: Run tests to confirm they fail**

  Cmd+U. Expected: compile error — `PolarFlowWebClient` not defined.

- [ ] **Step 5: Implement PolarFlowWebClient**

  Create `PolarMyFlow/API/PolarFlowWebClient.swift`:

  > Update the JSON decoding struct fields and URL construction to match your Task 8 findings.

  ```swift
  import Foundation

  final class PolarFlowWebClient {
      private let session: URLSession
      private let accessToken: String

      init(session: URLSession = .shared, accessToken: String) {
          self.session = session
          self.accessToken = accessToken
      }

      // Fetches all historical activities by paginating through the list endpoint.
      // UPDATE the URL and JSON parsing to match discovered endpoints from Task 8.
      func fetchAllActivities() async throws -> [Activity] {
          var all: [Activity] = []
          var page = 0
          while true {
              let batch = try await fetchPage(page: page)
              if batch.isEmpty { break }
              all.append(contentsOf: batch)
              page += 1
          }
          return all
      }

      private func fetchPage(page: Int) async throws -> [Activity] {
          // UPDATE this URL to the actual endpoint from Task 8
          var components = URLComponents(string: PolarFlowWebConstants.baseURL + PolarFlowWebConstants.trainingListPath)!
          components.queryItems = [
              URLQueryItem(name: "page", value: "\(page)"),
              URLQueryItem(name: "size", value: "\(PolarFlowWebConstants.pageSize)")
          ]
          var request = URLRequest(url: components.url!)
          request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
          request.setValue("application/json", forHTTPHeaderField: "Accept")

          let (data, response) = try await session.data(for: request)
          guard let http = response as? HTTPURLResponse else { throw APIError.networkUnavailable }
          guard http.statusCode == 200 else { throw APIError.httpError(statusCode: http.statusCode) }

          return try parseActivities(from: data)
      }

      // UPDATE the struct fields and mapping below to match actual JSON from Task 8
      private func parseActivities(from data: Data) throws -> [Activity] {
          struct Response: Decodable {
              struct Session: Decodable {
                  let id: String
                  let startTime: String
                  let duration: Double       // seconds — update field name if different
                  let distance: Double       // metres
                  let sport: String
                  let avgSpeed: Double?
                  let avgHeartRate: Int?
                  let maxHeartRate: Int?
                  let ascent: Double?
                  let descent: Double?
                  let calories: Int?
                  let hasRoute: Bool?
              }
              let sessions: [Session]       // update key name if different
          }

          guard let parsed = try? JSONDecoder().decode(Response.self, from: data) else {
              throw APIError.apiChanged("Unable to import history — Polar may have updated their API")
          }

          let formatter = ISO8601DateFormatter()
          return parsed.sessions.compactMap { s in
              guard let date = formatter.date(from: s.startTime) else { return nil }
              let speed = s.avgSpeed ?? (s.distance / s.duration)
              let pace  = s.duration / s.distance
              return Activity(
                  id: s.id,
                  startTime: date,
                  duration: s.duration,
                  distance: s.distance,
                  sportRawValue: s.sport,
                  avgSpeed: speed,
                  avgPace: pace,
                  avgHeartRate: s.avgHeartRate,
                  maxHeartRate: s.maxHeartRate,
                  ascent: s.ascent,
                  descent: s.descent,
                  calories: s.calories,
                  hasRoute: s.hasRoute ?? false
              )
          }
      }
  }
  ```

- [ ] **Step 6: Update tests to match actual JSON, then run and verify they pass**

  After updating the JSON shapes in tests to match Task 8 findings, Cmd+U. Expected: all `PolarFlowWebClientTests` pass.

- [ ] **Step 7: Commit**

  ```bash
  git add PolarMyFlowTests/Helpers/MockURLProtocol.swift \
          PolarMyFlow/API/APIError.swift \
          PolarMyFlow/API/PolarFlowWebClient.swift \
          PolarMyFlowTests/PolarFlowWebClientTests.swift
  git commit -m "feat: add PolarFlowWebClient for historical activity import"
  ```

---

## Task 10: PolarAccessLinkClient

**Files:**
- Create: `PolarMyFlow/API/PolarAccessLinkClient.swift`
- Create: `PolarMyFlowTests/PolarAccessLinkClientTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `PolarMyFlowTests/PolarAccessLinkClientTests.swift`:

  ```swift
  import XCTest
  @testable import PolarMyFlow

  final class PolarAccessLinkClientTests: XCTestCase {
      var client: PolarAccessLinkClient!

      override func setUp() {
          client = PolarAccessLinkClient(session: makeMockSession(), accessToken: "test-token")
      }

      // MARK: - User registration

      func test_registerUser_returnsUserID() async throws {
          let json = """
          { "polar-user-id": 99, "member-id": "user@example.com" }
          """.data(using: .utf8)!
          MockURLProtocol.requestHandler = { _ in
              (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                               statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
          }
          let userID = try await client.registerUser()
          XCTAssertEqual(userID, "99")
      }

      func test_registerUser_409_meansAlreadyRegistered() async throws {
          // 409 Conflict = user already registered — should succeed, return existing ID
          // The client re-fetches user info on 409
          // This test verifies no error is thrown
          let json = """
          { "polar-user-id": 77, "member-id": "user@example.com" }
          """.data(using: .utf8)!
          var callCount = 0
          MockURLProtocol.requestHandler = { request in
              callCount += 1
              let code = callCount == 1 ? 409 : 200
              return (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                                     statusCode: code, httpVersion: nil, headerFields: nil)!, json)
          }
          let userID = try await client.registerUser()
          XCTAssertEqual(userID, "77")
      }

      // MARK: - Exercise transaction

      func test_pullNewActivities_204_returnsEmpty() async throws {
          MockURLProtocol.requestHandler = { _ in
              (HTTPURLResponse(url: URL(string: "https://www.polaraccesslink.com")!,
                               statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
          }
          let activities = try await client.pullNewActivities()
          XCTAssertTrue(activities.isEmpty)
      }

      func test_pullNewActivities_parsesExerciseDetail() async throws {
          let transactionJSON = """
          { "transaction-id": 101, "exercises": [
              { "id": 1, "href": "https://www.polaraccesslink.com/v3/exercises/101/1" }
          ]}
          """.data(using: .utf8)!

          let detailJSON = """
          {
            "id": 1,
            "transaction-id": 101,
            "start-time": "2025-01-15T09:00:00",
            "duration": "PT1H30M0S",
            "calories": 800,
            "distance": 15000.0,
            "heart-rate": { "average": 142, "maximum": 170 },
            "sport": "CROSS_COUNTRY_SKIING",
            "has-route": true
          }
          """.data(using: .utf8)!

          var callCount = 0
          MockURLProtocol.requestHandler = { request in
              callCount += 1
              switch callCount {
              case 1: // POST transaction
                  return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, transactionJSON)
              case 2: // GET exercise list
                  return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, transactionJSON)
              case 3: // GET exercise detail
                  return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, detailJSON)
              default: // PUT commit
                  return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
              }
          }

          let activities = try await client.pullNewActivities()
          XCTAssertEqual(activities.count, 1)
          let act = activities[0]
          XCTAssertEqual(act.id, "101-1")
          XCTAssertEqual(act.duration, 5400, accuracy: 1)
          XCTAssertEqual(act.distance, 15000)
          XCTAssertEqual(act.avgHeartRate, 142)
          XCTAssertEqual(act.maxHeartRate, 170)
          XCTAssertEqual(act.sportRawValue, "CROSS_COUNTRY_SKIING")
          XCTAssertTrue(act.hasRoute)
      }

      func test_parseISO8601Duration_variousFormats() {
          XCTAssertEqual(PolarAccessLinkClient.parseISO8601Duration("PT1H30M0S"), 5400, accuracy: 0.1)
          XCTAssertEqual(PolarAccessLinkClient.parseISO8601Duration("PT42M1S"),   2521, accuracy: 0.1)
          XCTAssertEqual(PolarAccessLinkClient.parseISO8601Duration("PT30S"),       30, accuracy: 0.1)
          XCTAssertNil(PolarAccessLinkClient.parseISO8601Duration("invalid"))
      }
  }
  ```

- [ ] **Step 2: Run tests to confirm they fail**

  Cmd+U. Expected: compile error — `PolarAccessLinkClient` not defined.

- [ ] **Step 3: Implement PolarAccessLinkClient**

  Create `PolarMyFlow/API/PolarAccessLinkClient.swift`:

  ```swift
  import Foundation

  final class PolarAccessLinkClient {
      private let session: URLSession
      private var accessToken: String
      private static let baseURL = "https://www.polaraccesslink.com"

      init(session: URLSession = .shared, accessToken: String) {
          self.session = session
          self.accessToken = accessToken
      }

      // Register user with AccessLink. Returns polar-user-id as String.
      // 409 = already registered — fetch user info and return ID.
      func registerUser() async throws -> String {
          let url = URL(string: "\(Self.baseURL)/v3/users")!
          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.httpBody = try? JSONSerialization.data(withJSONObject: ["member-id": ""])

          let (data, response) = try await session.data(for: request)
          let http = response as! HTTPURLResponse

          if http.statusCode == 409 {
              // Already registered — fetch existing user
              return try await fetchCurrentUserID()
          }
          guard http.statusCode == 200 || http.statusCode == 201 else {
              throw APIError.httpError(statusCode: http.statusCode)
          }
          return try parseUserID(from: data)
      }

      // Fetch all new activities via the transaction model.
      // Returns empty array if 204 (no new activities).
      // Commits transaction after successful fetch.
      func pullNewActivities() async throws -> [Activity] {
          // 1. Create transaction
          let transactionURL = URL(string: "\(Self.baseURL)/v3/exercises/transaction")!
          var txRequest = URLRequest(url: transactionURL)
          txRequest.httpMethod = "POST"
          txRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
          txRequest.setValue("application/json", forHTTPHeaderField: "Accept")

          let (txData, txResponse) = try await session.data(for: txRequest)
          let txHTTP = txResponse as! HTTPURLResponse

          if txHTTP.statusCode == 204 { return [] }
          guard txHTTP.statusCode == 201 else {
              throw APIError.httpError(statusCode: txHTTP.statusCode)
          }

          struct TransactionResponse: Decodable {
              let `transaction-id`: Int
          }
          guard let tx = try? JSONDecoder().decode(TransactionResponse.self, from: txData) else {
              throw APIError.decodingFailed
          }
          let transactionID = tx.`transaction-id`

          // 2. Fetch exercise list
          let listURL = URL(string: "\(Self.baseURL)/v3/exercises/\(transactionID)")!
          var listRequest = URLRequest(url: listURL)
          listRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
          listRequest.setValue("application/json", forHTTPHeaderField: "Accept")

          let (listData, _) = try await session.data(for: listRequest)

          struct ExerciseRef: Decodable {
              let id: Int
          }
          struct ListResponse: Decodable {
              let exercises: [ExerciseRef]
          }
          guard let list = try? JSONDecoder().decode(ListResponse.self, from: listData) else {
              throw APIError.decodingFailed
          }

          // 3. Fetch detail for each exercise
          var activities: [Activity] = []
          for ref in list.exercises {
              let detailURL = URL(string: "\(Self.baseURL)/v3/exercises/\(transactionID)/\(ref.id)")!
              var detailReq = URLRequest(url: detailURL)
              detailReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
              detailReq.setValue("application/json", forHTTPHeaderField: "Accept")
              let (detailData, _) = try await session.data(for: detailReq)
              if let activity = parseExerciseDetail(detailData, transactionID: transactionID) {
                  activities.append(activity)
              }
          }

          // 4. Commit transaction
          var commitRequest = URLRequest(url: listURL)
          commitRequest.httpMethod = "PUT"
          commitRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
          _ = try await session.data(for: commitRequest)

          return activities
      }

      // MARK: - Parsing

      private func fetchCurrentUserID() async throws -> String {
          let url = URL(string: "\(Self.baseURL)/v3/users/\(0)")! // placeholder; real impl fetches /v3/users
          var request = URLRequest(url: url)
          request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
          request.setValue("application/json", forHTTPHeaderField: "Accept")
          let (data, _) = try await session.data(for: request)
          return try parseUserID(from: data)
      }

      private func parseUserID(from data: Data) throws -> String {
          struct UserResponse: Decodable {
              let `polar-user-id`: Int
          }
          guard let r = try? JSONDecoder().decode(UserResponse.self, from: data) else {
              throw APIError.decodingFailed
          }
          return "\(r.`polar-user-id`)"
      }

      private func parseExerciseDetail(_ data: Data, transactionID: Int) -> Activity? {
          struct HeartRate: Decodable {
              let average: Int?
              let maximum: Int?
          }
          struct Detail: Decodable {
              let id: Int
              let `start-time`: String
              let duration: String
              let calories: Int?
              let distance: Double?
              let `heart-rate`: HeartRate?
              let sport: String?
              let `has-route`: Bool?
          }
          guard let d = try? JSONDecoder().decode(Detail.self, from: data),
                let dist = d.distance, dist > 0,
                let dur = Self.parseISO8601Duration(d.duration)
          else { return nil }

          let formatter = ISO8601DateFormatter()
          formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate]
          guard let startTime = formatter.date(from: d.`start-time`) else { return nil }

          let speed = dist / dur
          let pace  = dur / dist

          return Activity(
              id: "\(transactionID)-\(d.id)",
              startTime: startTime,
              duration: dur,
              distance: dist,
              sportRawValue: d.sport ?? "OTHER",
              avgSpeed: speed,
              avgPace: pace,
              avgHeartRate: d.`heart-rate`?.average,
              maxHeartRate: d.`heart-rate`?.maximum,
              calories: d.calories,
              hasRoute: d.`has-route` ?? false
          )
      }

      // Internal for testing
      static func parseISO8601Duration(_ string: String) -> TimeInterval? {
          guard string.hasPrefix("PT") else { return nil }
          var remaining = String(string.dropFirst(2))
          var total: Double = 0
          for (unit, multiplier) in [("H", 3600.0), ("M", 60.0), ("S", 1.0)] {
              if let range = remaining.range(of: unit) {
                  let valueStr = String(remaining[remaining.startIndex..<range.lowerBound])
                  if let value = Double(valueStr) { total += value * multiplier }
                  remaining = String(remaining[range.upperBound...])
              }
          }
          return total > 0 ? total : nil
      }
  }
  ```

- [ ] **Step 4: Run tests and verify they pass**

  Cmd+U. Expected: all `PolarAccessLinkClientTests` pass.

- [ ] **Step 5: Commit**

  ```bash
  git add PolarMyFlow/API/PolarAccessLinkClient.swift \
          PolarMyFlowTests/PolarAccessLinkClientTests.swift
  git commit -m "feat: add PolarAccessLinkClient with transaction-based exercise sync"
  ```

---

## Task 11: SyncCoordinator

**Files:**
- Create: `PolarMyFlow/Data/SyncCoordinator.swift`
- Create: `PolarMyFlowTests/SyncCoordinatorTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `PolarMyFlowTests/SyncCoordinatorTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import PolarMyFlow

  final class SyncCoordinatorTests: XCTestCase {
      var context: ModelContext!
      var repo: ActivityRepository!
      var coordinator: SyncCoordinator!
      var mockAccessLink: MockAccessLinkClient!
      var mockFlowWeb: MockFlowWebClient!

      override func setUpWithError() throws {
          context = try makeTestContext()
          repo = ActivityRepository(context: context)
          mockAccessLink = MockAccessLinkClient()
          mockFlowWeb = MockFlowWebClient()
          coordinator = SyncCoordinator(
              repository: repo,
              accessLinkClient: mockAccessLink,
              flowWebClient: mockFlowWeb
          )
      }

      func test_firstLaunch_runsHistoricalImportThenRegistersAccessLink() async throws {
          mockFlowWeb.stubbedActivities = [makeActivity(id: "hist-1")]
          mockAccessLink.stubbedUserID = "user-42"
          mockAccessLink.stubbedActivities = []

          let progress = try await coordinator.sync(userID: "user-42")

          XCTAssertTrue(mockFlowWeb.fetchAllCalled)
          XCTAssertTrue(mockAccessLink.registerCalled)
          XCTAssertEqual(progress.imported, 1)

          let state = try repo.syncState(forUserID: "user-42")
          XCTAssertTrue(state.historicalImportComplete)
          XCTAssertTrue(state.accessLinkRegistered)
      }

      func test_subsequentLaunch_onlyCallsAccessLink() async throws {
          // Pre-seed state as already completed first launch
          let state = try repo.syncState(forUserID: "user-42")
          state.historicalImportComplete = true
          state.accessLinkRegistered = true
          try context.save()

          mockAccessLink.stubbedActivities = [makeActivity(id: "new-1")]

          _ = try await coordinator.sync(userID: "user-42")

          XCTAssertFalse(mockFlowWeb.fetchAllCalled)
          XCTAssertFalse(mockAccessLink.registerCalled)

          let all = try repo.fetchAll()
          XCTAssertEqual(all.count, 1)
          XCTAssertEqual(all.first?.id, "new-1")
      }

      func test_deduplication_doesNotDoubleCount() async throws {
          try repo.save(makeActivity(id: "shared-1"))

          let state = try repo.syncState(forUserID: "user-42")
          state.historicalImportComplete = true
          state.accessLinkRegistered = true
          try context.save()

          mockAccessLink.stubbedActivities = [makeActivity(id: "shared-1"), makeActivity(id: "new-2")]

          _ = try await coordinator.sync(userID: "user-42")

          let all = try repo.fetchAll()
          XCTAssertEqual(all.count, 2)  // shared-1 + new-2, no duplicate
      }
  }

  // MARK: - Mock clients

  class MockAccessLinkClient: AccessLinkClientProtocol {
      var registerCalled = false
      var stubbedUserID = "user-1"
      var stubbedActivities: [Activity] = []

      func registerUser() async throws -> String {
          registerCalled = true
          return stubbedUserID
      }
      func pullNewActivities() async throws -> [Activity] { stubbedActivities }
  }

  class MockFlowWebClient: FlowWebClientProtocol {
      var fetchAllCalled = false
      var stubbedActivities: [Activity] = []

      func fetchAllActivities() async throws -> [Activity] {
          fetchAllCalled = true
          return stubbedActivities
      }
  }
  ```

- [ ] **Step 2: Run tests to confirm they fail**

  Cmd+U. Expected: compile errors — `SyncCoordinator`, `AccessLinkClientProtocol`, `FlowWebClientProtocol` not defined.

- [ ] **Step 3: Add protocols to API client files**

  Append to `PolarMyFlow/API/PolarAccessLinkClient.swift`:

  ```swift
  protocol AccessLinkClientProtocol {
      func registerUser() async throws -> String
      func pullNewActivities() async throws -> [Activity]
  }

  extension PolarAccessLinkClient: AccessLinkClientProtocol {}
  ```

  Append to `PolarMyFlow/API/PolarFlowWebClient.swift`:

  ```swift
  protocol FlowWebClientProtocol {
      func fetchAllActivities() async throws -> [Activity]
  }

  extension PolarFlowWebClient: FlowWebClientProtocol {}
  ```

- [ ] **Step 4: Implement SyncCoordinator**

  Create `PolarMyFlow/Data/SyncCoordinator.swift`:

  ```swift
  import Foundation

  struct SyncProgress {
      let imported: Int
      let errors: [Error]
  }

  final class SyncCoordinator {
      private let repository: ActivityRepository
      private let accessLinkClient: AccessLinkClientProtocol
      private let flowWebClient: FlowWebClientProtocol

      init(
          repository: ActivityRepository,
          accessLinkClient: AccessLinkClientProtocol,
          flowWebClient: FlowWebClientProtocol
      ) {
          self.repository = repository
          self.accessLinkClient = accessLinkClient
          self.flowWebClient = flowWebClient
      }

      // Main entry point. Call on every app launch with the authenticated user's ID.
      @discardableResult
      func sync(userID: String) async throws -> SyncProgress {
          let state = try repository.syncState(forUserID: userID)
          var imported = 0
          var errors: [Error] = []

          if !state.historicalImportComplete {
              // First launch: import history then register with AccessLink
              do {
                  let historical = try await flowWebClient.fetchAllActivities()
                  for activity in historical {
                      try repository.save(activity)
                      imported += 1
                  }
                  state.historicalImportComplete = true
              } catch {
                  errors.append(error)
              }

              if !state.accessLinkRegistered {
                  do {
                      _ = try await accessLinkClient.registerUser()
                      state.accessLinkRegistered = true
                  } catch {
                      errors.append(error)
                  }
              }
          } else {
              // Subsequent launches: AccessLink only
              do {
                  let newActivities = try await accessLinkClient.pullNewActivities()
                  for activity in newActivities {
                      try repository.save(activity)
                      imported += 1
                  }
              } catch {
                  errors.append(error)
              }
          }

          state.lastSyncedAt = Date()
          try repository.saveSyncState()

          return SyncProgress(imported: imported, errors: errors)
      }
  }
  ```

- [ ] **Step 5: Run tests and verify they pass**

  Cmd+U. Expected: all `SyncCoordinatorTests` pass.

- [ ] **Step 6: Commit**

  ```bash
  git add PolarMyFlow/API/PolarAccessLinkClient.swift \
          PolarMyFlow/API/PolarFlowWebClient.swift \
          PolarMyFlow/Data/SyncCoordinator.swift \
          PolarMyFlowTests/SyncCoordinatorTests.swift
  git commit -m "feat: add SyncCoordinator orchestrating historical import and AccessLink sync"
  ```

---

## Task 12: App Entry Point + Root Tab Navigation

**Files:**
- Modify: `PolarMyFlow/PolarMyFlowApp.swift`
- Modify: `PolarMyFlow/ContentView.swift`

- [ ] **Step 1: Update PolarMyFlowApp**

  Replace contents of `PolarMyFlow/PolarMyFlowApp.swift`:

  ```swift
  import SwiftUI
  import SwiftData

  @main
  struct PolarMyFlowApp: App {
      @State private var authManager = AuthManager()

      var sharedModelContainer: ModelContainer = {
          let schema = Schema([Activity.self, SyncState.self])
          let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
          do {
              return try ModelContainer(for: schema, configurations: [config])
          } catch {
              fatalError("Could not create ModelContainer: \(error)")
          }
      }()

      var body: some Scene {
          WindowGroup {
              ContentView()
                  .environment(authManager)
          }
          .modelContainer(sharedModelContainer)
      }
  }
  ```

- [ ] **Step 2: Update ContentView with tab navigation**

  Replace contents of `PolarMyFlow/ContentView.swift`:

  ```swift
  import SwiftUI
  import SwiftData

  struct ContentView: View {
      @Environment(AuthManager.self) private var authManager

      var body: some View {
          if authManager.isAuthenticated {
              MainTabView()
                  .onAppear { authManager.restoreSession() }
          } else {
              LoginView()
          }
      }
  }

  struct MainTabView: View {
      var body: some View {
          TabView {
              DashboardView()
                  .tabItem {
                      Label("Dashboard", systemImage: "chart.bar.fill")
                  }
              ActivityListView()
                  .tabItem {
                      Label("Activities", systemImage: "list.bullet")
                  }
              TracksPlaceholderView()
                  .tabItem {
                      Label("Tracks", systemImage: "map")
                  }
          }
      }
  }

  struct LoginView: View {
      @Environment(AuthManager.self) private var authManager
      @State private var isAuthenticating = false
      @State private var errorMessage: String?

      var body: some View {
          VStack(spacing: 24) {
              Image(systemName: "figure.run.circle.fill")
                  .font(.system(size: 80))
                  .foregroundStyle(.blue)
              Text("Polar MyFlow")
                  .font(.largeTitle.bold())
              Text("Connect your Polar account to view your training history.")
                  .multilineTextAlignment(.center)
                  .foregroundStyle(.secondary)
              if let error = errorMessage {
                  Text(error)
                      .foregroundStyle(.red)
                      .font(.caption)
              }
              Button {
                  Task {
                      isAuthenticating = true
                      errorMessage = nil
                      do {
                          try await authManager.authenticate()
                      } catch {
                          errorMessage = "Authentication failed. Please try again."
                      }
                      isAuthenticating = false
                  }
              } label: {
                  if isAuthenticating {
                      ProgressView()
                          .frame(maxWidth: .infinity)
                  } else {
                      Text("Connect with Polar")
                          .frame(maxWidth: .infinity)
                  }
              }
              .buttonStyle(.borderedProminent)
              .disabled(isAuthenticating)
              .padding(.horizontal)
          }
          .padding()
      }
  }
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add PolarMyFlow/PolarMyFlowApp.swift PolarMyFlow/ContentView.swift
  git commit -m "feat: add app entry point, SwiftData container, and tab navigation"
  ```

---

## Task 13: Dashboard UI

**Files:**
- Create: `PolarMyFlow/Features/Dashboard/DashboardViewModel.swift`
- Create: `PolarMyFlow/Features/Dashboard/DashboardView.swift`
- Create: `PolarMyFlow/Features/Dashboard/SeasonCardView.swift`

- [ ] **Step 1: Create DashboardViewModel**

  Create `PolarMyFlow/Features/Dashboard/DashboardViewModel.swift`:

  ```swift
  import Foundation
  import SwiftData

  struct SportSummary: Identifiable {
      var id: SportType { sport }
      let sport: SportType
      let totalDistance: Double      // metres
      let totalDuration: TimeInterval
      let sessionCount: Int
      let avgPace: Double            // s/m
  }

  struct SeasonSummary: Identifiable {
      var id: Season { season }
      let season: Season
      let sportSummaries: [SportSummary]
  }

  @Observable
  final class DashboardViewModel {
      private(set) var seasons: [SeasonSummary] = []
      private(set) var isLoading = false
      private let repository: ActivityRepository

      init(repository: ActivityRepository) {
          self.repository = repository
      }

      @MainActor
      func load() async {
          isLoading = true
          defer { isLoading = false }

          guard let activities = try? repository.fetchAll() else { return }

          // Group activities by season
          var bySeason: [Season: [Activity]] = [:]
          for activity in activities {
              let season = Season.containing(activity.startTime)
              bySeason[season, default: []].append(activity)
          }

          seasons = bySeason
              .map { season, acts in
                  SeasonSummary(season: season, sportSummaries: buildSportSummaries(acts))
              }
              .sorted { $0.season > $1.season }  // newest first
      }

      private func buildSportSummaries(_ activities: [Activity]) -> [SportSummary] {
          var bySport: [SportType: [Activity]] = [:]
          for act in activities {
              bySport[act.sportType, default: []].append(act)
          }
          return bySport.map { sport, acts in
              let totalDistance = acts.reduce(0) { $0 + $1.distance }
              let totalDuration = acts.reduce(0) { $0 + $1.duration }
              let avgPace = totalDuration / totalDistance
              return SportSummary(
                  sport: sport,
                  totalDistance: totalDistance,
                  totalDuration: totalDuration,
                  sessionCount: acts.count,
                  avgPace: avgPace
              )
          }
          .sorted { $0.totalDistance > $1.totalDistance }
      }
  }
  ```

- [ ] **Step 2: Create SeasonCardView**

  Create `PolarMyFlow/Features/Dashboard/SeasonCardView.swift`:

  ```swift
  import SwiftUI

  struct SeasonCardView: View {
      let summary: SeasonSummary
      let onTapSport: (SportType) -> Void

      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              Text(summary.season.label)
                  .font(.headline)
                  .padding([.horizontal, .top])

              Divider().padding(.top, 8)

              ForEach(summary.sportSummaries) { sport in
                  Button {
                      onTapSport(sport.sport)
                  } label: {
                      SportRowView(summary: sport)
                  }
                  .buttonStyle(.plain)
                  Divider().padding(.leading, 52)
              }
          }
          .background(.background)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
      }
  }

  struct SportRowView: View {
      let summary: SportSummary

      var body: some View {
          HStack(spacing: 12) {
              Image(systemName: summary.sport.symbolName)
                  .font(.title3)
                  .frame(width: 28)
                  .foregroundStyle(.blue)

              VStack(alignment: .leading, spacing: 2) {
                  Text(summary.sport.displayName)
                      .font(.subheadline.weight(.medium))
                  Text("\(summary.sessionCount) sessions")
                      .font(.caption)
                      .foregroundStyle(.secondary)
              }

              Spacer()

              VStack(alignment: .trailing, spacing: 2) {
                  Text(formatDistance(summary.totalDistance))
                      .font(.subheadline.weight(.semibold))
                  Text(formatPace(summary.avgPace))
                      .font(.caption)
                      .foregroundStyle(.secondary)
              }
          }
          .padding(.horizontal)
          .padding(.vertical, 10)
          .contentShape(Rectangle())
      }

      private func formatDistance(_ metres: Double) -> String {
          let km = metres / 1000
          return String(format: "%.1f km", km)
      }

      // pace in s/m → format as min:ss /km
      private func formatPace(_ pace: Double) -> String {
          let secPerKm = pace * 1000
          let min = Int(secPerKm) / 60
          let sec = Int(secPerKm) % 60
          return String(format: "%d:%02d /km", min, sec)
      }
  }
  ```

- [ ] **Step 3: Create DashboardView**

  Create `PolarMyFlow/Features/Dashboard/DashboardView.swift`:

  ```swift
  import SwiftUI
  import SwiftData

  struct DashboardView: View {
      @Environment(\.modelContext) private var modelContext
      @Environment(AuthManager.self) private var authManager
      @State private var viewModel: DashboardViewModel?
      @State private var navigationPath = NavigationPath()
      @State private var selectedSport: SportType?
      @State private var selectedSeason: Season?

      var body: some View {
          NavigationStack(path: $navigationPath) {
              Group {
                  if let vm = viewModel {
                      if vm.isLoading {
                          ProgressView("Loading training history...")
                      } else if vm.seasons.isEmpty {
                          ContentUnavailableView(
                              "No training data",
                              systemImage: "figure.run",
                              description: Text("Sync your Polar account to see your training history.")
                          )
                      } else {
                          ScrollView {
                              LazyVStack(spacing: 16) {
                                  ForEach(vm.seasons) { season in
                                      SeasonCardView(summary: season) { sport in
                                          selectedSport = sport
                                          selectedSeason = season.season
                                          navigationPath.append("sport-detail")
                                      }
                                  }
                              }
                              .padding()
                          }
                      }
                  }
              }
              .navigationTitle("Dashboard")
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
      }
  }
  ```

- [ ] **Step 4: Build the app to verify no compile errors**

  In Xcode: Cmd+B. Fix any compile errors before committing.

- [ ] **Step 5: Commit**

  ```bash
  git add PolarMyFlow/Features/Dashboard/DashboardViewModel.swift \
          PolarMyFlow/Features/Dashboard/DashboardView.swift \
          PolarMyFlow/Features/Dashboard/SeasonCardView.swift
  git commit -m "feat: add Dashboard UI with seasonal sport summaries"
  ```

---

## Task 14: Sport Detail View

**Files:**
- Create: `PolarMyFlow/Features/Dashboard/SportDetailViewModel.swift`
- Create: `PolarMyFlow/Features/Dashboard/SportDetailView.swift`
- Create: `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift`
- Create: `PolarMyFlow/Features/ActivityList/ActivityDetailViewModel.swift`

- [ ] **Step 1: Create ActivityDetailViewModel**

  Create `PolarMyFlow/Features/ActivityList/ActivityDetailViewModel.swift`:

  ```swift
  import Foundation

  @Observable
  final class ActivityDetailViewModel {
      let activity: Activity

      init(activity: Activity) {
          self.activity = activity
      }

      var title: String {
          activity.sportType.displayName
      }

      var dateString: String {
          activity.startTime.formatted(date: .long, time: .shortened)
      }

      var durationString: String {
          let h = Int(activity.duration) / 3600
          let m = (Int(activity.duration) % 3600) / 60
          let s = Int(activity.duration) % 60
          if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
          return String(format: "%d:%02d", m, s)
      }

      var distanceString: String {
          String(format: "%.2f km", activity.distance / 1000)
      }

      var paceString: String {
          let secPerKm = activity.avgPace * 1000
          let min = Int(secPerKm) / 60
          let sec = Int(secPerKm) % 60
          return String(format: "%d:%02d /km", min, sec)
      }

      var avgHRString: String? {
          activity.avgHeartRate.map { "\($0) bpm" }
      }

      var maxHRString: String? {
          activity.maxHeartRate.map { "\($0) bpm" }
      }

      var ascentString: String? {
          activity.ascent.map { String(format: "↑ %.0f m", $0) }
      }

      var descentString: String? {
          activity.descent.map { String(format: "↓ %.0f m", $0) }
      }

      var caloriesString: String? {
          activity.calories.map { "\($0) kcal" }
      }
  }
  ```

- [ ] **Step 2: Create ActivityDetailView**

  Create `PolarMyFlow/Features/ActivityList/ActivityDetailView.swift`:

  ```swift
  import SwiftUI

  struct ActivityDetailView: View {
      let activity: Activity
      @State private var viewModel: ActivityDetailViewModel?

      var body: some View {
          Group {
              if let vm = viewModel {
                  List {
                      Section("Overview") {
                          LabeledContent("Date", value: vm.dateString)
                          LabeledContent("Duration", value: vm.durationString)
                          LabeledContent("Distance", value: vm.distanceString)
                          LabeledContent("Avg Pace", value: vm.paceString)
                      }
                      if vm.avgHRString != nil || vm.maxHRString != nil {
                          Section("Heart Rate") {
                              if let avg = vm.avgHRString {
                                  LabeledContent("Average", value: avg)
                              }
                              if let max = vm.maxHRString {
                                  LabeledContent("Maximum", value: max)
                              }
                          }
                      }
                      if vm.ascentString != nil || vm.descentString != nil {
                          Section("Elevation") {
                              if let asc = vm.ascentString {
                                  LabeledContent("Ascent", value: asc)
                              }
                              if let desc = vm.descentString {
                                  LabeledContent("Descent", value: desc)
                              }
                          }
                      }
                      if let cal = vm.caloriesString {
                          Section("Energy") {
                              LabeledContent("Calories", value: cal)
                          }
                      }
                  }
                  .navigationTitle(vm.title)
                  .navigationBarTitleDisplayMode(.inline)
              }
          }
          .onAppear {
              viewModel = ActivityDetailViewModel(activity: activity)
          }
      }
  }
  ```

- [ ] **Step 3: Create SportDetailViewModel**

  Create `PolarMyFlow/Features/Dashboard/SportDetailViewModel.swift`:

  ```swift
  import Foundation
  import SwiftData

  @Observable
  final class SportDetailViewModel {
      private(set) var activities: [Activity] = []
      let sport: SportType
      let season: Season
      var startDate: Date
      var endDate: Date
      private let repository: ActivityRepository

      init(sport: SportType, season: Season, repository: ActivityRepository) {
          self.sport = sport
          self.season = season
          self.repository = repository
          self.startDate = season.dateRange.lowerBound
          self.endDate = season.dateRange.upperBound
      }

      var totalDistance: String {
          let km = activities.reduce(0) { $0 + $1.distance } / 1000
          return String(format: "%.1f km", km)
      }

      var sessionCount: String { "\(activities.count) sessions" }

      @MainActor
      func load() async {
          let range = startDate..<endDate
          activities = (try? repository.fetch(sport: sport, in: range)) ?? []
      }
  }
  ```

- [ ] **Step 4: Create SportDetailView**

  Create `PolarMyFlow/Features/Dashboard/SportDetailView.swift`:

  ```swift
  import SwiftUI
  import SwiftData

  struct SportDetailView: View {
      let sport: SportType
      let season: Season
      @Environment(\.modelContext) private var modelContext
      @State private var viewModel: SportDetailViewModel?

      var body: some View {
          Group {
              if let vm = viewModel {
                  List {
                      Section {
                          HStack {
                              VStack(alignment: .leading) {
                                  Text(vm.totalDistance)
                                      .font(.title2.bold())
                                  Text("Total distance")
                                      .font(.caption)
                                      .foregroundStyle(.secondary)
                              }
                              Spacer()
                              VStack(alignment: .trailing) {
                                  Text(vm.sessionCount)
                                      .font(.title2.bold())
                                  Text("Sessions")
                                      .font(.caption)
                                      .foregroundStyle(.secondary)
                              }
                          }
                          .padding(.vertical, 4)
                      }

                      Section("Date Range") {
                          DatePicker("From", selection: Binding(
                              get: { vm.startDate },
                              set: { vm.startDate = $0; Task { await vm.load() } }
                          ), displayedComponents: .date)
                          DatePicker("To", selection: Binding(
                              get: { vm.endDate },
                              set: { vm.endDate = $0; Task { await vm.load() } }
                          ), displayedComponents: .date)
                      }

                      Section("Activities") {
                          if vm.activities.isEmpty {
                              Text("No activities in this range")
                                  .foregroundStyle(.secondary)
                          } else {
                              ForEach(vm.activities, id: \.id) { activity in
                                  NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                      ActivityRowView(activity: activity)
                                  }
                              }
                          }
                      }
                  }
                  .navigationTitle(sport.displayName)
              }
          }
          .task {
              let repo = ActivityRepository(context: modelContext)
              let vm = SportDetailViewModel(sport: sport, season: season, repository: repo)
              viewModel = vm
              await vm.load()
          }
      }
  }
  ```

- [ ] **Step 5: Build to verify no compile errors**

  Cmd+B. Fix any errors before committing.

- [ ] **Step 6: Commit**

  ```bash
  git add PolarMyFlow/Features/Dashboard/SportDetailViewModel.swift \
          PolarMyFlow/Features/Dashboard/SportDetailView.swift \
          PolarMyFlow/Features/ActivityList/ActivityDetailViewModel.swift \
          PolarMyFlow/Features/ActivityList/ActivityDetailView.swift
  git commit -m "feat: add sport detail and activity detail views"
  ```

---

## Task 15: Activity List UI

**Files:**
- Create: `PolarMyFlow/Features/ActivityList/ActivityListViewModel.swift`
- Create: `PolarMyFlow/Features/ActivityList/ActivityListView.swift`
- Create: `PolarMyFlow/Features/ActivityList/ActivityRowView.swift`

- [ ] **Step 1: Create ActivityRowView**

  Create `PolarMyFlow/Features/ActivityList/ActivityRowView.swift`:

  ```swift
  import SwiftUI

  struct ActivityRowView: View {
      let activity: Activity

      var body: some View {
          HStack(spacing: 12) {
              Image(systemName: activity.sportType.symbolName)
                  .font(.title3)
                  .frame(width: 28)
                  .foregroundStyle(.blue)

              VStack(alignment: .leading, spacing: 2) {
                  Text(activity.sportType.displayName)
                      .font(.subheadline.weight(.medium))
                  Text(activity.startTime.formatted(date: .abbreviated, time: .shortened))
                      .font(.caption)
                      .foregroundStyle(.secondary)
              }

              Spacer()

              VStack(alignment: .trailing, spacing: 2) {
                  Text(String(format: "%.1f km", activity.distance / 1000))
                      .font(.subheadline.weight(.semibold))
                  if let hr = activity.avgHeartRate {
                      Text("\(hr) bpm")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                  }
              }
          }
          .padding(.vertical, 2)
      }
  }
  ```

- [ ] **Step 2: Create ActivityListViewModel**

  Create `PolarMyFlow/Features/ActivityList/ActivityListViewModel.swift`:

  ```swift
  import Foundation
  import SwiftData

  @Observable
  final class ActivityListViewModel {
      private(set) var activities: [Activity] = []
      private(set) var availableSports: [SportType] = []
      var selectedSport: SportType? = nil {
          didSet { Task { await load() } }
      }
      private let repository: ActivityRepository

      init(repository: ActivityRepository) {
          self.repository = repository
      }

      @MainActor
      func load() async {
          availableSports = (try? repository.availableSports()) ?? []
          if let sport = selectedSport {
              activities = (try? repository.fetch(sport: sport)) ?? []
          } else {
              activities = (try? repository.fetchAll()) ?? []
          }
      }
  }
  ```

- [ ] **Step 3: Create ActivityListView**

  Create `PolarMyFlow/Features/ActivityList/ActivityListView.swift`:

  ```swift
  import SwiftUI
  import SwiftData

  struct ActivityListView: View {
      @Environment(\.modelContext) private var modelContext
      @State private var viewModel: ActivityListViewModel?

      var body: some View {
          NavigationStack {
              Group {
                  if let vm = viewModel {
                      List {
                          if !vm.availableSports.isEmpty {
                              Section {
                                  Picker("Sport", selection: Binding(
                                      get: { vm.selectedSport },
                                      set: { vm.selectedSport = $0 }
                                  )) {
                                      Text("All sports").tag(SportType?.none)
                                      ForEach(vm.availableSports, id: \.self) { sport in
                                          Label(sport.displayName, systemImage: sport.symbolName)
                                              .tag(SportType?.some(sport))
                                      }
                                  }
                                  .pickerStyle(.menu)
                              }
                          }

                          if vm.activities.isEmpty {
                              ContentUnavailableView(
                                  "No activities",
                                  systemImage: "figure.run",
                                  description: Text("No activities found for the selected filter.")
                              )
                          } else {
                              ForEach(vm.activities, id: \.id) { activity in
                                  NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                      ActivityRowView(activity: activity)
                                  }
                              }
                          }
                      }
                      .navigationTitle("Activities")
                  }
              }
              .task {
                  let repo = ActivityRepository(context: modelContext)
                  let vm = ActivityListViewModel(repository: repo)
                  viewModel = vm
                  await vm.load()
              }
          }
      }
  }
  ```

- [ ] **Step 4: Build to verify no compile errors**

  Cmd+B. Fix any errors.

- [ ] **Step 5: Commit**

  ```bash
  git add PolarMyFlow/Features/ActivityList/ActivityListViewModel.swift \
          PolarMyFlow/Features/ActivityList/ActivityListView.swift \
          PolarMyFlow/Features/ActivityList/ActivityRowView.swift
  git commit -m "feat: add Activity List tab with sport filter"
  ```

---

## Task 16: Tracks Placeholder

**Files:**
- Create: `PolarMyFlow/Features/Tracks/TracksPlaceholderView.swift`

- [ ] **Step 1: Create TracksPlaceholderView**

  Create `PolarMyFlow/Features/Tracks/TracksPlaceholderView.swift`:

  ```swift
  import SwiftUI

  struct TracksPlaceholderView: View {
      var body: some View {
          NavigationStack {
              VStack(spacing: 32) {
                  Spacer()

                  HStack(spacing: 40) {
                      VStack(spacing: 8) {
                          Image(systemName: "map")
                              .font(.system(size: 48))
                              .foregroundStyle(.tertiary)
                          Text("Map View")
                              .font(.caption)
                              .foregroundStyle(.tertiary)
                      }
                      VStack(spacing: 8) {
                          Image(systemName: "arrow.down.doc")
                              .font(.system(size: 48))
                              .foregroundStyle(.tertiary)
                          Text("GPX Export")
                              .font(.caption)
                              .foregroundStyle(.tertiary)
                      }
                  }

                  Text("Coming soon")
                      .font(.title2.bold())
                      .foregroundStyle(.secondary)

                  Text("Track maps and GPX export will be available in a future version.")
                      .multilineTextAlignment(.center)
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
                      .padding(.horizontal, 40)

                  Spacer()
              }
              .navigationTitle("Tracks")
          }
      }
  }
  ```

- [ ] **Step 2: Build to verify no compile errors**

  Cmd+B.

- [ ] **Step 3: Commit**

  ```bash
  git add PolarMyFlow/Features/Tracks/TracksPlaceholderView.swift
  git commit -m "feat: add Tracks placeholder tab"
  ```

---

## Task 17: Wire SyncCoordinator to App Lifecycle

**Files:**
- Modify: `PolarMyFlow/PolarMyFlowApp.swift`

- [ ] **Step 1: Update PolarMyFlowApp to run sync on launch**

  Replace the contents of `PolarMyFlow/PolarMyFlowApp.swift`:

  ```swift
  import SwiftUI
  import SwiftData

  @main
  struct PolarMyFlowApp: App {
      @State private var authManager = AuthManager()
      @State private var syncMessage: String?
      @State private var isSyncing = false

      var sharedModelContainer: ModelContainer = {
          let schema = Schema([Activity.self, SyncState.self])
          let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
          do {
              return try ModelContainer(for: schema, configurations: [config])
          } catch {
              fatalError("Could not create ModelContainer: \(error)")
          }
      }()

      var body: some Scene {
          WindowGroup {
              ContentView(syncMessage: syncMessage, isSyncing: isSyncing)
                  .environment(authManager)
                  .modelContainer(sharedModelContainer)
                  .task {
                      authManager.restoreSession()
                      guard authManager.isAuthenticated,
                            let token = authManager.currentToken,
                            let userID = authManager.currentUserID
                      else { return }
                      await runSync(token: token, userID: userID)
                  }
          }
      }

      @MainActor
      private func runSync(token: AuthToken, userID: String) async {
          isSyncing = true
          syncMessage = "Syncing with Polar..."

          let container = sharedModelContainer
          let context = ModelContext(container)
          let repo = ActivityRepository(context: context)
          let accessLinkClient = PolarAccessLinkClient(accessToken: token.accessToken)
          let flowWebClient = PolarFlowWebClient(accessToken: token.accessToken)
          let coordinator = SyncCoordinator(
              repository: repo,
              accessLinkClient: accessLinkClient,
              flowWebClient: flowWebClient
          )

          do {
              let state = try repo.syncState(forUserID: userID)
              if !state.historicalImportComplete {
                  syncMessage = "Importing your training history..."
              }
              let progress = try await coordinator.sync(userID: userID)
              if progress.imported > 0 {
                  syncMessage = "Imported \(progress.imported) new activities"
              } else {
                  syncMessage = nil
              }
          } catch {
              syncMessage = nil
          }

          isSyncing = false
      }
  }
  ```

- [ ] **Step 2: Update ContentView to accept sync state**

  Replace `ContentView.swift`:

  ```swift
  import SwiftUI
  import SwiftData

  struct ContentView: View {
      @Environment(AuthManager.self) private var authManager
      let syncMessage: String?
      let isSyncing: Bool

      var body: some View {
          if authManager.isAuthenticated {
              MainTabView(syncMessage: syncMessage, isSyncing: isSyncing)
          } else {
              LoginView()
          }
      }
  }

  struct MainTabView: View {
      let syncMessage: String?
      let isSyncing: Bool

      var body: some View {
          VStack(spacing: 0) {
              if isSyncing || syncMessage != nil {
                  HStack(spacing: 8) {
                      if isSyncing { ProgressView().scaleEffect(0.8) }
                      Text(syncMessage ?? "")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                  }
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 6)
                  .background(.bar)
              }
              TabView {
                  DashboardView()
                      .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                  ActivityListView()
                      .tabItem { Label("Activities", systemImage: "list.bullet") }
                  TracksPlaceholderView()
                      .tabItem { Label("Tracks", systemImage: "map") }
              }
          }
      }
  }

  struct LoginView: View {
      @Environment(AuthManager.self) private var authManager
      @State private var isAuthenticating = false
      @State private var errorMessage: String?

      var body: some View {
          VStack(spacing: 24) {
              Spacer()
              Image(systemName: "figure.run.circle.fill")
                  .font(.system(size: 80))
                  .foregroundStyle(.blue)
              Text("Polar MyFlow")
                  .font(.largeTitle.bold())
              Text("Connect your Polar account to view your training history.")
                  .multilineTextAlignment(.center)
                  .foregroundStyle(.secondary)
              if let error = errorMessage {
                  Text(error).foregroundStyle(.red).font(.caption)
              }
              Button {
                  Task {
                      isAuthenticating = true
                      errorMessage = nil
                      do { try await authManager.authenticate() }
                      catch { errorMessage = "Authentication failed. Please try again." }
                      isAuthenticating = false
                  }
              } label: {
                  if isAuthenticating {
                      ProgressView().frame(maxWidth: .infinity)
                  } else {
                      Text("Connect with Polar").frame(maxWidth: .infinity)
                  }
              }
              .buttonStyle(.borderedProminent)
              .disabled(isAuthenticating)
              .padding(.horizontal)
              Spacer()
          }
          .padding()
      }
  }
  ```

- [ ] **Step 3: Store userID after first auth**

  In `PolarMyFlow/Auth/AuthManager.swift`, after the token is stored in `authenticate()`, add a call to fetch and store the AccessLink user ID. For now, add a `setUserID` call after the coordinator registers. This wiring happens naturally: `SyncCoordinator.sync` calls `registerUser()` on the first launch and the returned ID should be stored. Add this to `AuthManager`:

  ```swift
  // Call this after sync to persist the user ID for future launches
  func setUserID(_ id: String) {
      currentUserID = id
  }
  ```

  Then in `PolarMyFlowApp.runSync`, after `coordinator.sync(userID:)`, call:

  ```swift
  if !state.historicalImportComplete {
      let resolvedID = try await accessLinkClient.registerUser()
      await authManager.setUserID(resolvedID)
  }
  ```

  Note: store `currentUserID` in `UserDefaults` so it persists across launches. Add to `AuthManager`:

  ```swift
  private let userIDKey = "polarflow.userID"

  func restoreSession() {
      guard let token = try? tokenStore.load() else { return }
      currentToken = token
      isAuthenticated = true
      currentUserID = UserDefaults.standard.string(forKey: userIDKey)
  }

  func setUserID(_ id: String) {
      currentUserID = id
      UserDefaults.standard.set(id, forKey: userIDKey)
  }
  ```

- [ ] **Step 4: Build and run in simulator**

  Cmd+R. The app should launch, show the Login screen (since no token is stored yet). After tapping "Connect with Polar", Polar's OAuth page opens in ASWebAuthenticationSession. After login, the tab bar appears and sync begins.

- [ ] **Step 5: Commit**

  ```bash
  git add PolarMyFlow/PolarMyFlowApp.swift \
          PolarMyFlow/ContentView.swift \
          PolarMyFlow/Auth/AuthManager.swift
  git commit -m "feat: wire SyncCoordinator to app launch with sync status banner"
  ```

---

## Self-Review Notes

- Task 8 (API discovery) must be completed before Task 9 (PolarFlowWebClient). JSON shapes in Task 9 tests are placeholders; update them to match discovered endpoints.
- `currentUserID` on first launch is unknown until AccessLink registers. SyncCoordinator handles this — the first sync path calls `registerUser()` and stores the result. Subsequent launches read from UserDefaults.
- The `SportDetailView` uses `navigationPath` push from `DashboardView`. The `selectedSport`/`selectedSeason` state in `DashboardView` is set before pushing — this is a one-way navigation and safe.
- `ActivityRowView` is shared between `ActivityListView` and `SportDetailView` — defined once in `ActivityList/` group and used from both.
