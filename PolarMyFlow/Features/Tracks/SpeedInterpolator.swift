/// Fills nil gaps in a per-point speed series so every point has a real-derived
/// value. Interior gaps are linearly interpolated between the nearest known
/// values; leading/trailing gaps take the nearest known value. Returns an empty
/// array when no value is known (caller then falls back to a flat color).
enum SpeedInterpolator {
    static func fill(_ speeds: [Double?]) -> [Double] {
        let knownIndices = speeds.indices.filter { speeds[$0] != nil }
        guard let first = knownIndices.first, let last = knownIndices.last else {
            return []   // all-nil or empty input
        }

        var result = [Double](repeating: 0, count: speeds.count)

        // Leading gap → first known value; trailing gap → last known value.
        let firstValue = speeds[first]!
        for i in 0..<first { result[i] = firstValue }
        let lastValue = speeds[last]!
        for i in (last + 1)..<speeds.count { result[i] = lastValue }

        // Known points copy through; interior gaps interpolate linearly by index.
        result[first] = firstValue
        var prevKnown = first
        for k in knownIndices.dropFirst() {
            result[k] = speeds[k]!
            let gap = k - prevKnown
            if gap > 1 {
                let lo = speeds[prevKnown]!
                let hi = speeds[k]!
                for j in (prevKnown + 1)..<k {
                    let t = Double(j - prevKnown) / Double(gap)
                    result[j] = lo + (hi - lo) * t
                }
            }
            prevKnown = k
        }
        return result
    }
}
