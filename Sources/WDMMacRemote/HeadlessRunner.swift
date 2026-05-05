import Foundation
import WDMMac
import WDMRemoteControl

/// Headless mode: build the VM, populate the registry, start the remote
/// server, write the state file, block. No window, no Dock entry. Powers
/// the e2e test (and the future MCP server frontend).
public enum HeadlessRunner {
    @MainActor
    public static func run(args: MacArgs) throws -> Never {
        let runtime = try MacRuntime.make()
        let server = try RemoteControlServer(port: args.port, target: runtime.adapter)
        HeadlessRunnerHolder.shared.retain(vm: runtime.vm, runner: runtime.runner)

        server.runAsync()
        let resolvedPort = server.resolvedPort() ?? args.port
        let state = RemoteState(
            port: resolvedPort,
            pid: ProcessInfo.processInfo.processIdentifier,
            startedAt: Date(),
            version: "wdm-mac/0.1"
        )
        let path = args.statePath.map(URL.init(fileURLWithPath:))
            ?? RemoteStateWriter.defaultPath()
        try RemoteStateWriter.write(state, to: path)
        FileHandle.standardError.write(Data(
            "wdm-mac --remote --headless: listening on 127.0.0.1:\(resolvedPort) (state: \(path.path))\n".utf8
        ))

        signal(SIGINT) { _ in exit(0) }
        signal(SIGTERM) { _ in exit(0) }
        // dispatchMain() converts the main thread into a libdispatch worker;
        // the server's queue continues to handle connections.
        dispatchMain()
    }
}

/// Keeps headless-mode references retained for the process lifetime.
@MainActor
final class HeadlessRunnerHolder {
    static let shared = HeadlessRunnerHolder()
    private var refs: [Any] = []
    func retain(vm: AnyObject, runner: AnyObject) { refs.append(vm); refs.append(runner) }
}
