import Foundation
import os
import WiFiOrISPCore

/// Listens for the `wifiorisp` command on a Unix socket in Application Support. Only processes
/// running as the signed-in user can connect. Each connection carries one request; the app
/// answers with JSON messages, one per line, and closes the connection when it's done.
final class CLIServer: Sendable {
    typealias Handler = @MainActor @Sendable (CLIRequest, CLIConnection) -> Void

    private let handler: Handler
    private let path = CLIProtocol.socketURL.path
    /// The socket file this instance created, so quitting never removes another instance's.
    private let ownSocket = OSAllocatedUnfairLock<ino_t?>(initialState: nil)

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func start() {
        // A command that hangs up mid-answer (Ctrl-C during `watch`) must not kill the app.
        signal(SIGPIPE, SIG_IGN)
        try? FileManager.default.createDirectory(
            at: CLIProtocol.socketURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // Another running copy of the app keeps the socket; a file left by a crash is removed.
        if Self.isAnswering(path) { return }
        unlink(path)
        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listener >= 0, var address = Self.address(path) else { return }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, size) }
        }
        var info = stat()
        guard bound == 0, chmod(path, 0o600) == 0, listen(listener, 8) == 0, stat(path, &info) == 0 else {
            close(listener)
            return
        }
        let inode = info.st_ino
        ownSocket.withLock { $0 = inode }
        let handler = handler
        Thread.detachNewThread {
            while true {
                let client = accept(listener, nil, nil)
                if client < 0 {
                    if errno == EINTR || errno == ECONNABORTED { continue }
                    return
                }
                DispatchQueue.global().async { Self.serve(client, handler: handler) }
            }
        }
    }

    func stop() {
        var info = stat()
        guard let own = ownSocket.withLock({ $0 }), stat(path, &info) == 0, info.st_ino == own else { return }
        unlink(path)
    }

    private static func isAnswering(_ path: String) -> Bool {
        let probe = socket(AF_UNIX, SOCK_STREAM, 0)
        guard probe >= 0, var address = address(path) else { return false }
        defer { close(probe) }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(probe, $0, size) }
        } == 0
    }

    static func address(_ path: String) -> sockaddr_un? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    private static func serve(_ client: Int32, handler: @escaping Handler) {
        var uid = uid_t()
        var gid = gid_t()
        guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else {
            close(client)
            return
        }
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, [Int32(1)], socklen_t(MemoryLayout<Int32>.size))
        let connection = CLIConnection(client)
        guard let data = readRequest(client), !data.isEmpty else {
            // Another copy of the app checking whether this one is listening.
            connection.close()
            return
        }
        guard let request = try? CLIProtocol.decoder().decode(CLIRequest.self, from: data) else {
            let error = "WiFi or ISP didn't understand that request. Update the app and try again."
            connection.send(CLIMessage(error: error))
            connection.close()
            return
        }
        DispatchQueue.main.async {
            MainActor.assumeIsolated { handler(request, connection) }
        }
    }

    /// Reads until the command closes its side. Requests are tiny; anything over 64 KB is refused.
    private static func readRequest(_ client: Int32) -> Data? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while data.count <= 65_536 {
            let received = read(client, &buffer, buffer.count)
            if received == 0 { return data }
            if received < 0 {
                if errno == EINTR { continue }
                return nil
            }
            data.append(buffer, count: received)
        }
        return nil
    }
}

/// One command's connection. Messages go out as JSON lines until it's closed.
final class CLIConnection: Sendable {
    private let socket: Int32
    private let isOpen = OSAllocatedUnfairLock(initialState: true)

    init(_ socket: Int32) {
        self.socket = socket
    }

    /// False once the command has hung up, so a `watch` knows to stop.
    @discardableResult
    func send(_ message: CLIMessage) -> Bool {
        guard var encoded = try? CLIProtocol.encoder().encode(message) else { return false }
        encoded.append(0x0A)
        let data = encoded
        return isOpen.withLock { open in
            guard open else { return false }
            let sent = data.withUnsafeBytes { raw in
                var offset = 0
                while offset < raw.count {
                    let written = write(socket, raw.baseAddress! + offset, raw.count - offset)
                    if written < 0, errno == EINTR { continue }
                    if written <= 0 { return false }
                    offset += written
                }
                return true
            }
            if !sent {
                open = false
                Darwin.close(socket)
            }
            return sent
        }
    }

    func close() {
        isOpen.withLock { open in
            guard open else { return }
            open = false
            Darwin.close(socket)
        }
    }
}
