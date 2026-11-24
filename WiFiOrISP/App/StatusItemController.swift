import AppKit
import PanelKit
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
        statusItem.button?.image = TwinMeterGlyph.menuBarImage(
            TwinMeterGlyph.needles(for: verdict, latest: monitor.latest)
        )

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

    // MARK: - Next steps

    private func perform(_ action: NextStep.Action) {
        switch action {
        case .page(let path):
            if let url = URL(string: "https://wifiorisp.com" + path) {
                NSWorkspace.shared.open(url)
            }
        case .runSpeedTest, .runLagTest:
            windows.showTests()
        case .exportReport:
            windows.exportReport()
        }
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        monitor.sampleSoon()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(.panelCard(VerdictCard(monitor: monitor, location: location) { [weak self] action in
            menu.cancelTracking()
            self?.perform(action)
        }))
        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem("Run Speed Test…") { [weak self] in self?.windows.showTests() })
        menu.addItem(ClosureMenuItem("Test Lag Under Load…") { [weak self] in self?.windows.showTests() })
        menu.addItem(ClosureMenuItem("Survey Rooms…") { [weak self] in self?.windows.showSurvey() })
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
        menu.addItem(ClosureMenuItem("WiFi or ISP Help") {
            NSWorkspace.shared.open(URL(string: "https://wifiorisp.com/help")!)
        })
        menu.addItem(ClosureMenuItem("About WiFi or ISP") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Quit WiFi or ISP", keyEquivalent: "q") { NSApp.terminate(nil) })
    }
}
