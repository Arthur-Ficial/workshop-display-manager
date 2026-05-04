import Foundation
import Darwin

/// Grabs a free localhost TCP port by binding briefly and reading it back.
/// Mirrors WDMWeb's test pattern.
enum TestPort {
    enum Failure: Error { case socket, bind, getsockname }

    static func findFree() throws -> UInt16 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure.socket }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr = in_addr(s_addr: in_addr_t(0x7f000001).bigEndian) // 127.0.0.1, network byte order
        let len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, len) }
        }
        guard bound == 0 else { throw Failure.bind }
        var lenOut = len
        let got = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.getsockname(fd, $0, &lenOut) }
        }
        guard got == 0 else { throw Failure.getsockname }
        return UInt16(bigEndian: addr.sin_port)
    }
}
