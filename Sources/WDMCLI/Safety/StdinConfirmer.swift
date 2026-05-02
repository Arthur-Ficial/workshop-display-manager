import Foundation

/// Reads one keypress (`y`/`Y`/Enter) from stdin within `timeoutSeconds`.
/// Anything else, EOF, or timeout → false (revert).
public struct StdinConfirmer: Confirmer {
    private let prompt: String
    private let stderr: OutputWriter

    public init(prompt: String, stderr: OutputWriter) {
        self.prompt = prompt
        self.stderr = stderr
    }

    public func confirm(timeoutSeconds: Int) -> Bool {
        stderr.write(prompt + " (y/N, \(timeoutSeconds)s) ")

        let stdin = FileHandle.standardInput
        let fd = stdin.fileDescriptor

        var fds = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let ready = withUnsafeMutablePointer(to: &fds) { ptr in
            poll(ptr, 1, Int32(timeoutSeconds * 1000))
        }

        guard ready > 0 else {
            stderr.writeLine("(timeout — reverting)")
            return false
        }

        var buf = [UInt8](repeating: 0, count: 8)
        let n = read(fd, &buf, buf.count)
        guard n > 0 else { return false }
        let answer = String(bytes: buf[0..<Int(n)], encoding: .utf8)?.first
        return answer == "y" || answer == "Y"
    }
}
