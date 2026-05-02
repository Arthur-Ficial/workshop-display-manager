import Foundation

public final class StreamOutputWriter: OutputWriter, @unchecked Sendable {
    private let handle: FileHandle
    public init(handle: FileHandle) { self.handle = handle }
    public func write(_ s: String) {
        if let data = s.data(using: .utf8) { handle.write(data) }
    }
}
