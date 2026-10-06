import AppKit
import SwiftUI
import WiFiOrISPCore

/// Owns the menu bar item: a plain `NSStatusItem` with an `autosaveName`, so macOS can
/// Cmd-drag it and remember where it goes.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor: MonitorController
    private let location: LocationAccess
    private let windows: Windows
    private let updater: Updater

    init(monitor: MonitorController, location: LocationAccess, windows: Windows, updater: Updater) {
        self.monitor = monitor
        self.location = location
        self.windows = windows
        self.updater = updater
        super.init()

        statusItem.autosaveName = "WiFiOrISPStatusItem"
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        monitor.onChange = { [weak self] in self?.refreshButton() }
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshButton() }
        }
        refreshButton()
    }

    private func refreshButton() {
        let verdict = monitor.verdict
        statusItem.button?.image = RouterIcon.menuBarImage(Self.lights(for: verdict, latest: monitor.latest))

        var parts: [String] = []
        if Preferences.showsSignalInMenuBar, let rssi = monitor.latest?.wifi?.rssi {
            parts.append("\(rssi) dBm")
        }
        if Preferences.showsVerdictInMenuBar, let short = verdict.short {
            parts.append(short)
        }
        let title = parts.isEmpty ? "" : " " + parts.joined(separator: " · ")
        if statusItem.button?.title != title {
            statusItem.button?.title = title
        }
        statusItem.button?.setAccessibilityLabel("WiFi or ISP: \(verdict.headline)")
        statusItem.button?.toolTip = verdict.headline
    }

    /// LEDs show signal strength while things are fine; they go dark when something's wrong.
    static func lights(for verdict: Verdict, latest: Sample?) -> RouterIcon.Lights {
        if verdict.kind == .notConnected { return .off }
        if verdict.isProblem { return .dark }
        guard let wifi = latest?.wifi else { return .bars(3) }
        return .bars(RouterIcon.bars(strength: PlainLanguage.signalStrength(rssi: wifi.rssi)))
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        monitor.sampleSoon()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let card = NSHostingView(rootView: VerdictCard(monitor: monitor, location: location))
        card.frame.size = card.fittingSize
        let cardItem = NSMenuItem()
        cardItem.view = card
        menu.addItem(cardItem)
        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem("Run Speed Test…") { [weak self] in self?.windows.showTests() })
        menu.addItem(ClosureMenuItem("Test Lag Under Load…") { [weak self] in self?.windows.showTests() })
        menu.addItem(ClosureMenuItem("History…", keyEquivalent: "h") { [weak self] in self?.windows.showHistory() })
        menu.addItem(ClosureMenuItem("Export Report for Your ISP…", keyEquivalent: "e") { [weak self] in
            self?.windows.exportReport()
        })

        if monitor.latest?.link == .wifi && !location.isAuthorized {
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem("Show Network Name…") { [weak self] in
                self?.location.requestWithExplanation()
            })
        }

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Settings…", keyEquivalent: ",") { [weak self] in self?.windows.showSettings() })
        let check = ClosureMenuItem("Check for Updates…") { [weak self] in self?.updater.checkForUpdates() }
        check.isEnabled = updater.canCheck
        menu.addItem(check)
        menu.addItem(ClosureMenuItem("About WiFi or ISP") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Quit WiFi or ISP", keyEquivalent: "q") { NSApp.terminate(nil) })
    }
}
