import Testing
import Foundation
@testable import WDMCore

/// Asserts there is EXACTLY ONE place that defines the wdm version
/// constant. Per CLAUDE.md SSOT — every other reference (Info.plist,
/// AboutPane, manpage, --help text) must derive from it.
///
/// Verifies:
///   1. `WDMCore.Version.current` exists and is a non-empty semver
///      shape.
///   2. No other Sources/**/*.swift file defines a literal of the
///      same value (catches "I hardcoded 0.2.0 in two places").
@Suite("Version single source")
struct VersionSingleSourceTests {

    @Test("Version.current is a non-empty semver token")
    func semverShape() {
        let v = Version.current
        #expect(!v.isEmpty)
        let pattern = "^[0-9]+\\.[0-9]+\\.[0-9]+(-[A-Za-z0-9.]+)?$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(v.startIndex..., in: v)
        #expect(regex?.firstMatch(in: v, range: range) != nil,
                "version '\(v)' does not match semver pattern")
    }

    @Test("No other Sources/ file hardcodes Version.current as a string literal")
    func uniqueDefinition() throws {
        let repo = try Self.repoRoot()
        let v = Version.current
        let sources = repo.appendingPathComponent("Sources")
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            Issue.record("could not enumerate \(sources.path)")
            return
        }
        var hardcoded: [String] = []
        let allowed = sources.appendingPathComponent("WDMCore/Version.swift").path
        for case let url as URL in walker where url.pathExtension == "swift" {
            if url.path == allowed { continue }
            guard let body = try? String(contentsOf: url, encoding: .utf8) else { continue }
            // Look for "<v>" string literal, with minor whitespace lenience.
            if body.contains("\"\(v)\"") {
                hardcoded.append(url.lastPathComponent)
            }
        }
        #expect(hardcoded.isEmpty,
                "version '\(v)' hardcoded outside Version.swift — SSOT violation:\n  \(hardcoded.joined(separator: "\n  "))")
    }

    private static func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        throw NSError(domain: "VersionSingleSourceTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Package.swift not found"])
    }
}
