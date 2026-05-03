public protocol Confirmer: Sendable {
    /// Block up to `timeoutSeconds` waiting for user confirmation.
    /// `message` is a one-line description of what was just applied
    /// (e.g. "Set display 2 to 1280x720@60") for display in the prompt.
    /// Return true to keep the change, false to revert.
    func confirm(message: String, timeoutSeconds: Int) -> Bool
}
