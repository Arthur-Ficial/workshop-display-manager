import Foundation

/// argv → typed configuration. Hand-rolled (no ArgumentParser) to match the
/// `wdm` binary's pattern and keep deps lean. Unknown flags fail fast.
public struct MacArgs: Equatable, Sendable {
    public var remote: Bool = false
    public var headless: Bool = false
    public var port: UInt16 = 0
    public var statePath: String?

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case unknown(String)
        case missingValue(String)
        case badPort(String)

        public var description: String {
            switch self {
            case .unknown(let f): "unknown flag: \(f)"
            case .missingValue(let f): "missing value for \(f)"
            case .badPort(let p): "invalid --port value: \(p)"
            }
        }
    }

    public static func parse(_ argv: [String]) throws -> MacArgs {
        var out = MacArgs()
        var i = 0
        while i < argv.count {
            let a = argv[i]
            switch a {
            case "--remote":
                out.remote = true
            case "--headless":
                out.headless = true
            case "--port":
                guard i + 1 < argv.count else { throw ParseError.missingValue("--port") }
                guard let n = UInt16(argv[i + 1]) else { throw ParseError.badPort(argv[i + 1]) }
                out.port = n
                i += 1
            case "--state-file":
                guard i + 1 < argv.count else { throw ParseError.missingValue("--state-file") }
                out.statePath = argv[i + 1]
                i += 1
            case "--help", "-h":
                out.remote = false
                return out
            default:
                throw ParseError.unknown(a)
            }
            i += 1
        }
        return out
    }

    public static let usage = """
    USAGE: wdm-mac [--remote [--port N] [--headless] [--state-file PATH]]

    Without --remote, opens the GUI window normally.
    With --remote, starts an AI-controllable HTTP API on 127.0.0.1.
      --port N           explicit port (default: ephemeral free port)
      --headless         no window; remote API only (for tests + future MCP)
      --state-file PATH  override state file path (default: ~/.config/wdm/remote.json)

    See: docs/superpowers/specs/2026-05-04-ai-controllable-gui-design.md
    """
}
