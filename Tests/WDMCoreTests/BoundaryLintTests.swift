import Testing
import Foundation

/// Architectural boundary lint, enforced as a hermetic test so a
/// bypassed pre-commit hook cannot land a violation. Wraps
/// `scripts/lint-no-gui-logic.sh` — the same script `make
/// lint-no-gui-logic` runs.
///
/// Why this lives in `Tests/WDMCoreTests/`: WDMCore is the bottom of
/// the layer stack, so its tests run early and fail fast. The lint
/// script itself is pure bash with no Swift dependencies — calling it
/// from any test target works.
@Suite("Architectural boundaries")
struct BoundaryLintTests {

    @Test("GUI modules contain no business-logic extensions on lib types")
    func noGuiLogic() throws {
        try Self.runLint(named: "lint-no-gui-logic.sh")
    }

    @Test("Every CLI verb has a GUI surface or is on the documented allowlist")
    func guiParity() throws {
        try Self.runLint(named: "lint-gui-parity.sh")
    }

    @Test("Every CLI verb has at least one e2e test under Tests/WDMCLITests")
    func everyVerbHasE2E() throws {
        try Self.runLint(named: "lint-every-verb-has-e2e.sh")
    }

    @Test("No Sources/ Swift file > 150 lines (whitelist for refactor backlog)")
    func fileSize() throws {
        try Self.runLint(named: "lint-file-size.sh")
    }

    @Test("No Swift function > 30 lines (whitelist for refactor backlog)")
    func functionSize() throws {
        try Self.runLint(named: "lint-function-size.sh")
    }

    @Test("No Swift function with cyclomatic complexity > 7 (whitelist for refactor backlog)")
    func cyclomaticComplexity() throws {
        try Self.runLint(named: "lint-cyclomatic-complexity.sh")
    }

    @Test("No 'and' segments in function names; no grab-bag filenames")
    func naming() throws {
        try Self.runLint(named: "lint-naming.sh")
    }

    @Test("Public-surface lint runs cleanly (soft — warnings allowed)")
    func publicSurface() throws {
        // Public-surface is SOFT by default. Just assert the script
        // exits 0 (warnings printed, no hard failure). When the
        // whitelist is curated, strict mode can be turned on here.
        try Self.runLint(named: "lint-public-surface.sh")
    }

    @Test("No known crash-generating patterns (NO CRASHES pillar)")
    func crashRegression() throws {
        try Self.runLint(named: "lint-crash-regression.sh")
    }

    @Test("Capture paths use native pixel dims (CRISP RENDERING pillar)")
    func renderingPixelDims() throws {
        try Self.runLint(named: "lint-rendering-pixel-dims.sh")
    }

    @Test("No fakes / stub markers in production (NO FAKES pillar)")
    func noFakes() throws {
        try Self.runLint(named: "lint-no-fakes.sh")
    }

    private static func runLint(named: String) throws {
        let repoRoot = try Self.repoRoot()
        let script = repoRoot.appendingPathComponent("scripts/\(named)")
        try #require(FileManager.default.isExecutableFile(atPath: script.path),
                     "lint script missing or not executable at \(script.path)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path]
        let out = Pipe(); proc.standardOutput = out; proc.standardError = out
        try proc.run()
        proc.waitUntilExit()
        let output = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        #expect(proc.terminationStatus == 0,
                "\(named) failed:\n\(output)")
    }

    private static func repoRoot() throws -> URL {
        // Walk up from this source file until we see Package.swift.
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        throw NSError(domain: "BoundaryLintTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "could not find Package.swift walking up from \(#filePath)"])
    }
}
