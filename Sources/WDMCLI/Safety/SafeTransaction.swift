import WDMCore
import WDMSystem

/// Wraps a mutating provider call with a snapshot/confirm/revert cycle.
/// 1. Take a "before" snapshot.
/// 2. Run the apply closure.
/// 3. If the apply returned .applied, ask the confirmer.
/// 4. If the confirmer says no (or times out), reapply the "before" snapshot.
public enum SafeTransaction {
    public static func run(
        provider: DisplayProvider,
        confirmer: Confirmer,
        timeoutSeconds: Int,
        apply: () throws -> ApplyResult
    ) throws -> ApplyResult {
        let before = try provider.snapshot()
        let result = try apply()
        guard result == .applied else { return result }
        if confirmer.confirm(timeoutSeconds: timeoutSeconds) {
            return .applied
        }
        try ProfileApplier.apply(target: before, using: provider, options: .noConfirm)
        return .reverted
    }
}
