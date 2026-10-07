import Foundation
import WiFiOrISPCore

// Development tool: `swift run wifiorisp-cli [samples|speed|rpm|report|identify]`.
let command = CommandLine.arguments.dropFirst().first ?? "samples"

@MainActor
func takeSamples() async {
    let sampler = Sampler()
    var history: [Sample] = []
    for _ in 0..<6 {
        let result = await sampler.sample()
        history.append(result.sample)
        let sample = result.sample
        let wifi = sample.wifi.map { "\($0.rssi) dBm, noise \($0.noise), \($0.band?.label ?? "?")" }
        let router = String(describing: sample.router)
        let internet = String(describing: sample.internet)
        print("\(sample.link) | \(wifi ?? "no wifi") | router \(router) | internet \(internet)")
        try? await Task.sleep(for: .seconds(2))
    }
    let verdict = VerdictEngine.evaluate(history, now: Date())
    print("\n\(verdict.headline)\n\(verdict.detail)")
}

func speedTest() async {
    do {
        let result = try await NDT7Client(clientVersion: "dev").run { phase, mbps in
            print("\(phase) \(Int(mbps)) Mbps")
        }
        print(result)
    } catch {
        print("failed: \(error.localizedDescription)")
    }
}

func responsiveness() async {
    let route = Route.current()
    let config = ProcessInfo.processInfo.environment["RPM_CONFIG"].flatMap(URL.init(string:))
        ?? ResponsivenessTest.defaultConfigURL
    let test = ResponsivenessTest(configURL: config) {
        guard let router = route?.router else { return nil }
        return await TCPProbe.roundTrip(to: router, port: 53)
    }
    do {
        let result = try await test.run { phase, fraction in print("\(phase.rawValue) \(Int(fraction * 100))%") }
        print(result)
        print("\(result.headline)\n\(result.detail)")
    } catch {
        print("failed: \(error.localizedDescription)")
    }
}

func report() {
    let end = Date()
    let start = end.addingTimeInterval(-86400)
    let log = LogStore(directory: LogStore.defaultDirectory).load(from: start, to: end)
    print(ISPReport.text(log: log, start: start, end: end))
}

@MainActor
func identify() async {
    let reader = WiFiReader()
    let router = Route.current()?.router
    let mac = router.flatMap(GatewayHardware.macAddress(of:))
    print("router \(router ?? "?") mac \(mac ?? "?") maker \(mac.flatMap(RouterMaker.lookup)?.name ?? "unknown")")
    if case .reading(let wifi) = reader.read() {
        let generation = wifi.generationLabel ?? "?"
        print("wifi \(generation) \(wifi.widthMHz ?? 0) MHz, Mac supports 6 GHz: \(reader.supports6GHz)")
    }
    let provider = await Provider.detect()
    print("provider ASN \(provider?.asn ?? 0) \(provider?.name ?? "not in the known list")")
}

switch command {
case "identify":
    await identify()
case "report":
    report()
case "speed":
    await speedTest()
case "rpm":
    await responsiveness()
default:
    await takeSamples()
}
