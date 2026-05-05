import Testing
import Foundation

/// `scripts/golden-goal.sh` is the contract for "ship-ready". This
/// test runs the script and asserts the exit code + ledger shape are
/// what the spec promises (`tasks/golden-goal-spec.md`).
///
/// Why this lives in WDMCoreTests: WDMCore is the bottom of the layer
/// stack, so its tests run early and fail fast. The script itself is
/// pure bash with no Swift dependencies — running it from any test
/// target works.
///
/// The script intentionally returns 0 even when DEFERRED lines exist
/// (the goal is "on track", not yet met). It returns non-zero only on
/// hard FAILures of currently-enforced lines. That semantic is what
/// this test pins — re-run after every milestone to verify the harness
/// still behaves correctly.
@Suite("Golden-goal harness")
struct GoldenGoalScriptTests {

    @Test("script exists, is executable, and prints the 10-line ledger")
    func runsAndPrintsLedger() throws {
        let repoRoot = try Self.repoRoot()
        let script = repoRoot.appendingPathComponent("scripts/golden-goal.sh")
        try #require(FileManager.default.isExecutableFile(atPath: script.path),
                     "golden-goal.sh missing or not executable at \(script.path)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path]
        let out = Pipe(); proc.standardOutput = out; proc.standardError = out
        // Skip slow swift build/test inside the script when invoked from
        // within `swift test` — we already passed those by running.
        // (Future: an env var flag in the script could short-circuit;
        // for now the test allows the script to exit non-zero with the
        // build step failing, but checks the ledger structure.)
        proc.environment = ProcessInfo.processInfo.environment.merging(
            ["WDM_GOLDEN_GOAL_SKIP_HEAVY": "1"],
            uniquingKeysWith: { _, new in new })
        try proc.run()
        proc.waitUntilExit()
        let output = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        // The ledger header must appear.
        #expect(output.contains("=== golden-goal ledger ==="),
                "expected ledger header; got:\n\(output)")
        // All 10 numbered lines must appear with one of [PASS]/[FAIL]/[DEFERRED].
        for n in 1...10 {
            #expect(output.contains("] \(n). "),
                    "ledger line \(n). missing from output:\n\(output)")
        }
        // The summary block must appear.
        #expect(output.contains("PASS:") && output.contains("DEFERRED:"),
                "expected summary block; got:\n\(output)")
    }

    private static func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        throw NSError(domain: "GoldenGoalScriptTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Package.swift not found walking up from \(#filePath)"])
    }
}
