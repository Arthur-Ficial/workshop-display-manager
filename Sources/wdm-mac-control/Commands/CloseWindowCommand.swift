import Foundation

enum CloseWindowCommand {
    static func run(client: RemoteClient, args: [String], stdout: FileHandle) throws -> Int32 {
        guard let name = args.first else {
            FileHandle.standardError.write(Data(
                "usage: wdm-mac-control close-window <window-name>\n".utf8))
            return 2
        }
        // JSON-escape the name (handle quotes / backslashes minimally).
        let escaped = name
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let body = Data(#"{"name":"\#(escaped)"}"#.utf8)
        let data = try client.post("/ui/closeWindow", body: body)
        var out = data; out.append(0x0a)
        stdout.write(out)
        return 0
    }
}
