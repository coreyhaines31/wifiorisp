import Foundation
import Testing
@testable import WiFiOrISPCore

func surveyReading(_ room: String, rssi: Int = -55, rate: Double = 400, routerMs: Double? = 3) -> SurveyReading {
    SurveyReading(room: room, time: now, rssi: rssi, noise: -92, linkRateMbps: rate, band: .ghz5, channel: 36,
                  routerMs: routerMs)
}

struct SurveyReadingTests {
    func sample(rssi: Int, rate: Double, router: Probe?, link: Link = .wifi) -> Sample {
        Sample(
            time: now, link: link,
            wifi: WiFiReading(rssi: rssi, noise: -90, txRate: rate, channel: 149, band: .ghz5),
            router: router, internet: .reply(ms: 20)
        )
    }

    @Test func takesTheMedianOfTheSamples() throws {
        let reading = try #require(SurveyReading(room: "Kitchen", samples: [
            sample(rssi: -60, rate: 400, router: .reply(ms: 4)),
            sample(rssi: -80, rate: 100, router: .reply(ms: 90)),
            sample(rssi: -62, rate: 433, router: .reply(ms: 6))
        ]))
        #expect(reading.rssi == -62)
        #expect(reading.linkRateMbps == 400)
        #expect(reading.routerMs == 6)
        #expect(reading.channel == 149)
        #expect(reading.signal == "Good")
    }

    @Test func aRouterThatMostlyDoesNotAnswerHasNoTiming() throws {
        let reading = try #require(SurveyReading(room: "Attic", samples: [
            sample(rssi: -80, rate: 50, router: .lost),
            sample(rssi: -80, rate: 50, router: .lost),
            sample(rssi: -80, rate: 50, router: .reply(ms: 30))
        ]))
        #expect(reading.routerMs == nil)
    }

    @Test func needsWiFi() {
        #expect(SurveyReading(room: "Desk", samples: [Sample(time: now, link: .wired)]) == nil)
        #expect(SurveyReading(room: "Desk", samples: []) == nil)
    }
}

struct SurveyTests {
    @Test func aSecondReadingForARoomReplacesTheFirst() {
        var survey = Survey()
        survey.record(surveyReading("Kitchen", rate: 100))
        survey.record(surveyReading("Office"))
        survey.record(surveyReading("kitchen", rate: 300))
        #expect(survey.rows.map(\.room) == ["Kitchen", "Office"])
        #expect(survey.rows[0].reading?.linkRateMbps == 300)
        #expect(survey.rows[0].previous == nil)
    }

    @Test func theNextPassIsComparedWithTheOneBefore() {
        var survey = Survey()
        survey.record(surveyReading("Kitchen", rssi: -70))
        survey.record(surveyReading("Hallway"))
        let started = survey.startNextPass()
        #expect(started)
        survey.record(surveyReading("kitchen", rssi: -58))
        survey.record(surveyReading("Garage", rate: 50))

        let rows = survey.rows
        #expect(rows.map(\.room) == ["Kitchen", "Hallway", "Garage"])
        #expect(rows[0].signalChange == 12)
        #expect(rows[1].reading == nil)
        #expect(rows[1].signalChange == nil)
        #expect(rows[2].previous == nil)
    }

    @Test func anEmptyPassCannotBeFollowedByAnother() {
        var survey = Survey()
        let empty = survey.startNextPass()
        survey.record(surveyReading("Kitchen"))
        let second = survey.startNextPass()
        let third = survey.startNextPass()
        #expect([empty, second, third] == [false, true, false])
    }

    @Test func savesAndLoads() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "survey-\(UUID().uuidString)/survey.json")
        let store = SurveyStore(url: url)
        #expect(try store.load().isEmpty)

        var survey = Survey()
        survey.record(surveyReading("Kitchen"))
        try store.save(survey)
        #expect(try store.load() == survey)

        try store.reset()
        #expect(try store.load().isEmpty)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test func aFileThatCannotBeReadIsNotTreatedAsEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "survey-\(UUID().uuidString).json")
        try Data("{ not a survey".utf8).write(to: url)
        #expect(throws: (any Error).self) { try SurveyStore(url: url).load() }
        try? FileManager.default.removeItem(at: url)
    }
}

