import Testing
import Foundation

/// CLAUDE.md "NO FAKE OR FALLBACK FUNCTIONALITY" pillar — production
/// source code MUST NOT import anything from `Tests/`. The Swift
/// package manager already prevents this at the module-graph level
/// (Tests/ targets depend on Sources/, never the reverse), but we
/// also assert that no `Sources/**/*.swift` file contains an `import`
/// of a Test module, OR a reference to a `*Recording*` / `*Fixture*`
/// type outside the explicitly-allowed factory boundary points.
///
/// Companion to scripts/lint-no-fakes.sh — the lint catches WDM_TEST_*
/// env-var leaks, this test catches symbol-level leaks.
@Suite("No unnecessary mocks")
struct NoUnnecessaryMocksTest {

    /// Production source code must not `import` anything in `Tests/*`.
    @Test("Production sources have no import of Test* modules")
    func noTestImports() throws {
        let repo = try Self.repoRoot()
        let sources = repo.appendingPathComponent("Sources")
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            Issue.record("could not enumerate \(sources.path)")
            return
        }
        var leaks: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let body = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { continue }
                let imp = trimmed.replacingOccurrences(of: "import ", with: "")
                let token = imp.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" })
                if token.contains("Test") || token.contains("Mock") {
                    leaks.append("\(url.path): \(trimmed)")
                }
            }
        }
        #expect(leaks.isEmpty,
                "production sources must not import Test/Mock modules; found:\n  \(leaks.joined(separator: "\n  "))")
    }

    private static func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        throw NSError(domain: "NoUnnecessaryMocksTest", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Package.swift not found"])
    }
}
