import Foundation
import WDMCLI

let args = Array(CommandLine.arguments.dropFirst())
let env = ProcessInfo.processInfo.environment
let stdout = StreamOutputWriter(handle: .standardOutput)
let stderr = StreamOutputWriter(handle: .standardError)
let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
exit(code)
