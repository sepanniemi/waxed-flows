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
