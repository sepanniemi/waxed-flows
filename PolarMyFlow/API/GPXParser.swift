import Foundation

// Parses Polar AccessLink GPX track responses into [RoutePoint].
// Expected structure: <gpx><trk><trkseg><trkpt lat="..." lon="..."><ele>X</ele><time>ISO8601</time></trkpt>...
enum GPXParser {
    static func parse(_ data: Data) -> [RoutePoint] {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.points
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var points: [RoutePoint] = []

        private var startTime: Date?
        private var pendingLat: Double?
        private var pendingLon: Double?
        private var pendingEle: Double?
        private var pendingTime: Date?
        private var currentText = ""

        private static let iso: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        private static let isoNoFrac: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {
            currentText = ""
            if elementName == "trkpt" {
                pendingLat = attributeDict["lat"].flatMap(Double.init)
                pendingLon = attributeDict["lon"].flatMap(Double.init)
                pendingEle = nil
                pendingTime = nil
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName {
            case "ele":
                pendingEle = Double(trimmed)
            case "time":
                pendingTime = Self.iso.date(from: trimmed) ?? Self.isoNoFrac.date(from: trimmed)
            case "trkpt":
                guard let lat = pendingLat, let lon = pendingLon, let time = pendingTime else { return }
                if startTime == nil { startTime = time }
                let elapsed = Int(time.timeIntervalSince(startTime!) * 1000)
                points.append(RoutePoint(latitude: lat, longitude: lon,
                                         altitude: pendingEle ?? 0,
                                         elapsedMillis: elapsed,
                                         speedKmh: nil))
            default:
                break
            }
            currentText = ""
        }
    }
}
