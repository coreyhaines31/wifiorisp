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
    }

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.alertsOnDrop: true,
            Key.alertsOn24GHz: true,
            Key.alertsOnWeakerRoam: true,
            Key.showsVerdictInMenuBar: true,
            Key.showsSignalInMenuBar: true,
            Key.keepDays: LogStore.defaultKeepDays,
            Key.responsivenessServer: ResponsivenessTest.defaultConfigURL.absoluteString
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

    static var acceptedMLabTerms: Bool {
        get { defaults.bool(forKey: Key.acceptedMLabTerms) }
        set { defaults.set(newValue, forKey: Key.acceptedMLabTerms) }
    }

    enum Keys {
        static let showsVerdictInMenuBar = Key.showsVerdictInMenuBar
        static let showsSignalInMenuBar = Key.showsSignalInMenuBar
        static let keepDays = Key.keepDays
        static let responsivenessServer = Key.responsivenessServer
    }
}
