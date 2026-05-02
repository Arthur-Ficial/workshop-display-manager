import Foundation

public enum LaunchAgentInstaller {
    public static let label = "com.fullstackoptimization.wdm"

    public static func plistContents(executablePath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
                <string>daemon</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/wdm-daemon.out.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/wdm-daemon.err.log</string>
            <key>ProcessType</key>
            <string>Background</string>
        </dict>
        </plist>
        """
    }

    public static func write(to url: URL, executablePath: String) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try plistContents(executablePath: executablePath).write(
            to: url, atomically: true, encoding: .utf8
        )
    }

    public static func defaultPlistURL() -> URL {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    // MARK: - parametrized plist for arbitrary `wdm` invocations

    /// Generic plist generator for any `wdm <args>` invocation. Used by
    /// `wdm virtual save --at-login` and any future `--at-login` verb.
    /// `KeepAlive = {SuccessfulExit: false}` matches the research finding:
    /// don't restart a successful one-shot scene-restore.
    public static func plistContents(label: String, executablePath: String, args: [String]) -> String {
        let argLines = ([executablePath] + args)
            .map { "        <string>\($0)</string>" }
            .joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
        \(argLines)
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
            <key>StandardOutPath</key>
            <string>/tmp/\(label).out.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/\(label).err.log</string>
            <key>ProcessType</key>
            <string>Background</string>
        </dict>
        </plist>
        """
    }

    public static func write(to url: URL, label: String, executablePath: String, args: [String]) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try plistContents(label: label, executablePath: executablePath, args: args).write(
            to: url, atomically: true, encoding: .utf8
        )
    }

    /// Default `~/Library/LaunchAgents/<label>.plist` URL, or override via env
    /// `WDM_LAUNCHAGENTS_DIR` (used by tests).
    public static func defaultPlistURL(forLabel label: String, env: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let p = env["WDM_LAUNCHAGENTS_DIR"], !p.isEmpty {
            return URL(fileURLWithPath: p).appendingPathComponent("\(label).plist")
        }
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
}
