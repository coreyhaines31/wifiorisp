import Foundation
import UserNotifications
import WiFiOrISPCore

/// Posts alerts for drops, falling to 2.4 GHz, and roaming to a weaker access point.
@MainActor
final class Notifier {
    /// Don't repeat the same kind of alert more often than this.
    private static let quietPeriod: TimeInterval = 300

    private var lastPosted: [AlertKind: Date] = [:]
    private var announcedDrop = false

    func handle(_ event: NetworkEvent, latest: Sample?) {
        guard let kind = event.alertKind, Preferences.alerts(for: kind) else { return }
        switch event.kind {
        case .dropStarted:
            // Turning Wi-Fi off isn't worth an alert.
            guard latest?.link != NetworkLink.none, allowed(kind, at: event.time) else { return }
            dropStarted(router: latest?.router)
        case .dropEnded(_, let routerAnswered):
            dropEnded(after: event.dropDuration ?? 0, routerAnswered: routerAnswered)
        case .bandChanged:
            guard allowed(kind, at: event.time) else { return }
            let network = latest?.wifi?.ssid.map { " on “\($0)”" } ?? ""
            post(
                title: "Switched to 2.4 GHz",
                body: "Your Mac moved to the slower 2.4 GHz band\(network). "
                    + "Moving closer to the router usually brings 5 GHz back."
            )
        case .roamed(_, _, let from, let to):
            guard allowed(kind, at: event.time) else { return }
            post(
                title: "Roamed to a weaker access point",
                body: "Your Mac switched to an access point with a weaker signal (\(Self.signalWord(from)) to "
                    + "\(Self.signalWord(to))). Turning Wi-Fi off and on can move you back to a closer one."
            )
        default:
            break
        }
    }

    private func dropStarted(router: Probe?) {
        announcedDrop = true
        let body = switch router {
        case .reply: "Your router is still answering, so the outage is past it: your ISP's side."
        case .lost: "Your router isn't answering either, so it's your Wi-Fi or router."
        case nil: "Nothing on the internet is answering."
        }
        post(title: "Internet dropped", body: body)
    }

    private func dropEnded(after seconds: TimeInterval, routerAnswered: Bool?) {
        guard announcedDrop else { return }
        announcedDrop = false
        let duration = Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, maximumUnitCount: 2))
        let side = routerAnswered == true ? " Your router answered throughout, so it was the ISP." : ""
        post(title: "Back online", body: "The internet was down for \(duration).\(side)")
    }

    /// Roams don't carry noise readings, so judge the words on signal alone.
    private static func signalWord(_ rssi: Int) -> String {
        PlainLanguage.signal(rssi: rssi, snr: 99).lowercased()
    }

    private func allowed(_ kind: AlertKind, at time: Date) -> Bool {
        if let last = lastPosted[kind], time.timeIntervalSince(last) < Self.quietPeriod { return false }
        lastPosted[kind] = time
        return true
    }

    private func post(title: String, body: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

typealias NetworkLink = WiFiOrISPCore.Link
