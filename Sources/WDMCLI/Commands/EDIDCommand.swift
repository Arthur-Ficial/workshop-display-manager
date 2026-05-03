import Foundation
import WDMCore
import WDMSystem

/// `wdm edid <id> [--raw|--json]` — dump the parsed Extended Display
/// Identification Data for a display. Foundation for stable per-display
/// identity that survives reboot, replug, and port changes.
public enum EDIDCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let positional = Args.positional(args)
        let raw = args.contains("--raw")
        let json = args.contains("--json")
        guard let alias = positional.first else {
            throw CLIError.usage("usage: wdm edid <id|main> [--raw|--json]")
        }
        let snapshot = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snapshot)
        let edid: EDID
        do {
            edid = try deps.provider.edid(for: id)
        } catch ProviderError.edidUnavailable(let i) {
            deps.stderr.writeLine(
                "wdm edid: no EDID for display \(i) " +
                "(virtual display, AirPlay receiver, or driver does not expose it)"
            )
            return ExitCodes.modeNotSupported
        }

        if raw {
            deps.stdout.writeLine(formatHex(edid.raw))
            return ExitCodes.success
        }
        if json {
            deps.stdout.write(try Self.encodeJSON(edid))
            return ExitCodes.success
        }
        deps.stdout.write(formatHuman(edid, displayID: id))
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
        // Hand-roll so the byte array doesn't bloat the output unless --raw is asked.
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
