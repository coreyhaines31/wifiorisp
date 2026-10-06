import Foundation

/// Small order statistics. Every function returns nil for an empty input.
public enum Statistics {
    public static func median(_ values: [Double]) -> Double? {
        percentile(values, 0.5)
    }

    /// Linear interpolation between closest ranks, `fraction` in 0...1.
    public static func percentile(_ values: [Double], _ fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let position = Double(sorted.count - 1) * min(max(fraction, 0), 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        let weight = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * weight
    }

    /// The mean after dropping values above the given percentile (single-sided), as the
    /// IETF responsiveness draft specifies with 95.
    public static func trimmedMean(_ values: [Double], keepingBelow fraction: Double = 0.95) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let kept = sorted.prefix(max(1, Int((Double(sorted.count) * fraction).rounded(.up))))
        return kept.reduce(0, +) / Double(kept.count)
    }
}
