import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = MonitorController()
    private let location = LocationAccess()
    private let updater = Updater()
    private lazy var tests = TestsModel(monitor: monitor)
    private var windows: Windows?
    private var statusItemController: StatusItemController?
    private var cliServer: CLIServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        #if !DEBUG
        // Debug builds run from DerivedData; registering that copy would open it at every login.
        if !Preferences.appliedLaunchAtLoginDefault {
            Preferences.appliedLaunchAtLoginDefault = true
            try? SMAppService.mainApp.register()
        }
        #endif
        let windows = Windows(monitor: monitor, tests: tests, location: location, updater: updater)
        self.windows = windows
        statusItemController = StatusItemController(
            monitor: monitor, location: location, windows: windows, updater: updater
        )
        monitor.start()
        let handler = CLIHandler(monitor: monitor, tests: tests, location: location)
        cliServer = CLIServer { request, connection in handler.handle(request, connection) }
        cliServer?.start()
        if !Preferences.hasSeenWelcome {
            windows.showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cliServer?.stop()
        monitor.stop()
    }
}
