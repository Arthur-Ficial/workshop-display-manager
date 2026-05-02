import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

@Suite("CGDisplayProvider display names (real hardware)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE"] == "1"))
struct CGDisplayProviderNamesTests {

    @Test("snapshot exposes a non-empty name for at least one display")
    func nameNonEmpty() throws {
        let provider = CGDisplayProvider()
        let snap = try provider.snapshot()
        let names = snap.displays.compactMap { $0.name }
        #expect(names.contains { !$0.isEmpty }, "expected at least one named display")
    }
}
