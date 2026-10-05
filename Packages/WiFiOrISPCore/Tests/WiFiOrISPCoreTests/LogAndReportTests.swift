import Foundation
import Testing
@testable import WiFiOrISPCore

struct LogStoreTests {
    func makeStore() -> LogStore {
        LogStore(directory: FileManager.default.temporaryDirectory.appending(path: "wifiorisp-tests-\(UUID().uuidString)"))
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
        let file = try #require(FileManager.default.contentsOfDirectory(at: store.directory, includingPropertiesForKeys: nil).first)
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

struct ReportTests {
    @Test func countsOutagesAndWhichSide() {
        let events = [
            NetworkEvent(time: now.addingTimeInterval(-600), kind: .dropStarted),
            NetworkEvent(time: now.addingTimeInterval(-540), kind: .dropEnded(since: now.addingTimeInterval(-600), routerAnswered: true)),
            NetworkEvent(time: now.addingTimeInterval(-300), kind: .dropStarted),
            NetworkEvent(time: now.addingTimeInterval(-270), kind: .dropEnded(since: now.addingTimeInterval(-300), routerAnswered: false))
        ]
        let summary = ReportSummary(log: Log(samples: samples(), events: events), start: now.addingTimeInterval(-3600), end: now)
        #expect(summary.outages.count == 2)
        #expect(summary.ispOutages.count == 1)
        #expect(summary.totalDowntime(now: now) == 90)
    }

    @Test func anOpenDropIsOngoing() {
        let events = [NetworkEvent(time: now.addingTimeInterval(-60), kind: .dropStarted)]
        let summary = ReportSummary(log: Log(samples: samples(), events: events), start: now.addingTimeInterval(-3600), end: now)
        #expect(summary.outages == [.init(start: now.addingTimeInterval(-60), end: nil, routerAnswered: nil)])
        #expect(summary.totalDowntime(now: now) == 60)
    }

    @Test func sharesTimeBySide() {
        let slow = samples(12, internet: .reply(ms: 250))
        let summary = ReportSummary(log: Log(samples: slow), start: now.addingTimeInterval(-3600), end: now)
        #expect(summary.ispSlowShare > 0.5)
        #expect(summary.yourSideSlowShare == 0)
        #expect(summary.internetMedianMs == 250)
    }

    @Test func textMentionsTheISPSide() {
        let events = [
            NetworkEvent(time: now.addingTimeInterval(-600), kind: .dropStarted),
            NetworkEvent(time: now.addingTimeInterval(-540), kind: .dropEnded(since: now.addingTimeInterval(-600), routerAnswered: true))
        ]
        let text = ISPReport.text(
            log: Log(samples: samples(), events: events), start: now.addingTimeInterval(-3600), end: now,
            generated: now, timeZone: .gmt
        )
        #expect(text.contains("Outages: 1, 1 min in total."))
        #expect(text.contains("router answered throughout: ISP side"))
        #expect(text.contains("Typical round trip to my router: 3 ms."))
    }

    @Test func emptyPeriod() {
        let text = ISPReport.text(log: Log(), start: now.addingTimeInterval(-3600), end: now, generated: now, timeZone: .gmt)
        #expect(text.contains("No measurements were taken in this period."))
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
