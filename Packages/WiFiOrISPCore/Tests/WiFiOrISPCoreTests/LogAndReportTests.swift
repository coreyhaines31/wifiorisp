import Foundation
import Testing
@testable import WiFiOrISPCore

struct LogStoreTests {
    func makeStore() -> LogStore {
        LogStore(directory: FileManager.default.temporaryDirectory.appending(path: "wifiorisp-\(UUID().uuidString)"))
    }

    @Test func roundTripsSamplesAndEvents() throws {
        let store = makeStore()
        defer { store.deleteAll() }
        let list = samples()
        for sample in list {
            try store.append(sample)
        }
        let event = NetworkEvent(time: now, kind: .dropEnded(since: now.addingTimeInterval(-30), routerAnswered: true))
        try store.append(event)

        let log = store.load(from: now.addingTimeInterval(-3600), to: now)
        #expect(log.samples.count == list.count)
        #expect(log.samples.last?.internet == .reply(ms: 20))
        #expect(log.events == [event])
    }

    @Test func loadsOnlyTheRange() throws {
        let store = makeStore()
        defer { store.deleteAll() }
        try store.append(Sample(time: now.addingTimeInterval(-86400 * 2), link: .wired))
        try store.append(Sample(time: now, link: .wired))
        #expect(store.load(from: now.addingTimeInterval(-3600), to: now).samples.count == 1)
        #expect(store.load(from: now.addingTimeInterval(-86400 * 3), to: now).samples.count == 2)
    }

    @Test func skipsBrokenLines() throws {
        let store = makeStore()
        defer { store.deleteAll() }
        try store.append(Sample(time: now, link: .wired))
        let files = try FileManager.default.contentsOfDirectory(at: store.directory, includingPropertiesForKeys: nil)
        let file = try #require(files.first)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"s\":{\"t\":12".utf8))
        try handle.close()
        #expect(store.load(from: now.addingTimeInterval(-60), to: now).samples.count == 1)
    }

    @Test func prunesOldDays() throws {
        let store = makeStore()
        defer { store.deleteAll() }
        try store.append(Sample(time: now.addingTimeInterval(-86400 * 40), link: .wired))
        try store.append(Sample(time: now, link: .wired))
        store.prune(keepingDays: 30, now: now)
        let files = try FileManager.default.contentsOfDirectory(at: store.directory, includingPropertiesForKeys: nil)
        #expect(files.count == 1)
    }
}

func drop(from start: Double, to end: Double, routerAnswered: Bool?) -> [NetworkEvent] {
    [
        NetworkEvent(time: now.addingTimeInterval(start), kind: .dropStarted),
        NetworkEvent(
            time: now.addingTimeInterval(end),
            kind: .dropEnded(since: now.addingTimeInterval(start), routerAnswered: routerAnswered)
        )
    ]
}

let lastHour = now.addingTimeInterval(-3600)

struct ReportTests {
    @Test func countsOutagesAndWhichSide() {
        let events = drop(from: -600, to: -540, routerAnswered: true)
            + drop(from: -300, to: -270, routerAnswered: false)
        let summary = ReportSummary(log: Log(samples: samples(), events: events), start: lastHour, end: now)
        #expect(summary.outages.count == 2)
        #expect(summary.ispOutages.count == 1)
        #expect(summary.totalDowntime(now: now) == 90)
    }

    @Test func anUnendedDropEndsWhenTheInternetAnswersAgain() {
        // samples() answer every 10 s up to `now`; the drop started at -60.
        let events = [NetworkEvent(time: now.addingTimeInterval(-60), kind: .dropStarted)]
        let summary = ReportSummary(log: Log(samples: samples(), events: events), start: lastHour, end: now)
        let expected = ReportSummary.Outage(
            start: now.addingTimeInterval(-60), end: now.addingTimeInterval(-50), routerAnswered: nil
        )
        #expect(summary.outages == [expected])
    }

