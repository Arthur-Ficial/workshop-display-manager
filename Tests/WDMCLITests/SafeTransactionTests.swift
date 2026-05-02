import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem
@testable import WDMCLI

/// Confirmer stub: returns the configured answer, records calls.
final class StubConfirmer: Confirmer, @unchecked Sendable {
    var answer: Bool
    var calls = 0
    init(answer: Bool) { self.answer = answer }
    func confirm(timeoutSeconds: Int) -> Bool {
        calls += 1
        return answer
    }
}

@Suite("SafeTransaction")
struct SafeTransactionTests {

    private func makeProvider() throws -> FixtureDisplayProvider {
        let url = try CLITestHarness.makeFixture()
        return try FixtureDisplayProvider(fixtureURL: url)
    }

    @Test("user confirms → change persists")
    func confirmKeeps() throws {
        let provider = try makeProvider()
        let confirmer = StubConfirmer(answer: true)
        let result = try SafeTransaction.run(
            provider: provider,
            confirmer: confirmer,
            timeoutSeconds: 1,
            apply: { try provider.setMain(displayID: 2, options: .noConfirm) }
        )
        #expect(result == .applied)
        #expect(try provider.snapshot().main?.id == 2)
        #expect(confirmer.calls == 1)
    }

    @Test("user declines → change reverted to pre-state")
    func declineReverts() throws {
        let provider = try makeProvider()
        let confirmer = StubConfirmer(answer: false)
        let result = try SafeTransaction.run(
            provider: provider,
            confirmer: confirmer,
            timeoutSeconds: 1,
            apply: { try provider.setMain(displayID: 2, options: .noConfirm) }
        )
        #expect(result == .reverted)
        #expect(try provider.snapshot().main?.id == 1, "main must revert to original")
    }

    @Test("apply returning .noChange skips confirmation")
    func noChangeSkips() throws {
        let provider = try makeProvider()
        let confirmer = StubConfirmer(answer: false)
        let result = try SafeTransaction.run(
            provider: provider,
            confirmer: confirmer,
            timeoutSeconds: 1,
            apply: { try provider.setMain(displayID: 1, options: .noConfirm) }   // already main
        )
        #expect(result == .noChange)
        #expect(confirmer.calls == 0)
    }
}
