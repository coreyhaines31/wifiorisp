import Foundation
import WiFiOrISPCore

/// User settings, stored in UserDefaults.
enum Preferences {
    private static var defaults: UserDefaults { .standard }

    private enum Key {
        static let alertsOnDrop = "alertsOnDrop"
        static let alertsOn24GHz = "alertsOn24GHz"
        static let alertsOnWeakerRoam = "alertsOnWeakerRoam"
        static let showsVerdictInMenuBar = "showsVerdictInMenuBar"
        static let showsSignalInMenuBar = "showsSignalInMenuBar"
        static let keepDays = "keepDays"
        static let responsivenessServer = "responsivenessServer"
        static let acceptedMLabTerms = "acceptedMLabTerms"
        static let hasSeenWelcome = "hasSeenWelcome"
        static let planDown = "planDownMbps"
        static let planUp = "planUpMbps"
        static let people = "homePeople"
        static let videoCalls = "homeVideoCalls"
        static let gaming = "homeGaming"
        static let streams4K = "homeStreams4K"
        static let bigUploads = "homeBigUploads"
    }

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.alertsOnDrop: true,
            Key.alertsOn24GHz: true,
            Key.alertsOnWeakerRoam: true,
            Key.showsVerdictInMenuBar: true,
            Key.showsSignalInMenuBar: false,
            Key.keepDays: LogStore.defaultKeepDays,
            Key.responsivenessServer: ResponsivenessTest.defaultConfigURL.absoluteString,
            Key.people: 2,
            Key.videoCalls: true,
            Key.streams4K: 1
        ])
    }

    static func alerts(for kind: AlertKind) -> Bool {
        switch kind {
        case .drop: defaults.bool(forKey: Key.alertsOnDrop)
        case .fellTo24GHz: defaults.bool(forKey: Key.alertsOn24GHz)
        case .roamedWeaker: defaults.bool(forKey: Key.alertsOnWeakerRoam)
        }
    }

    static func key(for kind: AlertKind) -> String {
        switch kind {
        case .drop: Key.alertsOnDrop
        case .fellTo24GHz: Key.alertsOn24GHz
        case .roamedWeaker: Key.alertsOnWeakerRoam
        }
    }

    static var showsVerdictInMenuBar: Bool { defaults.bool(forKey: Key.showsVerdictInMenuBar) }
    static var showsSignalInMenuBar: Bool { defaults.bool(forKey: Key.showsSignalInMenuBar) }
    static var keepDays: Int { max(1, defaults.integer(forKey: Key.keepDays)) }

    static var responsivenessServer: URL {
        defaults.string(forKey: Key.responsivenessServer).flatMap(URL.init(string:))
            ?? ResponsivenessTest.defaultConfigURL
    }

    /// What the user pays for, or nil until they've entered it.
    static var plan: Plan? {
        let download = defaults.double(forKey: Key.planDown)
        let upload = defaults.double(forKey: Key.planUp)
        return download > 0 && upload > 0 ? Plan(downMbps: download, upMbps: upload) : nil
    }

    static var profile: HomeProfile {
        HomeProfile(
            people: max(1, defaults.integer(forKey: Key.people)),
            videoCalls: defaults.bool(forKey: Key.videoCalls),
            gaming: defaults.bool(forKey: Key.gaming),
            streams4K: defaults.integer(forKey: Key.streams4K),
            bigUploads: defaults.bool(forKey: Key.bigUploads)
        )
    }

    static var hasSeenWelcome: Bool {
        get { defaults.bool(forKey: Key.hasSeenWelcome) }
        set { defaults.set(newValue, forKey: Key.hasSeenWelcome) }
    }

    static var acceptedMLabTerms: Bool {
        get { defaults.bool(forKey: Key.acceptedMLabTerms) }
        set { defaults.set(newValue, forKey: Key.acceptedMLabTerms) }
    }

    enum Keys {
        static let showsVerdictInMenuBar = Key.showsVerdictInMenuBar
        static let showsSignalInMenuBar = Key.showsSignalInMenuBar
        static let keepDays = Key.keepDays
        static let responsivenessServer = Key.responsivenessServer
        static let planDown = Key.planDown
        static let planUp = Key.planUp
        static let people = Key.people
        static let videoCalls = Key.videoCalls
        static let gaming = Key.gaming
        static let streams4K = Key.streams4K
        static let bigUploads = Key.bigUploads
    }
}
