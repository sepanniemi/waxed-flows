enum SportType: String, Codable, CaseIterable, Equatable {
    case xcSkiing = "CROSS_COUNTRY_SKIING"
    case running = "RUNNING"
    case cycling = "CYCLING"
    case swimming = "SWIMMING"
    case hiking = "HIKING"
    case strength = "STRENGTH_TRAINING"
    case rowing = "ROWING"
    case other = "OTHER"

    init(polarString: String) {
        self = SportType(rawValue: polarString) ?? .other
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
        case .other:
            return "figure.mixed.cardio"
        }
    }
}
