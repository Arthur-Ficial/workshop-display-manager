import WDMCore

public enum SnapshotTableFormatter {
    public static func format(_ snapshot: Snapshot) -> String {
        let header = ["ID", "NAME", "MODE", "ORIGIN", "ROT", "MAIN", "MIRROR"]
        let rows: [[String]] = snapshot.displays.map { d in
            [
                String(d.id),
                d.name ?? "-",
                d.currentMode.description,
                "\(d.origin.x),\(d.origin.y)",
                String(d.rotationDegrees),
                d.isMain ? "*" : " ",
                d.mirrorSource.map(String.init) ?? "-",
            ]
        }
        return Self.render(header: header, rows: rows)
    }

    private static func render(header: [String], rows: [[String]]) -> String {
        let all = [header] + rows
        let widths = (0..<header.count).map { col in
            all.map { $0[col].count }.max() ?? 0
        }
        let format: ([String]) -> String = { cells in
            cells.enumerated()
                .map { idx, cell in cell.padding(toLength: widths[idx], withPad: " ", startingAt: 0) }
                .joined(separator: "  ")
                .trimmingCharacters(in: .whitespaces)
        }
        return ([format(header)] + rows.map(format)).joined(separator: "\n") + "\n"
    }
}
