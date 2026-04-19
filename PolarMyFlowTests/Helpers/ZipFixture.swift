import Foundation
import ZIPFoundation

// Builds a fresh zip at a temp URL from a map of relative path → file bytes.
// Returns the URL of the created zip. Caller is responsible for cleanup.
enum ZipFixture {
    static func make(_ entries: [String: Data]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let zipURL = dir.appendingPathComponent("test.zip")

        let archive = try Archive(url: zipURL, accessMode: .create)
        for (path, data) in entries {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            }
        }
        return zipURL
    }

    static func session(
        startTime: String = "2025-01-15T09:00:00",
        durationMillis: Int = 5_400_000,
        sportId: String = "6",
        distanceMeters: Double = 15000
    ) -> Data {
        let json = """
        {
            "startTime": "\(startTime)",
            "durationMillis": \(durationMillis),
            "distanceMeters": \(distanceMeters),
            "calories": 500,
            "hrAvg": 140,
            "hrMax": 170,
            "sport": { "id": "\(sportId)" },
            "exercises": [{
                "ascentMeters": 100.0,
                "descentMeters": 95.0
            }]
        }
        """
        return json.data(using: .utf8)!
    }
}
