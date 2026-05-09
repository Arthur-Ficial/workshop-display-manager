import Foundation
import WDMRemoteControl

enum ClickCommand {
    static func run(client: RemoteClient, args: [String], stdout: FileHandle) throws -> Int32 {
        guard let raw = args.first else {
            FileHandle.standardError.write(Data("usage: wdm-mac-control click <ref e.g. @e2>\n".utf8))
            return 2
        }
        guard let ref = Ref(raw) else {
            FileHandle.standardError.write(Data("invalid ref: \(raw)\n".utf8))
            return 2
        }
        let body = Data(#"{"ref":"\#(ref.rawValue)"}"#.utf8)
        let data = try client.post("/ui/click", body: body)
        var out = data
        out.append(0x0a)
        stdout.write(out)
        return 0
    }
}