    @Test func anUnendedDropStopsAtTheLastMeasurement() {
        // Down until the app quit at -40; the report runs to `now`.
        let down = samples(3, internet: .lost, now: now.addingTimeInterval(-40))
        let events = [NetworkEvent(time: now.addingTimeInterval(-60), kind: .dropStarted)]
        let summary = ReportSummary(log: Log(samples: down, events: events), start: lastHour, end: now)
        #expect(summary.totalDowntime(now: now) == 20)
    }

    @Test func aSecondStartClosesAnUnendedDrop() {
        let events = [
            NetworkEvent(time: now.addingTimeInterval(-600), kind: .dropStarted),
            NetworkEvent(time: now.addingTimeInterval(-60), kind: .dropStarted)
        ]
        let summary = ReportSummary(log: Log(events: events), start: lastHour, end: now)
        #expect(summary.outages.count == 2)
        #expect(summary.outages[0].end == now.addingTimeInterval(-60))
    }

    @Test func sharesTimeBySide() {
        let slow = samples(12, internet: .reply(ms: 250))
        let summary = ReportSummary(log: Log(samples: slow), start: now.addingTimeInterval(-3600), end: now)
        #expect(summary.ispSlowShare > 0.5)
        #expect(summary.yourSideSlowShare == 0)
        #expect(summary.internetMedianMs == 250)
    }

    @Test func textMentionsTheISPSide() {
        let events = drop(from: -600, to: -540, routerAnswered: true)
        let text = ISPReport.text(
            log: Log(samples: samples(), events: events), start: now.addingTimeInterval(-3600), end: now,
            generated: now, timeZone: .gmt
        )
        #expect(text.contains("Outages: 1, 1 min in total."))
        #expect(text.contains("router answered throughout: ISP side"))
        #expect(text.contains("Typical round trip to my router: 3 ms."))
    }

    @Test func emptyPeriod() {
        let text = ISPReport.text(log: Log(), start: lastHour, end: now, generated: now, timeZone: .gmt)
        #expect(text.contains("No measurements were taken in this period."))
    }

    @Test func comparesSpeedTestsWithThePlan() {
        let test = SpeedTestResult(time: now, downloadMbps: 250, uploadMbps: 10, minRTTms: nil, server: "x")
        let log = Log(samples: samples(), events: [NetworkEvent(time: now, kind: .speedTest(test))])
        let text = ISPReport.text(
            log: log, start: lastHour, end: now, generated: now, timeZone: .gmt, plan: Plan(downMbps: 500, upMbps: 20)
        )
        #expect(text.contains("I pay for 500 Mbps down and 20 Mbps up."))
        #expect(text.contains("typically 250 Mbps down (50% of the plan) and 10 Mbps up (50%)"))
    }

    @Test func saysNoneWithoutOutages() {
        let log = Log(samples: samples())
        let text = ISPReport.text(log: log, start: lastHour, end: now, generated: now, timeZone: .gmt)
        #expect(text.contains("- Outages: none."))
    }
}

struct SampleCSVTests {
    @Test func writesOneRowPerSample() {
        var sample = samples(1)[0]
        sample.wifi?.ssid = "Home, Upstairs"
        sample.router = .lost
        let lines = SampleCSV.text([sample]).split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[1].contains("wifi,\"Home, Upstairs\","))
        #expect(lines[1].hasSuffix(",,1,20.0,0"))
    }
}

struct TimelineTests {
    @Test func bucketsSamples() {
        var list = samples(12, router: .reply(ms: 4))
        list[11].internet = .lost
        list[10].wifi?.rssi = -70
        let points = Timeline.points(list, from: now.addingTimeInterval(-120), to: now, buckets: 2)
        #expect(points.count == 2)
        #expect(points[0].routerMs == 4)
        #expect(points[1].rssi == -70)
        #expect(points[1].internetLoss > 0)
        #expect(points[0].internetLoss == 0)
    }

    @Test func emptyRange() {
        #expect(Timeline.points(samples(), from: now, to: now).isEmpty)
    }

    @Test func neutralizesFormulas() {
        #expect(SampleCSV.escape("=HYPERLINK(1)") == "'=HYPERLINK(1)")
        #expect(SampleCSV.escape("Home") == "Home")
    }
}
