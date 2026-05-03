import Foundation

public final class BufferOutputWriter: OutputWriter, @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""

    public init() {}

    public func write(_ s: String) {
        lock.withLock { buffer += s }
    }

    public var contents: String {
        lock.withLock { buffer }
    }
}
