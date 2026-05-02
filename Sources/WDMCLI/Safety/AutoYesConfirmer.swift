public struct AutoYesConfirmer: Confirmer {
    public init() {}
    public func confirm(timeoutSeconds: Int) -> Bool { true }
}

public struct AutoNoConfirmer: Confirmer {
    public init() {}
    public func confirm(timeoutSeconds: Int) -> Bool { false }
}
