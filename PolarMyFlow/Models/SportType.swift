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
        case 1:      return .running
        case 2:      return .cycling
        case 3:      return .walking
        case 4:      return .swimming
        case 5:      return .mountainBiking
        case 6, 62:  return .xcSkiing
        case 15:     return .strength
        case 17:     return .rowing
        default:     return .other
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

    var symbolName: String {
        switch self {
        case .xcSkiing:
            return "figure.skiing.crosscountry"
        case .running:
            return "figure.run"
        case .cycling:
            return "figure.outdoor.cycle"
        case .swimming:
            return "figure.pool.swim"
        case .hiking:
            return "figure.hiking"
        case .strength:
            return "dumbbell"
        case .rowing:
            return "figure.rowing"
        case .mountainBiking:
            return "figure.outdoor.cycle"
        case .walking:
            return "figure.walk"
        case .other:
            return "figure.mixed.cardio"
        }
    }
}
