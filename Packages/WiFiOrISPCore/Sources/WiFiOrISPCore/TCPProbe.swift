import Darwin
import Foundation

/// Times one TCP handshake: the SYN out and the SYN-ACK (or RST) back is exactly one round trip.
/// No ICMP, so it needs no privileges. A refused connection still counts as a reply,
/// since the host answered.
public enum TCPProbe {
    private static let queue = DispatchQueue(label: "app.wifiorisp.probe", attributes: .concurrent)

    public static func roundTrip(to host: String, port: UInt16, timeout: TimeInterval = 2) async -> Probe {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: measure(host: host, port: port, timeout: timeout))
            }
        }
    }

    private static func measure(host: String, port: UInt16, timeout: TimeInterval) -> Probe {
        guard var address = SocketAddress(host: host, port: port) else { return .lost }
        let socketFD = socket(address.family, SOCK_STREAM, IPPROTO_TCP)
        guard socketFD >= 0 else { return .lost }
        defer { close(socketFD) }

        var on: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(socketFD, F_SETFL, fcntl(socketFD, F_GETFL) | O_NONBLOCK)

        let start = DispatchTime.now().uptimeNanoseconds
        let result = address.withSockaddr { connect(socketFD, $0, $1) }
        if result == 0 || errno == ECONNREFUSED {
            return .reply(ms: elapsedMs(since: start))
        }
        guard errno == EINPROGRESS else { return .lost }

        var pollFD = pollfd(fd: socketFD, events: Int16(POLLOUT), revents: 0)
        guard poll(&pollFD, 1, Int32(timeout * 1000)) == 1 else { return .lost }
        let ms = elapsedMs(since: start)

        var error: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(socketFD, SOL_SOCKET, SO_ERROR, &error, &length)
        return error == 0 || error == ECONNREFUSED ? .reply(ms: ms) : .lost
    }

    private static func elapsedMs(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
}

/// An IPv4 or IPv6 literal address with a port.
private enum SocketAddress {
    case v4(sockaddr_in)
    case v6(sockaddr_in6)

    init?(host: String, port: UInt16) {
        var v4 = sockaddr_in()
        if inet_pton(AF_INET, host, &v4.sin_addr) == 1 {
            v4.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            v4.sin_family = sa_family_t(AF_INET)
            v4.sin_port = port.bigEndian
            self = .v4(v4)
            return
        }
        var v6 = sockaddr_in6()
        if inet_pton(AF_INET6, host, &v6.sin6_addr) == 1 {
            v6.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
            v6.sin6_family = sa_family_t(AF_INET6)
            v6.sin6_port = port.bigEndian
            self = .v6(v6)
            return
        }
        return nil
    }

    var family: Int32 {
        switch self {
        case .v4: AF_INET
        case .v6: AF_INET6
        }
    }

    mutating func withSockaddr<T>(_ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
        switch self {
        case .v4(var address):
            withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
        case .v6(var address):
            withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, socklen_t(MemoryLayout<sockaddr_in6>.size)) }
            }
        }
    }
}
