import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = MonitorController()
    private let location = LocationAccess()
    private let updater = Updater()
    private var windows: Windows?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        let windows = Windows(monitor: monitor, location: location, updater: updater)
        self.windows = windows
        statusItemController = StatusItemController(
            monitor: monitor, location: location, windows: windows, updater: updater
        )
        monitor.start()
        if !Preferences.hasSeenWelcome {
            windows.showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }
}
