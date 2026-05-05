import Foundation
import Testing

@Suite("WDMSystem signal policy")
struct SignalPolicyTests {
    @Test func systemLibraryDoesNotIgnoreProcessSignals() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let systemDir = packageRoot.appendingPathComponent("Sources/WDMSystem")
        let urls = FileManager.default.enumerator(at: systemDir,
                                                  includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []
        let offenders = try urls
            .filter { $0.pathExtension == "swift" }
            .compactMap { url -> String? in
                let text = try String(contentsOf: url, encoding: .utf8)
                return text.contains("SIG_IGN") ? url.lastPathComponent : nil
            }
            .sorted()

        #expect(offenders.isEmpty,
                "WDMSystem must not globally ignore SIGINT/SIGTERM/SIGHUP: \(offenders)")
    }
}
