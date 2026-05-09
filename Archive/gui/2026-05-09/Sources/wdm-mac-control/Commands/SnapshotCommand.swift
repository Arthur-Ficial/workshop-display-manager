import Foundation
import WDMRemoteControl

enum SnapshotCommand {
    static func run(client: RemoteClient, args: [String], stdout: FileHandle) throws -> Int32 {
        var pretty = true
        for a in args {
            if a == "--json" { pretty = false }
        }
        let data = try client.get("/ui/snapshot")
        if pretty {
            // Render a tidy ASCII table for humans
            let tree = try SceneTreeJSON.decode(data)
            stdout.write(Data(formatTable(tree).utf8))
        } else {
            // Pass-through JSON for pipelines (jq-friendly)
            var out = data
            out.append(0x0a) // newline
            stdout.write(out)
        }
        return 0
    }

    private static func formatTable(_ tree: SceneTree) -> String {
        var s = "ref   role     remoteID                    label                  selected\n"
        s += "----  -------  --------------------------  ---------------------  --------\n"
        for n in tree.nodes {
            s += pad(n.ref.rawValue, 4) + "  "
            s += pad(n.role, 7) + "  "
            s += pad(n.remoteID, 26) + "  "
            s += pad(n.label ?? "", 21) + "  "
            s += (n.state.selected ? "✓" : " ") + "\n"
        }
        s += "\n(\(tree.nodes.count) interactive node\(tree.nodes.count == 1 ? "" : "s"), version \(tree.version))\n"
        return s
    }

    private static func pad(_ s: String, _ n: Int) -> String {
        s.count >= n ? String(s.prefix(n)) : s + String(repeating: " ", count: n - s.count)
    }
}
