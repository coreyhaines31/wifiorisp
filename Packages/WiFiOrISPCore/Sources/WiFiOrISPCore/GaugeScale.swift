import Foundation

/// Where a gauge needle sits for a reading, on a face marked SLOW · OK · FAST from left to right.
///
/// The zone edges are the thresholds `PlainLanguage` uses for Fast, OK and Slow, so the needle and
/// the reading's word always agree. Within each zone the scale is logarithmic: a few ms either way
/// matters near zero and hardly at all past the slow edge, so quick readings swing well into FAST.
public enum GaugeScale {
    public enum Side: Sendable {
        case router, internet
    }

    /// Where the SLOW zone ends on the face (0 is the left stop, 1 the right stop).
    public static let slowEdge = 0.25
    /// Where the FAST zone starts on the face.
    public static let fastEdge = 0.5
    /// Past the left stop, for a probe that got no answer.
    public static let noAnswer = -0.02

    /// The ms that land on each mark of the face for one side.
    struct Scale {
        /// Pins the needle at the right stop.
        var best: Double
        /// The fast edge.
        var fast: Double
        /// The slow edge.
        var slow: Double
        /// Pins the needle at the left stop.
        var worst: Double
    }

    static func scale(_ side: Side) -> Scale {
        switch side {
        case .router:
            Scale(best: 2, fast: PlainLanguage.fastRouterMs, slow: VerdictEngine.slowRouterMs, worst: 200)
        case .internet:
            Scale(best: 5, fast: PlainLanguage.fastInternetMs, slow: PlainLanguage.slowInternetMs, worst: 500)
        }
    }

    /// Needle position for a round trip of `ms`, 0...1.
    public static func position(_ ms: Double, side: Side) -> Double {
        let scale = scale(side)
        let ms = min(max(ms, scale.best), scale.worst)
        if ms <= scale.fast { return interpolate(ms, scale.best, scale.fast, 1, fastEdge) }
        if ms <= scale.slow { return interpolate(ms, scale.fast, scale.slow, fastEdge, slowEdge) }
        return interpolate(ms, scale.slow, scale.worst, slowEdge, 0)
    }

    /// Needle position for a probe: no answer sits past the left stop, no measurement at rest.
    public static func position(_ probe: Probe?, side: Side) -> Double {
        switch probe {
        case .reply(let ms): position(ms, side: side)
        case .lost: noAnswer
        case nil: 0
        }
    }

    /// Log-scale interpolation of `ms` between two ms marks onto two face positions.
    private static func interpolate(
        _ ms: Double, _ from: Double, _ to: Double, _ start: Double, _ end: Double
    ) -> Double {
        let share = log(ms / from) / log(to / from)
        return start + (end - start) * share
    }
}
