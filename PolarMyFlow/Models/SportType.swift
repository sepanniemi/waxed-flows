import SwiftUI

enum SportType: String, Codable, CaseIterable, Equatable {
    case xcSkiing = "CROSS_COUNTRY_SKIING"
    case running = "RUNNING"
    case cycling = "CYCLING"
    case swimming = "SWIMMING"
    case hiking = "HIKING"
    case strength = "STRENGTH_TRAINING"
    case rowing = "ROWING"
    case mountainBiking = "MOUNTAIN_BIKING"
    case walking        = "WALKING"
    case other = "OTHER"

    init(polarString: String) {
        self = SportType(rawValue: polarString) ?? .other
    }

    static func from(polarSportId id: Int) -> SportType {
        switch id {
        case 1, 4:           return .running         // RUNNING, JOGGING
        case 2:              return .cycling
        case 3:              return .walking
        case 5:              return .mountainBiking
        case 6, 24, 25, 62:  return .xcSkiing        // CROSS-COUNTRY_SKIING, XC_SKIING_FREESTYLE, XC_SKIING_CLASSIC
        case 8:              return .rowing
        case 11:             return .hiking
        case 15:             return .strength
        case 23:             return .swimming
        default:             return .other
        }
    }

    var displayName: String {
        switch self {
        case .xcSkiing:
            return "XC Skiing"
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        case .hiking:
            return "Hiking"
        case .strength:
            return "Strength"
        case .rowing:
            return "Rowing"
        case .mountainBiking:
            return "Mountain Biking"
        case .walking:
            return "Walking"
        case .other:
            return "Other"
        }
    }

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
