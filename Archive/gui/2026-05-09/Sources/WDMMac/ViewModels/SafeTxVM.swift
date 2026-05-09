import Foundation
import WDMKit

/// The GUI's bridge between the SwiftUI confirmation banner and WDMKit's
/// `Confirmer` protocol. Every mutating Kit op (`controller.main`,
/// `controller.rotate`, `controller.brightness`, …) takes a `Confirmer`
/// and blocks the calling thread inside `confirm(message:timeoutSeconds:)`
/// until the user keeps or reverts. SafeTxVM hands the Kit op a
/// `SafeTxBannerConfirmer` whose `confirm()` blocks on a semaphore while
/// the @Published banner state on this VM drives a SwiftUI overlay.
///
/// The Kit op MUST be invoked off the main actor (e.g. via
/// `Task.detached`) so the banner countdown can tick on the main actor
/// while the worker thread waits inside `confirm()`.
@MainActor
public final class SafeTxVM: ObservableObject {
    @Published public private(set) var visible: Bool = false
    @Published public private(set) var message: String = ""
    @Published public private(set) var secondsRemaining: Int = 0

    private var pendingDecision: (@Sendable (Bool) -> Void)?
    private var countdownTask: Task<Void, Never>?

    public init() {}

    /// The Confirmer the GUI hands to a Kit op. One outstanding
    /// `confirm()` at a time — concurrent mutations queue at the call
    /// site (the Inspector disables buttons while a banner is up).
    public var confirmer: Confirmer { SafeTxBannerConfirmer(vm: self) }

    /// Resolve the pending Confirmer with `keep = true`. Bound to the
    /// SwiftUI banner's "Keep" affordance and the SPACE key handler.
    public func keep() { resolve(true) }

    /// Resolve the pending Confirmer with `keep = false`. Bound to the
    /// banner's "Revert" affordance and any non-SPACE key.
    public func revert() { resolve(false) }

    /// Called from the Confirmer (background thread) — hops onto the
    /// main actor to flip @Published state and start the countdown.
    fileprivate nonisolated func presentFromBackground(
        message: String,
        totalSeconds: Int,
        decision: @escaping @Sendable (Bool) -> Void
    ) {
        Task { @MainActor [weak self] in
            self?.present(message: message, totalSeconds: totalSeconds, decision: decision)
        }
    }

    private func present(
        message: String,
        totalSeconds: Int,
        decision: @escaping @Sendable (Bool) -> Void
    ) {
        self.message = message
        self.secondsRemaining = totalSeconds
        self.visible = true
        self.pendingDecision = decision
        self.countdownTask?.cancel()
        self.countdownTask = Task { [weak self] in
            await self?.runCountdown(seconds: totalSeconds)
        }
    }

    private func runCountdown(seconds: Int) async {
        var remaining = seconds
        while remaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            remaining -= 1
            self.secondsRemaining = remaining
        }
        self.resolve(false)
    }

    private func resolve(_ keep: Bool) {
        guard let decision = pendingDecision else { return }
        pendingDecision = nil
        countdownTask?.cancel()
        countdownTask = nil
        visible = false
        message = ""
        secondsRemaining = 0
        decision(keep)
    }
}

/// Sendable Confirmer that synchronously blocks its caller until the
/// SafeTxVM resolves the decision. Lives in this file so the
/// VM-to-Confirmer wiring is a single, self-contained unit.
private struct SafeTxBannerConfirmer: Confirmer {
    let vm: SafeTxVM

    func confirm(message: String, timeoutSeconds: Int) -> Bool {
        final class Box: @unchecked Sendable {
            var value: Bool = false
        }
        let box = Box()
        let sema = DispatchSemaphore(value: 0)
        vm.presentFromBackground(message: message, totalSeconds: timeoutSeconds) { keep in
            box.value = keep
            sema.signal()
        }
        sema.wait()
        return box.value
    }
}
