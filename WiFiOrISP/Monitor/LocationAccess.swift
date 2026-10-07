import AppKit
import CoreLocation

/// macOS only shows apps the Wi-Fi network name with Location access. The app never asks
/// for a location; it only needs the permission. Without it, the network shows as "Unknown network".
@MainActor
final class LocationAccess: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var status: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var isAuthorized: Bool {
        status == .authorizedAlways || status == .authorized
    }

    var statusText: String {
        switch status {
        case .authorizedAlways, .authorized: "Allowed"
        case .denied: "Not allowed"
        case .restricted: "Restricted by your Mac's settings"
        default: "Not asked yet"
        }
    }

    static let explanation = """
        macOS treats the Wi-Fi network name as location data, because a network name can reveal \
        where you are. So apps can only read it with Location access.

        WiFi or ISP uses the name to label your history by network and to spot when your Mac \
        roams between access points. It never asks for your location and nothing leaves your Mac.

        Everything else works without it. Your network just shows as "Unknown network".
        """

    /// Asks macOS directly, or opens System Settings if it was already turned down.
    /// For places that have already explained why, like the welcome window.
    func request() {
        if status == .notDetermined {
            NSApp.activate()
            manager.requestWhenInUseAuthorization()
        } else if status == .denied {
            Self.openSystemSettings()
        }
    }

    /// Explains why, then asks macOS (or opens System Settings if it was already turned down).
    func requestWithExplanation() {
        let alert = NSAlert()
        alert.messageText = "Show your Wi-Fi network name?"
        alert.informativeText = Self.explanation
        alert.addButton(withTitle: status == .denied ? "Open System Settings" : "Continue")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            Self.openSystemSettings()
        }
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
        NSWorkspace.shared.open(url)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.status = status }
    }
}
