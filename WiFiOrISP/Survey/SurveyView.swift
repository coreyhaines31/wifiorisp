import SwiftUI
import WiFiOrISPCore

/// The room-by-room survey, shared with the `wifiorisp survey` command through one file.
@MainActor
final class SurveyModel: ObservableObject {
    struct Measuring: Equatable {
        var room: String
        var step: Int
    }

    @Published private(set) var survey = Survey()
    @Published private(set) var measuring: Measuring?
    @Published private(set) var error: String?

    private let store: SurveyStore

    init(store: SurveyStore = SurveyStore(url: SurveyStore.defaultURL)) {
        self.store = store
        reload()
    }

    /// Picks up readings the command took since the window was last shown.
    func reload() {
        do {
            survey = try store.load()
            error = nil
        } catch {
            self.error = "Couldn't read the saved survey. Start over to clear it."
        }
    }

    var canStartNextPass: Bool { survey.passes.last?.isEmpty == false }

    func measure(room: String) {
        let room = room.trimmingCharacters(in: .whitespaces)
        guard !room.isEmpty, measuring == nil else { return }
        error = nil
        measuring = Measuring(room: room, step: 1)
        Task {
            do {
                let reading = try await SurveyMeasurer.measure(room: room) { [weak self] step in
                    self?.measuring = Measuring(room: room, step: step)
                }
                // Read again: the command may have saved a reading while this one measured.
                var latest = try store.load()
                latest.record(reading)
                try store.save(latest)
                survey = latest
            } catch {
                self.error = (error as? SurveyError)?.message ?? error.localizedDescription
            }
            measuring = nil
        }
    }

    func startNextPass() {
        var next = survey
        guard next.startNextPass() else { return }
        save(next)
    }

    func startOver() {
        do {
            try store.reset()
            survey = Survey()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save(_ survey: Survey) {
        do {
            try store.save(survey)
            self.survey = survey
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SurveyView: View {
    @ObservedObject var model: SurveyModel
    @State private var room = ""
    @State private var confirmsStartOver = false

    private var rows: [SurveyRow] { model.survey.rows }
    private var compares: Bool { rows.contains { $0.previous != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            intro
            measureRow
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !rows.isEmpty {
                Divider()
                table
                summary
                actions
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Survey your rooms").font(.title3.bold())
            Text("Carry this Mac to a room, name it, and take a reading. After you change something, like moving "
                + "the router, start a second pass and take the readings again to see before and after.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var measureRow: some View {
        if let measuring = model.measuring {
            ProgressView(value: Double(measuring.step), total: Double(SurveyMeasurer.sampleCount)) {
                Text("Measuring \(measuring.room)…")
            }
        } else {
            HStack {
                TextField("Room name, like Kitchen", text: $room)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(measure)
                Button("Measure Here", action: measure)
                    .keyboardShortcut(.defaultAction)
                    .disabled(room.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var table: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
            GridRow {
                Text("Room")
                Text("Signal")
                Text("Link rate")
                Text("Router")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            ForEach(rows, id: \.room) { row in
                GridRow {
                    Text(row.room).fontWeight(.medium)
                    signal(row)
                    Text(SurveyCells.linkRate(row))
                    Text(SurveyCells.router(row))
                }
            }
        }
        .font(.callout)
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The signal, with the change in dB coloured once it's big enough to be real.
    private func signal(_ row: SurveyRow) -> some View {
        HStack(spacing: 6) {
            Text(SurveyCells.signal(row))
            if let change = row.signalChange {
                Text(change > 0 ? "+\(change)" : "\(change)")
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        abs(change) < SurveyText.meaningfulChange ? Color.secondary : (change > 0 ? .green : .red)
                    )
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            if compares, let text = SurveyText.summary(rows) {
                Text(text).font(.callout.weight(.medium))
            } else if let weakest = SurveyText.weakest(rows.compactMap(\.reading)) {
                Text("Weakest signal: \(weakest).").font(.callout.weight(.medium))
            }
            Text(SurveyText.linkRateNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        HStack {
            Button(model.survey.passes.count > 1 ? "Start Another Pass" : "Start Second Pass") {
                model.startNextPass()
            }
                .disabled(!model.canStartNextPass || model.measuring != nil)
                .help("After you change something, take every room's reading again to compare.")
            Spacer()
            Button("Start Over", role: .destructive) { confirmsStartOver = true }
                .disabled(model.measuring != nil)
                .confirmationDialog("Clear every room's readings?", isPresented: $confirmsStartOver) {
                    Button("Start Over", role: .destructive) { model.startOver() }
                }
        }
    }

    private func measure() {
        model.measure(room: room)
        room = ""
    }
}

/// The table's cells, as text.
enum SurveyCells {
    static func signal(_ row: SurveyRow) -> String {
        guard let previous = row.previous else {
            return row.reading.map { "\($0.signal) (\($0.rssi) dBm)" } ?? "–"
        }
        return "\(previous.rssi) → \(row.reading.map { "\($0.rssi)" } ?? "–") dBm"
    }

    static func linkRate(_ row: SurveyRow) -> String {
        let rate = { (reading: SurveyReading) in "\(Int(reading.linkRateMbps.rounded()))" }
        guard let previous = row.previous else { return row.reading.map { "\(rate($0)) Mbps" } ?? "–" }
        return "\(rate(previous)) → \(row.reading.map(rate) ?? "–") Mbps"
    }

    static func router(_ row: SurveyRow) -> String {
        let ms = { (reading: SurveyReading) in reading.routerMs.map { "\(Int($0.rounded()))" } ?? "–" }
        guard let previous = row.previous else {
            guard let reading = row.reading else { return "–" }
            return reading.routerMs.map { "\(PlainLanguage.router($0).rawValue) · \(Int($0.rounded())) ms" }
                ?? "No answer"
        }
        return "\(ms(previous)) → \(row.reading.map(ms) ?? "–") ms"
    }
}
