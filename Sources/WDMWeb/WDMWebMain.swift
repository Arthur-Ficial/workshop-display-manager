import Foundation
import WDMKit

/// Process entry point for `wdm-web`. Parses argv, builds a controller from
/// the same factories the CLI uses, and runs the server until SIGTERM/SIGINT.
public enum WDMWebMain {
    public static func run() {
        let args = Array(CommandLine.arguments.dropFirst())
        var port: UInt16 = 8080
        var listen: String = "127.0.0.1"
        var iter = args.makeIterator()
        while let token = iter.next() {
            switch token {
            case "--port":
                if let s = iter.next(), let p = UInt16(s) { port = p }
            case "--listen":
                if let s = iter.next() { listen = s }
            case "--help", "-h":
                printUsage()
                return
            default:
                break
            }
        }
        let env = ProcessInfo.processInfo.environment
        let deps: WDMWebDeps
        do {
            deps = try WDMWebControllerFactory.make(env: env)
        } catch {
            FileHandle.standardError.write(Data("wdm-web: provider build failed: \(error)\n".utf8))
            exit(1)
        }
        let server: WDMWebServer
        do {
            server = try WDMWebServer(host: listen, port: port, deps: deps)
        } catch {
            FileHandle.standardError.write(Data("wdm-web: bind failed: \(error)\n".utf8))
            exit(1)
        }
        FileHandle.standardError.write(Data("wdm-web: listening on http://\(listen):\(server.port)\n".utf8))
        server.run()
    }

    private static func printUsage() {
        FileHandle.standardError.write(Data("usage: wdm-web [--listen <addr>] [--port <n>]\n".utf8))
    }
}
