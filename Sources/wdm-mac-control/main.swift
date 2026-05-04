import Foundation
import WDMRemoteControl

let argv = Array(CommandLine.arguments.dropFirst())
let stdout = FileHandle.standardOutput
let stderr = FileHandle.standardError

let usage = """
USAGE: wdm-mac-control <verb> [args]

Verbs (M1):
  snapshot [--json]      print the current scene tree (table or raw JSON)
  click <@eN>            POST /ui/click {"ref":"@eN"}
  close-window <name>    POST /ui/closeWindow {"name":"<name>"}
  version                print the running server version

Discovers a running `wdm-mac --remote` via ~/.config/wdm/remote.json
(override via WDM_REMOTE_STATE_FILE).
"""

guard let verb = argv.first else {
    stderr.write(Data((usage + "\n").utf8))
    exit(2)
}
let rest = Array(argv.dropFirst())

do {
    let state = try StateLoader.load(env: ProcessInfo.processInfo.environment)
    let client = RemoteClient(port: state.port)
    let code: Int32
    switch verb {
    case "snapshot":
        code = try SnapshotCommand.run(client: client, args: rest, stdout: stdout)
    case "click":
        code = try ClickCommand.run(client: client, args: rest, stdout: stdout)
    case "close-window":
        code = try CloseWindowCommand.run(client: client, args: rest, stdout: stdout)
    case "version":
        let data = try client.get("/ui/version")
        var out = data; out.append(0x0a)
        stdout.write(out)
        code = 0
    case "--help", "-h", "help":
        stdout.write(Data((usage + "\n").utf8))
        code = 0
    default:
        stderr.write(Data("wdm-mac-control: unknown verb '\(verb)'\n\n\(usage)\n".utf8))
        code = 2
    }
    exit(code)
} catch {
    stderr.write(Data("wdm-mac-control: \(error)\n".utf8))
    exit(1)
}
