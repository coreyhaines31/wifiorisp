import CoreWLAN
import Foundation
import SystemConfiguration

/// The default route, from the system's network state (no shelling out to `route`).
public struct Route: Equatable, Sendable {
    public var router: String?
    public var interface: String

    public static func current() -> Route? {
        guard let store = SCDynamicStoreCreate(nil, "app.wifiorisp" as CFString, nil, nil),
              let state = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let interface = state["PrimaryInterface"] as? String
        else { return nil }
        return Route(router: state["Router"] as? String, interface: interface)
    }

    /// The router of one interface's network service. With a VPN up, the default route points
    /// into the tunnel, but the router that matters for Wi-Fi is still the one on the Wi-Fi network.
    public static func router(for interface: String) -> String? {
        guard let store = SCDynamicStoreCreate(nil, "app.wifiorisp" as CFString, nil, nil),
              let values = SCDynamicStoreCopyMultiple(store, nil, ["State:/Network/Service/[^/]+/IPv4"] as CFArray)
                as? [String: [String: Any]]
        else { return nil }
        return values.values.first { $0["InterfaceName"] as? String == interface }?["Router"] as? String
    }

    /// Tunnels (VPNs) take over the default route without being the physical link.
    public var isTunnel: Bool {
        ["utun", "ipsec", "ppp", "tun", "tap"].contains { interface.hasPrefix($0) }
    }
}

/// Reads the current Wi-Fi association from CoreWLAN. Never scans: a scan is what sends
/// airportd into a request storm, and the app doesn't need nearby networks.
@MainActor
public final class WiFiReader {
    private let client = CWWiFiClient.shared()

    public init() {}

    public var interfaceName: String? {
        client.interface()?.interfaceName
    }

    public enum Result {
        case off
        case notAssociated
        case reading(WiFiReading)
    }

    public func read() -> Result {
        guard let interface = client.interface(), interface.powerOn() else { return .off }
        let rssi = interface.rssiValue()
        // 0 dBm means "not associated".
        guard rssi != 0 else { return .notAssociated }
        let channel = interface.wlanChannel()
        return .reading(WiFiReading(
            rssi: rssi,
            noise: interface.noiseMeasurement(),
            txRate: interface.transmitRate(),
            channel: channel?.channelNumber,
            band: channel.flatMap { Band(channel: $0) },
            ssid: interface.ssid(),
            bssid: interface.bssid()
        ))
    }
}

extension Band {
    init?(channel: CWChannel) {
        switch channel.channelBand {
        case .band2GHz: self = .ghz2
        case .band5GHz: self = .ghz5
        case .band6GHz: self = .ghz6
        default: return nil
        }
    }
}
