import SwiftUI
import WDMCore

/// About pane — app name, version, links. Reads version from
/// `WDMCore.Version.current` so there is exactly ONE place version
/// lives in the codebase.
public struct AboutPane: View {
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Workshop Display Manager")
                    .font(.system(size: 22, weight: .semibold))
                Text("wdm-mac · \(Version.current)").foregroundStyle(.secondary)
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