struct SurveyTextTests {
    func twoPasses() -> Survey {
        var survey = Survey()
        survey.record(surveyReading("Kitchen", rssi: -70, rate: 408, routerMs: 9))
        survey.record(surveyReading("Hallway", rssi: -60, rate: 433, routerMs: 4))
        survey.record(surveyReading("Office", rssi: -50, rate: 816))
        _ = survey.startNextPass()
        survey.record(surveyReading("Kitchen", rssi: -58, rate: 720, routerMs: 4))
        survey.record(surveyReading("Hallway", rssi: -72, rate: 229, routerMs: nil))
        return survey
    }

    @Test func anEmptySurveySaysHowToStart() {
        #expect(SurveyText.table(Survey()).contains("wifiorisp survey room"))
    }

    @Test func onePassListsEveryRoomAndTheWeakest() {
        var survey = Survey()
        survey.record(surveyReading("Kitchen", rssi: -58, rate: 720, routerMs: 4))
        survey.record(surveyReading("Hallway", rssi: -79, rate: 229, routerMs: nil))
        let lines = SurveyText.table(survey).components(separatedBy: "\n")
        #expect(lines[0] == "Room      Signal           Link rate   Router")
        #expect(lines[1] == "Kitchen   Good (-58 dBm)   720 Mbps    Fast · 4 ms")
        #expect(lines[2] == "Hallway   Weak (-79 dBm)   229 Mbps    No answer")
        #expect(lines.contains("Weakest signal: Hallway."))
        #expect(lines.last?.contains("wifiorisp survey again") == true)
    }

    @Test func twoPassesShowBeforeAndAfter() {
        let lines = SurveyText.table(twoPasses()).components(separatedBy: "\n")
        #expect(lines[1] == "Kitchen   -70 → -58 dBm (+12)   408 → 720 Mbps   9 → 4 ms")
        #expect(lines[2] == "Hallway   -60 → -72 dBm (-12)   433 → 229 Mbps   4 → – ms")
        #expect(lines[3] == "Office    -50 → – dBm           816 → – Mbps     3 → – ms")
        #expect(lines.contains("Stronger signal in 1 of 2 rooms. Weaker in: Hallway."))
        #expect(lines.contains("Not measured again yet: Office."))
        #expect(!lines.contains { $0.contains("wifiorisp survey again") })
    }

    @Test func aWobbleOfADecibelOrTwoIsNotAChange() {
        var survey = Survey()
        survey.record(surveyReading("Kitchen", rssi: -58, rate: 1152))
        survey.record(surveyReading("Office", rssi: -59, rate: 864))
        #expect(!SurveyText.table(survey).contains("Weakest"))
        _ = survey.startNextPass()
        survey.record(surveyReading("Kitchen", rssi: -60, rate: 864))
        #expect(SurveyText.table(survey).contains("Stronger signal in 0 of 1 room.\n"))
    }

    @Test func roomNamesWithEmojiKeepTheirWholeName() {
        var survey = Survey()
        survey.record(surveyReading("👨‍👩‍👧 den", rssi: -58, rate: 720, routerMs: 4))
        survey.record(surveyReading("Hall", rssi: -58, rate: 720, routerMs: 4))
        let lines = SurveyText.table(survey).components(separatedBy: "\n")
        #expect(lines[1].hasPrefix("👨‍👩‍👧 den   Good"))
        #expect(lines[2].hasPrefix("Hall    Good"))
    }

    @Test func aPassJustStartedCountsInTheJSON() {
        var survey = Survey()
        survey.record(surveyReading("Kitchen"))
        _ = survey.startNextPass()
        let json = CLISurvey(survey)
        #expect(json.passes == 2)
        #expect(json.rooms[0].previous != nil)
        #expect(json.rooms[0].reading == nil)
    }

    @Test func readingIsOneLine() {
        #expect(SurveyText.reading(surveyReading("Kitchen", rssi: -58, rate: 720, routerMs: 4))
            == "Kitchen: Good signal (-58 dBm), link rate 720 Mbps, router Fast · 4 ms")
    }

    @Test func jsonCarriesBothPasses() {
        let json = CLISurvey(twoPasses())
        #expect(json.passes == 2)
        #expect(json.rooms.map(\.room) == ["Kitchen", "Hallway", "Office"])
        #expect(json.rooms[0].signalChangeDB == 12)
        #expect(json.rooms[0].previous?.linkRateMbps == 408)
        #expect(json.rooms[2].reading == nil)
        #expect(json.weakest == "Hallway")
    }
}
