enum BuildConfig {
    #if DEBUG
    static let clientID     = "4b330ffa-0cc6-474f-92a9-f833d1c55d2a"
    static let clientSecret = "19330628-94ec-4ffe-b052-02a9c8750f07"
    /// Limit history fetch to last N days in debug to avoid loading full history in simulator
    static let historyLookbackDays: Int? = 90
    #else
    static let clientID     = "c045142a-470a-4d0c-8f44-b8aa1200e975"
    static let clientSecret = "59ccbd6e-aaae-4881-b121-a3b7774ff03b"
    /// Full history from 2010 on real device
    static let historyLookbackDays: Int? = nil
    #endif
}
