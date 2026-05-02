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
}
