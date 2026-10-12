import Foundation

/// Who made the router, from the first three bytes of its hardware (MAC) address.
public enum RouterMaker: String, CaseIterable, Codable, Sendable {
    case eero, netgear, tpLink, asus, linksys, ubiquiti, google, synology
    case commscope, technicolor, sagemcom, askey, nokia, arcadyan, calix, humax, sercomm, hitron, ubee, compal, spacex

    public var name: String {
        switch self {
        case .eero: "eero"
        case .netgear: "NETGEAR"
        case .tpLink: "TP-Link"
        case .asus: "ASUS"
        case .linksys: "Linksys"
        case .ubiquiti: "Ubiquiti"
        case .google: "Google Nest Wifi"
        case .synology: "Synology"
        case .commscope: "Arris (CommScope)"
        case .technicolor: "Technicolor"
        case .sagemcom: "Sagemcom"
        case .askey: "Askey"
        case .nokia: "Nokia"
        case .arcadyan: "Arcadyan"
        case .calix: "Calix"
        case .humax: "Humax"
        case .sercomm: "Sercomm"
        case .hitron: "Hitron"
        case .ubee: "Ubee"
        case .compal: "Compal"
        case .spacex: "Starlink"
        }
    }

    /// Makers whose routers people buy themselves, rather than gateways an ISP supplies.
    public var isConsumerRouter: Bool {
        switch self {
        case .eero, .netgear, .tpLink, .asus, .linksys, .ubiquiti, .google, .synology: true
        default: false
        }
    }

    /// The router guide on wifiorisp.com, where there is one.
    public var guideSlug: String? {
        switch self {
        case .eero: "eero"
        case .netgear: "netgear"
        case .tpLink: "tp-link"
        case .asus: "asus"
        case .linksys: "linksys"
        case .ubiquiti: "ubiquiti-unifi"
        case .google: "google-nest-wifi"
        default: nil
        }
    }

    /// The router's own name for its smart-queueing setting, where it has one that helps with lag.
    public var smartQueueSetting: String? {
        switch self {
        case .eero: "SQM in the eero app (off in bridge mode)"
        case .asus: "Adaptive QoS"
        case .ubiquiti: "Smart Queues"
        case .netgear: "Dynamic QoS (select Nighthawk models)"
        default: nil
        }
    }

    private static let byPrefix: [String: RouterMaker] = {
        var map: [String: RouterMaker] = [:]
        for (maker, list) in prefixes {
            for prefix in list.split(separator: " ") {
                map[String(prefix)] = maker
            }
        }
        return map
    }()

    /// The maker for a MAC address like "4c:43:41:d7:ed:9d", or nil if it's unknown or randomized.
    public static func lookup(mac: String) -> RouterMaker? {
        let bytes = mac.split(separator: ":").map { $0.count == 1 ? "0" + $0 : String($0) }
        guard bytes.count == 6, let first = UInt8(bytes[0], radix: 16) else { return nil }
        // A set "locally administered" bit means a made-up address that says nothing about the maker.
        guard first & 0x02 == 0 else { return nil }
        return byPrefix[bytes[0...2].joined().uppercased()]
    }
}

/// Reads the router's hardware address from the Mac's own address table. Nothing leaves the Mac.
public enum GatewayHardware {
    public static func macAddress(of address: String) -> String? {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/sbin/arp")
        process.arguments = ["-n", address]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        let output = String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        return output.flatMap(parseMAC)
    }

    static func parseMAC(_ output: String) -> String? {
        output.firstMatch(of: /([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2}/).map { String($0.output.0).lowercased() }
    }
}

/// Which internet provider a connection belongs to, from its network's ASN (autonomous system number).
public struct Provider: Equatable, Sendable {
    public var asn: Int
    /// The display name, for providers we know.
    public var name: String?
    /// The provider guide on wifiorisp.com, for providers that have one.
    public var guideSlug: String?

    public init(asn: Int) {
        self.asn = asn
        let known = Self.known.first { $0.asns.contains(asn) }
        name = known?.name
        guideSlug = known?.slug
    }

    struct Known {
        var name: String
        var slug: String
        var asns: Set<Int>

        init(_ name: String, _ slug: String, _ asns: Set<Int>) {
            self.name = name
            self.slug = slug
            self.asns = asns
        }
    }

    /// Major US home providers and their main ASNs.
    static let known: [Known] = [
        Known("Spectrum", "why-is-my-spectrum-internet-slow",
         [20115, 11427, 10796, 12271, 11351, 20001, 33363, 7843, 11426, 10838]),
        Known("Xfinity", "why-is-my-xfinity-internet-slow",
         [7922, 7015, 7016, 7725, 13367, 20214, 21508, 22258, 22909, 33287, 33489, 33490, 33491, 33650, 33651,
          33652, 33657, 33659, 33660, 33662, 33667, 33668]),
        Known("AT&T", "why-is-my-att-internet-slow", [7018, 7132]),
        Known("Verizon Fios", "why-is-my-verizon-fios-internet-slow", [701]),
        Known("Verizon", "why-is-my-verizon-5g-home-internet-slow", [22394]),
        Known("T-Mobile", "why-is-my-t-mobile-home-internet-slow", [21928]),
        Known("Cox", "why-is-my-cox-internet-slow", [22773]),
        Known("Optimum", "why-is-my-optimum-internet-slow", [6128, 19108]),
        Known("Frontier", "why-is-my-frontier-internet-slow", [5650]),
        Known("CenturyLink", "why-is-my-centurylink-internet-slow", [209, 22561]),
        Known("Google Fiber", "why-is-my-google-fiber-internet-slow", [16591]),
        Known("Starlink", "why-is-my-starlink-internet-slow", [14593])
    ]

    /// Asks Cloudflare's speed test server, which reports the connection's ASN in a header. This is
    /// the one request the app makes on its own: once per network, to tailor the ISP steps.
    public static func detect() async -> Provider? {
        var request = URLRequest(url: URL(string: "https://speed.cloudflare.com/__down?bytes=0")!)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "asn"),
              let asn = Int(header)
        else { return nil }
        return Provider(asn: asn)
    }
}
