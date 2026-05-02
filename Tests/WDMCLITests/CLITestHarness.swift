import Foundation
@testable import WDMCLI

/// Captures one CLI invocation for assertions.
struct CLIResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

enum CLITestHarness {

    /// Build a fresh fixture file for a single test and return the path.
    static func makeFixture(_ json: String? = nil) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-cli-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.json")
        let payload = json ?? defaultFixture
        try payload.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Invoke the CLI in-process. Equivalent to spawning the binary, but faster.
    /// The exact same code path is exercised end-to-end (parse → dispatch → write → exit code).
    static func run(_ args: [String], fixture: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = ["WDM_TEST_FIXTURE": fixture.path]
        let exitCode = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: exitCode, stdout: stdout.contents, stderr: stderr.contents)
    }

    static let defaultFixture = """
    {
      "snapshot": {
        "createdAt": 1700000000,
        "displays": [
          {
            "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
            "origin": { "x": 0, "y": 0 },
            "rotationDegrees": 0
          },
          {
            "id": 2, "name": "Projector", "isMain": false, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 2560, "y": 0 },
            "rotationDegrees": 0
          }
        ]
      },
      "availableModes": {
        "1": [
          { "width": 2560, "height": 1664, "refreshHz": 60 },
          { "width": 1920, "height": 1200, "refreshHz": 60 }
        ],
        "2": [
          { "width": 1920, "height": 1080, "refreshHz": 60 },
          { "width": 1280, "height": 720,  "refreshHz": 60 }
        ]
      }
    }
    """
}
