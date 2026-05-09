import Foundation

/// Persistent handshake file telling `wdm-mac-control` (or any client) where
/// the running `wdm-mac --remote` server is bound. Default location is
/// `~/.config/wdm/remote.json`; tests override via `WDM_REMOTE_STATE_FILE`.
public struct RemoteState: Codable, Equatable, Sendable {
    public let port: UInt16
    public let pid: Int32
    public let startedAt: Date
    public let version: String

    public init(port: UInt16, pid: Int32, startedAt: Date, version: String) {
        self.port = port
        self.pid = pid
        self.startedAt = startedAt
        self.version = version
    }
}

public enum RemoteStateWriter {
    public static func defaultPath(env: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = env["WDM_REMOTE_STATE_FILE"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        let home = env["HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: home)
            .appendingPathComponent(".config/wdm/remote.json")
    }

    @discardableResult
    public static func write(_ state: RemoteState, to path: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .prettyPrinted]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(state)
        try data.write(to: path, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
        return path
    }

    public static func read(from path: URL) throws -> RemoteState {
        let data = try Data(contentsOf: path)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(RemoteState.self, from: data)
    }

    public static func clear(at path: URL) {
        try? FileManager.default.removeItem(at: path)
    }
}
