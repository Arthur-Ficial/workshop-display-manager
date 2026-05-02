public struct AutoYesConfirmer: Confirmer {
    public init() {}
    public func confirm(message: String, timeoutSeconds: Int) -> Bool { true }
}

public struct AutoNoConfirmer: Confirmer {
    public init() {}
    public func confirm(message: String, timeoutSeconds: Int) -> Bool { false }
}
