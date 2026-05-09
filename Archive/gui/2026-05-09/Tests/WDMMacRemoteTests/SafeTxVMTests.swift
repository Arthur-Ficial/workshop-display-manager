import Testing
import Foundation
import WDMKit
@testable import WDMMac

/// SafeTxVM is the GUI's bridge between the SwiftUI confirmation banner
/// and the WDMKit `Confirmer` protocol the Kit ops require. The lib-level
/// contract is unchanged: `confirmer.confirm(message:timeoutSeconds:)`
/// blocks the *caller* thread until the user keeps or reverts. SafeTxVM's
/// job is to (a) flip @Published banner state on the main actor when a
/// Kit op asks for confirmation, (b) tick down `secondsRemaining` once
/// per second, (c) resolve to the boolean the Confirmer hands back.
///
/// These tests pin the contract WITHOUT spinning up a SwiftUI runtime —
/// the Confirmer round-trip works the same whether or not a banner view
/// is observing the VM.
@MainActor
@Suite("SafeTxVM Confirmer round-trip", .serialized)
struct SafeTxVMTests {
    @Test("keep() returns true and clears the banner")
    func keepReturnsTrue() async throws {
        let vm = SafeTxVM()
        let confirmer = vm.confirmer

        let resultTask = Task.detached { () -> Bool in
            confirmer.confirm(message: "Set display 2 main", timeoutSeconds: 30)
        }

        try await waitForVisible(vm: vm)
        vm.keep()

        let result = await resultTask.value
        #expect(result == true)
        #expect(vm.visible == false)
    }

    @Test("revert() returns false and clears the banner")
    func revertReturnsFalse() async throws {
        let vm = SafeTxVM()
        let confirmer = vm.confirmer

        let resultTask = Task.detached { () -> Bool in
            confirmer.confirm(message: "Set display 2 main", timeoutSeconds: 30)
        }

        try await waitForVisible(vm: vm)
        vm.revert()

        let result = await resultTask.value
        #expect(result == false)
        #expect(vm.visible == false)
    }

    @Test("timeout returns false (auto-revert)")
    func timeoutReturnsFalse() async throws {
        let vm = SafeTxVM()
        let confirmer = vm.confirmer

        let resultTask = Task.detached { () -> Bool in
            confirmer.confirm(message: "Set display 2 main", timeoutSeconds: 1)
        }

        let result = await resultTask.value
        #expect(result == false)
        #expect(vm.visible == false)
    }

    @Test("banner exposes message + initial countdown to observers")
    func bannerExposesMessageAndCountdown() async throws {
        let vm = SafeTxVM()
        let confirmer = vm.confirmer

        let resultTask = Task.detached { () -> Bool in
            confirmer.confirm(message: "Rotated display 1 to 90°", timeoutSeconds: 12)
        }

        try await waitForVisible(vm: vm)
        #expect(vm.message == "Rotated display 1 to 90°")
        #expect(vm.secondsRemaining == 12)

        vm.keep()
        _ = await resultTask.value
    }

    /// Spin up to ~3 s waiting for the @Published banner to flip visible.
    /// Polls instead of using Combine to keep the test independent of
    /// scheduler timing.
    private func waitForVisible(vm: SafeTxVM, timeoutMs: Int = 3000) async throws {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            if vm.visible { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("SafeTxVM banner never became visible within \(timeoutMs)ms")
    }
}
