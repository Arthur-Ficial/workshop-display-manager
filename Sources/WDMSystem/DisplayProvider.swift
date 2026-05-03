import WDMCore

public protocol DisplayProvider: Sendable {
    func snapshot() throws -> Snapshot
    func modes(for displayID: UInt32) throws -> [Mode]

    @discardableResult func setMain(displayID: UInt32, options: ApplyOptions) throws -> ApplyResult
    @discardableResult func setMode(displayID: UInt32, mode: Mode, options: ApplyOptions) throws -> ApplyResult
    @discardableResult func mirror(source: UInt32, mirror: UInt32, options: ApplyOptions) throws -> ApplyResult
    /// Mirror `source` onto every id in `targets` atomically (single CG config commit).
    /// Validates every target up front; if any one is unknown, throws and applies nothing.
    @discardableResult func mirror(source: UInt32, targets: [UInt32], options: ApplyOptions) throws -> ApplyResult
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

    /// Read the current image flip state for a display.
    /// Returns `.none` for unflipped (default).
    func flip(for displayID: UInt32) throws -> Flip

    /// Apply an image flip across the X and/or Y axis.
    /// Throws `displayNotFound` if the id is unknown, or
    /// `configurationFailed` if the underlying framebuffer doesn't support it.
    @discardableResult func setFlip(
        displayID: UInt32, flip: Flip, options: ApplyOptions
    ) throws -> ApplyResult
}
