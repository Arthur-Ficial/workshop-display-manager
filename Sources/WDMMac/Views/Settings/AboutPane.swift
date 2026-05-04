import SwiftUI

/// About pane — app name, version, links. Static for now.
public struct AboutPane: View {
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Workshop Display Manager")
                    .font(.system(size: 22, weight: .semibold))
                Text("wdm-mac · 0.1.0").foregroundStyle(.secondary)
                    .font(.system(size: 12, design: .monospaced))
            }
            VStack(alignment: .leading, spacing: 4) {
                KVRow("Engine", "WDMKit on Swift 6.3")
                KVRow("Frontend", "WDMMac (SwiftUI, macOS 26)")
                KVRow("Remote API", "127.0.0.1 (--remote)")
                KVRow("License", "Proprietary, all rights reserved")
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("settings.pane.about")
    }
}
