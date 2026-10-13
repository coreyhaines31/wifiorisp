import Foundation
import Testing
@testable import WiFiOrISPCore

struct CLIArgumentsTests {
    @Test func noArgumentsShowsHelp() throws {
        #expect(try CLIArguments.parse([]) == .help)
        #expect(try CLIArguments.parse(["--help"]) == .help)
    }

    @Test func appCommandsTakeJSON() throws {
        #expect(try CLIArguments.parse(["status"]) == .app(.status, json: false))
        #expect(try CLIArguments.parse(["lag", "--json"]) == .app(.lag, json: true))
    }

    @Test func historyDefaultsToADay() throws {
        #expect(try CLIArguments.parse(["history"]) == .history(since: 86_400, format: .text))
        #expect(try CLIArguments.parse(["history", "--since", "1h30m", "--csv"]) == .history(since: 5400, format: .csv))
    }

    @Test func reportDefaultsToAWeek() throws {
        #expect(try CLIArguments.parse(["report"]) == .report(since: 7 * 86_400))
        #expect(try CLIArguments.parse(["report", "--since", "30d"]) == .report(since: 30 * 86_400))
    }

    @Test func rejectsWhatItDoesNotKnow() {
        #expect(throws: CLIArgumentError.self) { try CLIArguments.parse(["fix-it"]) }
        #expect(throws: CLIArgumentError.self) { try CLIArguments.parse(["status", "--since", "1h"]) }
        #expect(throws: CLIArgumentError.self) { try CLIArguments.parse(["history", "--json", "--csv"]) }
        #expect(throws: CLIArgumentError.self) { try CLIArguments.parse(["history", "--since"]) }
    }

    @Test func readsDurations() {
        #expect(CLIArguments.duration("90m") == 5400)
        #expect(CLIArguments.duration("2d") == 172_800)
        #expect(CLIArguments.duration("24") == nil)
        #expect(CLIArguments.duration("1x") == nil)
        #expect(CLIArguments.duration("0h") == nil)
    }
}

struct CLIStatusTests {
    func status(_ list: [Sample], provider: Provider? = nil, paused: Bool = false) -> CLIStatus {
        let context = AdviceContext(
            verdict: VerdictEngine.evaluate(list, now: now), latest: list.last, maker: .eero, provider: provider
        )
        return CLIStatus(context: context, networkName: "Home", paused: paused)
    }

    @Test func describesTheVerdictAndTheNumbers() {
        let status = status(samples(internet: .reply(ms: 186)), provider: Provider(asn: 7922))
        #expect(status.verdict.kind == "isp")
        #expect(status.verdict.side == "isp")
        #expect(status.verdict.problem)
        #expect(status.router == CLIStatus.Timing(ms: 3, rating: "Fast"))
        #expect(status.internet == CLIStatus.Timing(ms: 186, rating: "Slow"))
        #expect(status.wifi?.signal == "Excellent")
        #expect(status.wifi?.network == "Home")
        #expect(status.routerMaker == "eero")
        #expect(status.provider == "Xfinity")
    }

    @Test func nextStepsPointToPagesOrCommands() {
        let steps = status(samples(internet: .reply(ms: 186))).nextSteps
        #expect(steps.first?.url == "https://wifiorisp.com/slow-internet")
        #expect(steps.contains { $0.command == "wifiorisp speed" })
        #expect(steps.last?.command == "wifiorisp report")
    }

    @Test func noAdviceWhilePaused() {
        let status = status(samples(internet: .reply(ms: 186)), paused: true)
        #expect(status.nextSteps.isEmpty)
        #expect(CLIText.status(status).contains("Paused while a test runs."))
    }

    @Test func wiredHasNoWiFi() {
        let status = status(samples(link: .wired))
        #expect(status.wifi == nil)
        #expect(CLIText.status(status).contains("Network   Wired"))
    }

    @Test func encodesAsJSON() throws {
        let data = try CLIProtocol.encoder().encode(CLIMessage(status: status(samples())))
        let decoded = try CLIProtocol.decoder().decode(CLIMessage.self, from: data)
        #expect(decoded.status == status(samples()))
    }
}

struct CLITextTests {
    @Test func statusReadsLikeTheMenu() {
        let context = AdviceContext(verdict: VerdictEngine.evaluate(samples(), now: now), latest: samples().last)
        let text = CLIText.status(CLIStatus(context: context, networkName: nil, paused: false))
        #expect(text.hasPrefix("Fine: WiFi and ISP both OK\n"))
        #expect(text.contains("Router        Fast · 3 ms"))
        #expect(text.contains("Network       Unknown"))
        #expect(text.contains("run: wifiorisp lag"))
    }

    @Test func historyDescribesDrops() {
        let log = Log(samples: samples(), events: [
            NetworkEvent(time: now, kind: .dropStarted),
            NetworkEvent(time: now.addingTimeInterval(90), kind: .dropEnded(since: now, routerAnswered: true)),
            NetworkEvent(time: now.addingTimeInterval(200), kind: .dropStarted)
        ])
        let lines = CLIText.events(log.events).map(\.text)
        #expect(lines == [
            "Internet dropped for 1 min, 30 sec (router kept answering: ISP's side)",
            "Internet dropped, and hasn't come back yet"
        ])
        #expect(CLIText.history(log, start: now.addingTimeInterval(-3600), end: now).contains("What happened"))
    }

    @Test func emptyHistorySaysSo() {
        #expect(CLIText.history(Log(), start: now, end: now).hasPrefix("No measurements"))
    }
}
