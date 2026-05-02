import WDMCore

public protocol DisplayProvider: Sendable {
    func snapshot() throws -> Snapshot
    func modes(for displayID: UInt32) throws -> [Mode]

    @discardableResult func setMain(displayID: UInt32, options: ApplyOptions) throws -> ApplyResult
    @discardableResult func setMode(displayID: UInt32, mode: Mode, options: ApplyOptions) throws -> ApplyResult
    @discardableResult func mirror(source: UInt32, mirror: UInt32, options: ApplyOptions) throws -> ApplyResult
    @discardableResult func unmirror(displayID: UInt32, options: ApplyOptions) throws -> ApplyResult
    @discardableResult func move(displayID: UInt32, to origin: Point, options: ApplyOptions) throws -> ApplyResult
    @discardableResult func rotate(displayID: UInt32, degrees: Int, options: ApplyOptions) throws -> ApplyResult

    /// Read brightness on a 0…1 scale. Returns nil if the display does not
    /// expose brightness control (most external monitors).
    func brightness(for displayID: UInt32) throws -> Float?

    /// Set brightness on a 0…1 scale. Throws if the display is unsupported.
    @discardableResult func setBrightness(
        displayID: UInt32, value: Float, options: ApplyOptions
    ) throws -> ApplyResult
}
