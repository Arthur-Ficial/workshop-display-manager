import Foundation
import WDMKit

/// `wdm edid <id> [--raw|--json]` — dump the parsed Extended Display
/// Identification Data for a display.
public enum EDIDCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let positional = Args.positional(args)
        guard let alias = positional.first else {
            throw WDMError.usage("usage: wdm edid <id|main> [--raw|--json]")
        }
        let edid = try deps.controller.edid(alias)
        let id = try deps.controller.get(alias).id

        if args.contains("--raw") {
            deps.stdout.writeLine(formatHex(edid.raw))
        } else if args.contains("--json") {
            deps.stdout.write(try encodeJSON(edid))
        } else {
            deps.stdout.write(formatHuman(edid, displayID: id))
        }
        return ExitCodes.success
    }

    private static func formatHuman(_ e: EDID, displayID: UInt32) -> String {
        var lines: [String] = []
        lines.append("display:        \(displayID)")
        lines.append("manufacturer:   \(e.manufacturerID)")
        lines.append("product:        0x\(String(format: "%04X", e.productCode))")
        lines.append("serial:         \(e.serialNumber)")
        lines.append("manufactured:   \(e.manufactureYear) week \(e.manufactureWeek)")
        lines.append("EDID version:   \(e.edidVersion)")
        lines.append("display name:   \(e.displayName ?? "-")")
        lines.append("serial string:  \(e.serialString ?? "-")")
        lines.append("stable ID:      \(e.stableID)")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func formatHex(_ bytes: [UInt8]) -> String {
        var out: [String] = []
        for chunk in stride(from: 0, to: bytes.count, by: 16) {
            let end = min(chunk + 16, bytes.count)
            let row = bytes[chunk..<end].map { String(format: "%02x", $0) }.joined(separator: " ")
            out.append(row)
        }
        return out.joined(separator: "\n")
    }

    private static func encodeJSON(_ e: EDID) throws -> String {
        let dict: [String: Any] = [
            "manufacturerID": e.manufacturerID,
            "productCode": Int(e.productCode),
            "serialNumber": Int(e.serialNumber),
            "manufactureWeek": Int(e.manufactureWeek),
            "manufactureYear": e.manufactureYear,
            "edidVersion": e.edidVersion,
            "displayName": e.displayName as Any? ?? NSNull(),
            "serialString": e.serialString as Any? ?? NSNull(),
            "stableID": e.stableID
        ]
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}
