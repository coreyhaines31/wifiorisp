import Foundation
import Testing
@testable import WiFiOrISPCore

struct UptimeTests {
    let day: TimeInterval = 86400

    func context(_ list: [Sample], awakeDays: Double, osMajor: Int = 26) -> AdviceContext {
        AdviceContext(
            verdict: VerdictEngine.evaluate(list, now: now), latest: list.last,
            uptime: UptimeCheck(awake: awakeDays * day, osMajor: osMajor)
        )
    }

    @Test func limitIsTwoToTheThirtySecondMilliseconds() {
        #expect(UptimeCheck.freezeAfter == Double(UInt64(1) << 32) / 1000)
    }

    @Test func stagesAroundTheLimit() {
        let limit = UptimeCheck.freezeAfter
        #expect(UptimeCheck(awake: 30 * day, osMajor: 26).stage == .fine)
        #expect(UptimeCheck(awake: limit - UptimeCheck.headsUp - 1, osMajor: 26).stage == .fine)
        #expect(UptimeCheck(awake: limit - UptimeCheck.headsUp, osMajor: 26).stage == .approaching)
        #expect(UptimeCheck(awake: limit - 1, osMajor: 26).stage == .approaching)
        #expect(UptimeCheck(awake: limit, osMajor: 26).stage == .past)
        #expect(UptimeCheck(awake: 120 * day, osMajor: 27).stage == .past)
    }

    @Test func olderMacOSIsNeverAffected() {
        #expect(UptimeCheck(awake: 200 * day, osMajor: 15).stage == .fine)
        #expect(Advice.uptimeNotice(context(samples(router: .lost, internet: .lost), awakeDays: 200, osMajor: 15))
            == nil)
    }

    @Test func daysReadPlainly() {
        #expect(UptimeCheck(awake: 0.5 * day, osMajor: 26).daysText == "less than a day")
        #expect(UptimeCheck(awake: 1.9 * day, osMajor: 26).daysText == "1 day")
        #expect(UptimeCheck(awake: 52.3 * day, osMajor: 26).daysText == "52 days")
    }

    @Test func pastTheLimitWithFailingProbesPutsRestartFirst() {
        let failing = context(samples(router: .lost, internet: .lost), awakeDays: 52)
        #expect(Advice.uptimeNotice(failing)?.tone == .cause)
        let first = Advice.steps(failing).first
        #expect(first?.title == "Restart your Mac: it's been on 52 days")
        #expect(first?.action == .page(UptimeNotice.guide))

        let slowISP = context(samples(internet: .reply(ms: 300)), awakeDays: 52)
        #expect(Advice.steps(slowISP).first?.action == .page(UptimeNotice.guide))
    }

    @Test func pastTheLimitButFineWarnsWithoutARestartStep() {
        let fine = context(samples(), awakeDays: 52)
        #expect(Advice.uptimeNotice(fine)?.tone == .warning)
        #expect(Advice.steps(fine).allSatisfy { $0.action != .page(UptimeNotice.guide) })
    }

    @Test func weakSignalIsNotBlamedOnUptime() {
        let weak = context(samples(rssi: -80, router: .reply(ms: 90)), awakeDays: 52)
        #expect(Advice.uptimeNotice(weak)?.tone == .warning)
        #expect(Advice.steps(weak).first?.title == "Move closer to the router, or into the same room")
    }

    @Test func approachingIsAHeadsUpOnly() {
        let failing = context(samples(router: .lost, internet: .lost), awakeDays: 46)
        #expect(Advice.uptimeNotice(failing)?.tone == .headsUp)
        #expect(Advice.steps(failing).first?.action != .page(UptimeNotice.guide))
    }

    @Test func freshRestartSaysNothing() {
        #expect(Advice.uptimeNotice(context(samples(router: .lost, internet: .lost), awakeDays: 3)) == nil)
    }

    @Test func statusCarriesUptimeForAgents() throws {
        let status = CLIStatus(context: context(samples(router: .lost, internet: .lost), awakeDays: 52.34),
                               networkName: "Home", paused: false)
        #expect(status.uptime?.awakeDays == 52.3)
        #expect(status.uptime?.stage == "past")
        #expect(status.uptime?.url == "https://wifiorisp.com" + UptimeNotice.guide)
        #expect(status.nextSteps.first?.url == "https://wifiorisp.com" + UptimeNotice.guide)
        let text = CLIText.status(status)
        #expect(text.contains("Uptime"))
        #expect(text.contains("52 days since the last restart"))
        #expect(text.contains("Restart your Mac first"))

        let fresh = CLIStatus(context: context(samples(), awakeDays: 3), networkName: nil, paused: false)
        #expect(fresh.uptime?.stage == "fine")
        #expect(fresh.uptime?.headline == nil)
        let json = try #require(String(bytes: CLIProtocol.encoder().encode(fresh), encoding: .utf8))
        #expect(json.contains("\"uptime\":{\"awakeDays\":3,\"stage\":\"fine\"}"))
    }

    @Test func reportNotesUptime() {
        let report = ISPReport.text(
            log: Log(samples: samples(), events: []), start: now.addingTimeInterval(-3600), end: now,
            uptime: UptimeCheck(awake: 52 * day, osMajor: 26)
        )
        #expect(report.contains("Mac running since its last restart: 52 days, not counting sleep"))
    }
}
