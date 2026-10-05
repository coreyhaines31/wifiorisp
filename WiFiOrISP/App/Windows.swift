import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WiFiOrISPCore

/// Opens the app's windows and runs the exports.
@MainActor
final class Windows {
    private let monitor: MonitorController
    private let location: LocationAccess
    private let updater: Updater
    private lazy var tests = TestsModel(monitor: monitor)
    private lazy var history = HistoryModel(store: monitor.store)
    private var testsWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(monitor: MonitorController, location: LocationAccess, updater: Updater) {
        self.monitor = monitor
        self.location = location
        self.updater = updater
    }

    func showTests() {
        testsWindow = testsWindow ?? makeWindow("Tests", view: TestsView(model: tests))
        show(testsWindow)
    }

    func showHistory() {
        if historyWindow == nil {
            historyWindow = makeWindow("History", view: HistoryView(
                model: history,
                exportReport: { [weak self] in self?.exportReport() },
                exportCSV: { [weak self] in self?.exportCSV() }
            ))
            historyWindow?.styleMask.insert(.resizable)
        } else {
            history.reload()
        }
        show(historyWindow)
    }

    func showSettings() {
        if settingsWindow == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            add("General", symbol: "gearshape", view: GeneralSettingsView(updater: updater), to: tabs)
            add("Alerts", symbol: "bell", view: AlertsSettingsView(), to: tabs)
            let privacy = PrivacySettingsView(location: location, store: monitor.store)
            add("Privacy", symbol: "hand.raised", view: privacy, to: tabs)
            add("Advanced", symbol: "slider.horizontal.3", view: AdvancedSettingsView(), to: tabs)
            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable]
            window.toolbarStyle = .preference
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        show(settingsWindow)
    }

    // MARK: - Exports

    /// Asks how far back, then saves a plain-text report to email or paste into a support chat.
    func exportReport() {
        let picker = NSPopUpButton()
        let choices: [(String, TimeInterval)] = [
            ("Last 24 hours", 86400), ("Last 7 days", 7 * 86400), ("Last 30 days", 30 * 86400)
        ]
        choices.forEach { picker.addItem(withTitle: $0.0) }
        picker.selectItem(at: 1)
        picker.sizeToFit()

        let panel = NSSavePanel()
        panel.title = "Export Report for Your ISP"
        panel.message = "A plain-text summary of outages and slowdowns, with the evidence of which side caused them."
        panel.nameFieldStringValue = "Connection report \(Date().formatted(.iso8601.year().month().day())).txt"
        panel.allowedContentTypes = [.plainText]
        panel.accessoryView = labeled("Period:", picker)
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let end = Date()
        let start = end.addingTimeInterval(-choices[picker.indexOfSelectedItem].1)
        let log = monitor.store.load(from: start, to: end)
        write(ISPReport.text(log: log, start: start, end: end), to: url)
    }

    func exportCSV() {
        let panel = NSSavePanel()
        panel.title = "Export CSV"
        panel.nameFieldStringValue = "WiFi or ISP \(Date().formatted(.iso8601.year().month().day())).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let end = Date()
        let log = monitor.store.load(from: end.addingTimeInterval(-Double(Preferences.keepDays) * 86400), to: end)
        write(SampleCSV.text(log.samples), to: url)
    }

    private func write(_ text: String, to url: URL) {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Helpers

    private func labeled(_ label: String, _ control: NSView) -> NSView {
        let text = NSTextField(labelWithString: label)
        let stack = NSStackView(views: [text, control])
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.frame.size = stack.fittingSize
        return stack
    }

    private func makeWindow(_ title: String, view: some View) -> NSWindow {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func add(_ title: String, symbol: String, view: some View, to tabs: NSTabViewController) {
        let controller = NSHostingController(rootView: view.frame(width: 520))
        controller.sizingOptions = .preferredContentSize
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        tabs.addTabViewItem(item)
    }

    private func show(_ window: NSWindow?) {
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
