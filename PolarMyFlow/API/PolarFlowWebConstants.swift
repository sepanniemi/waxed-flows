// IMPORTANT: These are internal Polar Flow web API endpoints.
// They are undocumented and may change without notice.
// Discovered by inspecting flow.polar.com network traffic on 2026-04-13.

enum PolarFlowWebConstants {
    static let baseURL = "https://flow.polar.com"
    static let historyPath = "/api/training/history"

    // Auth: cookie-based. Session cookies from the shared iOS web session
    // (WKWebsiteDataStore.default()) contain FLOW_SESSION and PLAY_SESSION_FLOW.

    // Date format used in API responses ("2026-04-05 10:12:28.447")
    static let responseDateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

    // Fetch full history in 1-year chunks from this start year
    static let historyStartYear = 2010
}
