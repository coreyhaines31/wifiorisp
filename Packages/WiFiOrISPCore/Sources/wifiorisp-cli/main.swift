import Foundation
import WiFiOrISPCore

// Development tool: `swift run wifiorisp-cli [samples|speed|rpm]`.
let command = CommandLine.arguments.dropFirst().first ?? "samples"

@MainActor
func takeSamples() async {
    let sampler = Sampler()
    var history: [Sample] = []
    for _ in 0..<6 {
        let result = await sampler.sample()
        history.append(result.sample)
        let sample = result.sample
        let wifi = sample.wifi.map { "\($0.rssi) dBm, noise \($0.noise), \($0.txRate) Mbps, ch \($0.channel ?? 0) \($0.band?.label ?? "?")" }
        print("\(sample.link) | \(wifi ?? "no wifi") | router \(String(describing: sample.router)) | internet \(String(describing: sample.internet))")
        try? await Task.sleep(for: .seconds(2))
    }
    let verdict = VerdictEngine.evaluate(history, now: Date())
    print("\n\(verdict.headline)\n\(verdict.detail)")
}

switch command {
default:
    await takeSamples()
}
