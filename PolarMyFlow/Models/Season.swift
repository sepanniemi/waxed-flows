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
