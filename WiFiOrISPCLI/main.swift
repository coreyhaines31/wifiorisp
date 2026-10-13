import Foundation
import WiFiOrISPCore

let usage = """
wifiorisp: ask WiFi or ISP whether slow internet is your Wi-Fi or your ISP, from the terminal.

Usage:
  wifiorisp status [--json]
  wifiorisp watch [--json]
  wifiorisp speed [--json]
  wifiorisp lag [--json]
  wifiorisp history [--since 24h] [--json | --csv]
  wifiorisp report [--since 7d]

Commands:
  status    The verdict right now, the numbers behind it, and what to do next.
  watch     A line after every measurement (every 5 to 30 seconds), until Ctrl-C.
  speed     Download and upload speed, from M-Lab (about 20 seconds). M-Lab publishes
            every result, including your IP address, as open data.
  lag       Lag under load, and whether it builds up in your Wi-Fi or past your router
            (about 20 seconds, a few hundred MB on a fast connection).
  history   What the background log saw: typical timings, slow spells, drops, and tests.
  report    The plain-text report to send your ISP.

Options:
  --json         Print JSON. `watch --json` prints one object per line.
  --since TIME   How far back, like 90m, 24h, or 7d.

Exit status: 0 when all is well, 2 when status finds a problem, 1 on errors.
status, watch, speed, and lag open WiFi or ISP in the background if it isn't running.
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("wifiorisp: \(message)\n".utf8))
    exit(1)
}

func note(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}

func printJSON<Value: Encodable>(_ value: Value, pretty: Bool = true) {
    let encoder = CLIProtocol.encoder()
    if pretty { encoder.outputFormatting.insert(.prettyPrinted) }
    guard let data = try? encoder.encode(value) else { fail("Couldn't encode the result.") }
    print(String(decoding: data, as: UTF8.self))
    fflush(stdout)
}

// MARK: - Talking to the app

func socketAddress() -> sockaddr_un? {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(CLIProtocol.socketURL.path.utf8)
    guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
    return address
}

/// Connects and sends the request. Nil if the app isn't listening.
func connect(_ request: CLIRequest) -> Int32? {
    let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard socket >= 0 else { return nil }
    setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, [Int32(1)], socklen_t(MemoryLayout<Int32>.size))
    guard var address = socketAddress() else { fail("The path to WiFi or ISP's socket is too long.") }
    let size = socklen_t(MemoryLayout<sockaddr_un>.size)
    let connected = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(socket, $0, size) }
    }
    guard connected == 0, let body = try? CLIProtocol.encoder().encode(request),
          body.withUnsafeBytes({ write(socket, $0.baseAddress, $0.count) }) == body.count
    else {
        close(socket)
        return nil
    }
    shutdown(socket, SHUT_WR)
    // A stuck app shouldn't hang the command. `watch` waits as long as it takes.
    let seconds: Int = switch request.action {
    case .status: 60
    case .speed, .lag: 120
    case .watch: 0
    }
    var timeout = timeval(tv_sec: seconds, tv_usec: 0)
    setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    return socket
}

/// The app this command ships inside, or nil when it was built on its own.
func enclosingApp() -> URL? {
    // argv[0] is just "wifiorisp" when found on the PATH, so ask for the real path.
    guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return nil }
    let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return app.pathExtension == "app" ? app : nil
}

/// Opens WiFi or ISP in the background if needed, then connects.
func connectLaunchingApp(_ request: CLIRequest) -> Int32 {
    if let socket = connect(request) { return socket }
    let open = Process()
    open.executableURL = URL(filePath: "/usr/bin/open")
    open.arguments = enclosingApp().map { ["-g", $0.path] } ?? ["-g", "-b", CLIProtocol.bundleIdentifier]
    open.standardError = FileHandle.nullDevice
    do {
        try open.run()
        open.waitUntilExit()
    } catch {
        fail("Couldn't open WiFi or ISP: \(error.localizedDescription)")
    }
    guard open.terminationStatus == 0 else {
        fail("Couldn't find WiFi or ISP. Install it with: brew install --cask coreyhaines31/tap/wifiorisp")
    }
    note("Opened WiFi or ISP in the background.")
    for _ in 0..<50 {
        Thread.sleep(forTimeInterval: 0.2)
        if let socket = connect(request) { return socket }
    }
    fail("WiFi or ISP didn't answer. If it was running before an update, quit it from the menu and open it again.")
}

/// Shows test progress on one line in a terminal. For scripts and agents, prints a line only
/// when the phase changes, not for every speed update.
struct ProgressLine {
    private let interactive = isatty(STDERR_FILENO) == 1
    private var shown = false
    private var lastPhase: String?

    mutating func show(_ text: String) {
        if interactive {
            FileHandle.standardError.write(Data("\r\u{1B}[K\(text)".utf8))
            shown = true
        } else {
            let phase = String(text.prefix { $0 != ":" })
            if phase != lastPhase { note(text) }
            lastPhase = phase
        }
    }

    mutating func clear() {
        if shown { FileHandle.standardError.write(Data("\r\u{1B}[K".utf8)) }
        shown = false
    }
}

/// Reads the app's answer line by line, and returns the exit status.
func receive(_ socket: Int32, action: CLIRequest.Action, json: Bool) -> Int32 {
    var buffer = Data()
    var chunk = [UInt8](repeating: 0, count: 4_096)
    var progress = ProgressLine()
    var finished = false
    var status: Int32 = 0
    while !finished {
        let received = read(socket, &chunk, chunk.count)
        if received < 0, errno == EINTR { continue }
        if received <= 0 { break }
        buffer.append(chunk, count: received)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let message = try? CLIProtocol.decoder().decode(CLIMessage.self, from: line) else { continue }
            if let text = message.progress {
                progress.show(text)
                continue
            }
            progress.clear()
            if let error = message.error { fail(error) }
            if let result = message.status {
                show(result, action: action, json: json)
                if action == .status {
                    status = result.verdict.problem ? 2 : 0
                    finished = true
                }
            } else if let speed = message.speed {
                json ? printJSON(speed) : print(CLIText.speed(speed))
                finished = true
            } else if let lag = message.lag {
                json ? printJSON(lag) : print(CLIText.lag(lag))
                finished = true
            }
        }
    }
    progress.clear()
    close(socket)
    if !finished {
        fail(errno == EAGAIN ? "WiFi or ISP took too long to answer." : "WiFi or ISP stopped answering.")
    }
    return status
}

func show(_ status: CLIStatus, action: CLIRequest.Action, json: Bool) {
    if action == .watch {
        json ? printJSON(status, pretty: false) : print(CLIText.watchLine(status))
        fflush(stdout)
    } else {
        json ? printJSON(status) : print(CLIText.status(status))
    }
}

// MARK: - Reading the log

func readLog(since: TimeInterval) -> (Log, Date, Date) {
    let end = Date()
    let start = end.addingTimeInterval(-since)
    return (LogStore(directory: LogStore.defaultDirectory).load(from: start, to: end), start, end)
}

/// The plan entered in the app's Settings, for the report.
var savedPlan: Plan? {
    let defaults = UserDefaults(suiteName: CLIProtocol.bundleIdentifier)
    let down = defaults?.double(forKey: "planDownMbps") ?? 0
    let up = defaults?.double(forKey: "planUpMbps") ?? 0
    return down > 0 ? Plan(downMbps: down, upMbps: up) : nil
}

// MARK: - Main

let command: CLICommand
do {
    command = try CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    let message = (error as? CLIArgumentError)?.message ?? error.localizedDescription
    fail("\(message)\nRun wifiorisp help for usage.")
}

switch command {
case .help:
    print(usage)
case .version:
    print(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
case .history(let since, let format):
    let (log, start, end) = readLog(since: since)
    switch format {
    case .text: print(CLIText.history(log, start: start, end: end))
    case .json: printJSON(CLIHistory(log: log, start: start, end: end))
    case .csv: print(SampleCSV.text(log.samples), terminator: "")
    }
case .report(let since):
    let (log, start, end) = readLog(since: since)
    print(ISPReport.text(log: log, start: start, end: end, plan: savedPlan))
case .app(let action, let json):
    if action == .speed {
        note("Speed test by M-Lab, which publishes every result, including your IP address, as open data.")
    }
    let socket = connectLaunchingApp(CLIRequest(action: action))
    exit(receive(socket, action: action, json: json))
}
