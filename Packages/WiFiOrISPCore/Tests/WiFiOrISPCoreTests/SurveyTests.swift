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
        #expect(survey.rows.map(\.room) == ["kitchen", "Office"])
        #expect(survey.rows[0].reading?.linkRateMbps == 300)
        #expect(survey.rows[0].previous == nil)
    }

    @Test func theNextPassIsComparedWithTheOneBefore() {
        var survey = Survey()
        survey.record(surveyReading("Kitchen", rate: 400))
        survey.record(surveyReading("Hallway", rate: 400))
        let started = survey.startNextPass()
        #expect(started)
        survey.record(surveyReading("Kitchen", rate: 700))
        survey.record(surveyReading("Garage", rate: 50))

        let rows = survey.rows
        #expect(rows.map(\.room) == ["Kitchen", "Hallway", "Garage"])
        #expect(rows[0].linkRateChange == 0.75)
        #expect(rows[1].reading == nil)
        #expect(rows[1].linkRateChange == nil)
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
        #expect(store.load().isEmpty)

        var survey = Survey()
        survey.record(surveyReading("Kitchen"))
        try store.save(survey)
        #expect(store.load() == survey)

        try store.reset()
        #expect(store.load().isEmpty)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
