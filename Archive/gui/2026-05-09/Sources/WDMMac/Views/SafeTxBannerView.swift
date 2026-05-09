import SwiftUI

/// Compact glass-effect banner pinned to the bottom of the window. Shown
/// while a `SafeTxVM` is awaiting a keep/revert decision after a mutating
/// Kit op completes. Mirrors the CLI's "press y in 15s to keep, anything
/// else reverts" prompt — but on macOS Tahoe glass and driven by the
/// same `Confirmer` protocol.
///
/// Interactive elements:
///   - **Keep** (`safetx.banner.keep` / SPACE) — Confirmer returns true.
///   - **Revert** (`safetx.banner.revert` / ESC) — Confirmer returns false.
///   - **Countdown chip** (`safetx.banner.countdown`) — passive.
///
/// On timeout, `SafeTxVM` auto-resolves with `false` per CLAUDE.md
/// safety pillar (unconfirmed = reverted).
public struct SafeTxBannerView: View {
    @ObservedObject var vm: SafeTxVM

    public init(vm: SafeTxVM) {
        self.vm = vm
    }

    public var body: some View {
        if vm.visible {
            GlassPanel(cornerRadius: 14) {
                HStack(spacing: 14) {
                    countdownChip
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.message.isEmpty ? "Display change applied" : vm.message)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                        Text("Reverting in \(vm.secondsRemaining)s · SPACE keeps")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    revertButton
                    keepButton
                }
                .frame(minWidth: 360)
            }
            .padding(.bottom, 18)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("safetx.banner")
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var countdownChip: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 2)
                .frame(width: 30, height: 30)
            Text("\(vm.secondsRemaining)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .accessibilityIdentifier("safetx.banner.countdown")
    }

    private var keepButton: some View {
        Button("Keep") { vm.keep() }
            .liquidGlassButton()
            .accessibilityIdentifier("safetx.banner.keep")
            .keyboardShortcut(.space, modifiers: [])
    }

    private var revertButton: some View {
        Button("Revert") { vm.revert() }
            .liquidGlassButton()
            .accessibilityIdentifier("safetx.banner.revert")
            .keyboardShortcut(.escape, modifiers: [])
    }
}
