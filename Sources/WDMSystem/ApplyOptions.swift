public struct ApplyOptions: Sendable, Equatable {
    public let confirm: Bool
    public let autoRevertSeconds: Int

    public init(confirm: Bool, autoRevertSeconds: Int = 15) {
        self.confirm = confirm
        self.autoRevertSeconds = autoRevertSeconds
    }

    public static let noConfirm = ApplyOptions(confirm: false)
    public static let confirm = ApplyOptions(confirm: true)
}
