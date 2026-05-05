import SwiftUI

/// Bottom footer per the design briefing. Single source of truth for
/// "what's happening right now": daemon dot, real/virtual/pip counts,
/// timestamp + last event, Watch + Advanced toggles on the right.
public struct StatusBarView: View {
    @ObservedObject var vm: DisplaysListVM

    public init(vm: DisplaysListVM) { self.vm = vm }

    public var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("Daemon").font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("statusbar.daemon")

            divider

            countPill(value: vm.tiles.count, label: "real")
                .accessibilityIdentifier("statusbar.count.real")
            countPill(value: 0, label: "virtual")
                .accessibilityIdentifier("statusbar.count.virtual")
            countPill(value: 0, label: "pip")
                .accessibilityIdentifier("statusbar.count.pip")

            Spacer()

            // TimelineView ticks once a second so the wall-clock display
            // stays current — without it the timestamp froze at first paint.
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                HStack(spacing: 6) {
                    Text(Self.formatter.string(from: ctx.date))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("·").foregroundStyle(.secondary)
                    Text(lastEvent).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                // Collapse into a single AX node — without this each Text
                // child inherits the parent identifier and /ui/snapshot
                // emits the same remoteID 3×.
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("statusbar.lastEvent")
            }

            Spacer()

            toggle("Watch", "eye")
                .accessibilityIdentifier("statusbar.toggle.watch")
            toggle("Advanced", "slider.horizontal.3")
                .accessibilityIdentifier("statusbar.toggle.advanced")
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .frame(height: 30)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.10)).frame(width: 1, height: 14)
    }

    private func countPill(value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)").font(.system(size: 11, weight: .semibold))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        // Collapse the inner Text children so the .accessibilityIdentifier
        // applied at the call site lands on a single AX node, not both.
        .accessibilityElement(children: .combine)
    }

    private func toggle(_ label: String, _ symbol: String) -> some View {
        Button {} label: {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(label).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .clickable(cornerRadius: 5)
    }

    private var lastEvent: String {
        if let main = vm.tiles.first(where: \.isMain) {
            return "\(main.title) is main"
        }
        return "ready"
    }

    /// Cached formatter — re-allocating on every body call was a hot
    /// path leak; DateFormatter is heavyweight to construct.
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
