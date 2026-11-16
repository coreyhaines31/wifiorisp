import Testing
@testable import WiFiOrISPCore

struct GaugeScaleTests {
    @Test func quickReadingsSitWellIntoFast() {
        #expect(GaugeScale.position(4, side: .router) > 0.75)
        #expect(GaugeScale.position(11, side: .internet) > 0.75)
    }

    @Test func zoneEdgesAreTheReadingThresholds() {
        #expect(abs(GaugeScale.position(PlainLanguage.fastRouterMs, side: .router) - GaugeScale.fastEdge) < 1e-9)
        #expect(abs(GaugeScale.position(VerdictEngine.slowRouterMs, side: .router) - GaugeScale.slowEdge) < 1e-9)
        #expect(abs(GaugeScale.position(PlainLanguage.fastInternetMs, side: .internet) - GaugeScale.fastEdge) < 1e-9)
        #expect(abs(GaugeScale.position(PlainLanguage.slowInternetMs, side: .internet) - GaugeScale.slowEdge) < 1e-9)
    }

    /// The needle's zone always matches the word the readings show.
    @Test(arguments: [GaugeScale.Side.router, .internet])
    func zoneMatchesTheWord(side: GaugeScale.Side) {
        let rate = side == .router ? PlainLanguage.router : PlainLanguage.internet
        for ms in stride(from: 0.5, through: 600, by: 0.5) {
            let position = GaugeScale.position(ms, side: side)
            switch rate(ms) {
            case .fast: #expect(position >= GaugeScale.fastEdge, "\(ms) ms")
            case .okay: #expect(position < GaugeScale.fastEdge && position >= GaugeScale.slowEdge, "\(ms) ms")
            case .slow: #expect(position < GaugeScale.slowEdge, "\(ms) ms")
            }
        }
    }

    @Test func slowerIsAlwaysLower() {
        var last = 2.0
        for ms in stride(from: 0.0, through: 600, by: 1) {
            let position = GaugeScale.position(ms, side: .internet)
            #expect(position <= last)
            last = position
        }
    }

    @Test func pinsAtTheStops() {
        #expect(GaugeScale.position(0.1, side: .router) == 1)
        #expect(GaugeScale.position(900, side: .internet) == 0)
        #expect(GaugeScale.position(.lost, side: .router) < 0)
        #expect(GaugeScale.position(nil, side: .router) == 0)
    }
}
