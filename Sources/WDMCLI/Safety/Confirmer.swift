public protocol Confirmer: Sendable {
    /// Block up to `timeoutSeconds` waiting for user confirmation.
    /// Return true to keep the change, false to revert.
    func confirm(timeoutSeconds: Int) -> Bool
}
