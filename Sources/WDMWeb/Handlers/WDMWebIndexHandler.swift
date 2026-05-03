import Foundation
import WDMKit

/// `GET /` — a single self-contained HTML page that renders the live display
/// arrangement as scaled SVG rectangles. Polls `GET /arrangement` every
/// second so plugging in a monitor or running `wdm move` shows up live.
/// Data source is the same `WDMController.list()` the CLI uses — no
/// duplication.
public enum WDMWebIndexHandler {
    public static func handle(_: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        let displays = (try? deps.controller.list()) ?? []
        let html = render(displays: displays)
        return WDMWebResponse(status: 200, body: Data(html.utf8),
                              contentType: "text/html; charset=utf-8")
    }

    static func render(displays: [DisplayInfo]) -> String {
        let bounds = computeBounds(displays)
        let scale = chooseScale(bounds: bounds)
        let canvasW = Int(Double(bounds.width) * scale) + 80
        let canvasH = Int(Double(bounds.height) * scale) + 80
        let rects = displays.map { rect(for: $0, bounds: bounds, scale: scale) }
            .joined(separator: "\n")
        return template(canvasW: canvasW, canvasH: canvasH, rects: rects,
                        displays: displays)
    }

    static func computeBounds(_ displays: [DisplayInfo]) -> (minX: Int, minY: Int, width: Int, height: Int) {
        guard !displays.isEmpty else { return (0, 0, 100, 100) }
        let minX = displays.map { $0.origin.x }.min() ?? 0
        let minY = displays.map { $0.origin.y }.min() ?? 0
        let maxX = displays.map { $0.origin.x + $0.currentMode.width }.max() ?? 100
        let maxY = displays.map { $0.origin.y + $0.currentMode.height }.max() ?? 100
        return (minX, minY, maxX - minX, maxY - minY)
    }

    static func chooseScale(bounds: (minX: Int, minY: Int, width: Int, height: Int)) -> Double {
        let target = 900.0
        return min(target / Double(max(bounds.width, 1)), target / Double(max(bounds.height, 1)))
    }

    static func rect(for d: DisplayInfo,
                     bounds: (minX: Int, minY: Int, width: Int, height: Int),
                     scale: Double) -> String {
        let x = Int(Double(d.origin.x - bounds.minX) * scale) + 40
        let y = Int(Double(d.origin.y - bounds.minY) * scale) + 40
        let w = Int(Double(d.currentMode.width) * scale)
        let h = Int(Double(d.currentMode.height) * scale)
        let label = (d.name ?? "display \(d.id)") + (d.isMain ? " (MAIN)" : "")
        let fill = d.isMain ? "#3b82f6" : "#475569"
        let info = "\(d.currentMode.width)×\(d.currentMode.height)@\(d.currentMode.refreshHz)Hz · origin (\(d.origin.x),\(d.origin.y))"
        return """
          <g>
            <rect x="\(x)" y="\(y)" width="\(w)" height="\(h)"
                  fill="\(fill)" fill-opacity="0.18"
                  stroke="\(fill)" stroke-width="2" rx="6"/>
            <text x="\(x + 8)" y="\(y + 22)" font-size="14" font-weight="600" fill="#0f172a">\(escape(label))</text>
            <text x="\(x + 8)" y="\(y + 40)" font-size="12" fill="#475569">\(escape(info))</text>
            <text x="\(x + 8)" y="\(y + h - 8)" font-size="11" fill="#94a3b8">id \(d.id)</text>
          </g>
        """
    }

    static func template(canvasW: Int, canvasH: Int, rects: String,
                         displays: [DisplayInfo]) -> String {
        let rows = displays.map {
            "<tr><td>\($0.id)</td><td>\(escape($0.name ?? "-"))</td>" +
            "<td>\($0.currentMode.width)×\($0.currentMode.height)@\($0.currentMode.refreshHz)Hz</td>" +
            "<td>(\($0.origin.x), \($0.origin.y))</td>" +
            "<td>\($0.rotationDegrees)°</td>" +
            "<td>\($0.isMain ? "✓" : "")</td></tr>"
        }.joined(separator: "\n")
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>wdm — live arrangement</title>
          <style>
            body { font: 14px -apple-system, system-ui, sans-serif; color: #0f172a;
                   background: #f8fafc; margin: 24px; max-width: 1100px; }
            h1 { font-size: 18px; margin: 0 0 4px; }
            p.sub { margin: 0 0 18px; color: #64748b; }
            .canvas { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 8px; }
            table { border-collapse: collapse; margin-top: 18px; width: 100%; }
            th, td { text-align: left; padding: 6px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; }
            th { background: #f1f5f9; font-weight: 600; }
            code { background: #e2e8f0; padding: 2px 6px; border-radius: 3px; font-size: 12px; }
          </style>
        </head>
        <body>
          <h1>wdm · live display arrangement</h1>
          <p class="sub">Same data as <code>wdm arrange list --json</code>. Auto-refreshes every 2 s.</p>
          <div class="canvas">
            <svg width="\(canvasW)" height="\(canvasH)" xmlns="http://www.w3.org/2000/svg">
              \(rects)
            </svg>
          </div>
          <table>
            <thead><tr><th>id</th><th>name</th><th>mode</th><th>origin</th><th>rot</th><th>main</th></tr></thead>
            <tbody>\(rows)</tbody>
          </table>
          <script>setTimeout(() => location.reload(), 2000);</script>
        </body>
        </html>
        """
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
