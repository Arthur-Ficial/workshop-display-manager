public protocol OutputWriter: Sendable {
    func write(_ s: String)
}

public extension OutputWriter {
    func writeLine(_ s: String) { write(s + "\n") }
}
