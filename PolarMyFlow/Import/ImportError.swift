import Foundation

enum ImportError: Error, LocalizedError {
    case invalidArchive
    case wrongFormat
    case cancelled
    case ioFailure(Error)

    var errorDescription: String? {
        switch self {
        case .invalidArchive: return "Not a valid Polar export."
        case .wrongFormat:    return "This doesn't look like a Polar data export."
        case .cancelled:      return "Import cancelled."
        case .ioFailure(let e): return "Import failed: \(e.localizedDescription)"
        }
    }
}
