import SwiftUI

/// Left column. Three sections, each rendered via the same `SectionHeader`
/// + content composition — DRY across DISPLAYS / VIRTUAL / PROFILES.
public struct SidebarView: View {
    @ObservedObject var vm: DisplaysListVM
    let onSelect: (String) -> Void

    public init(vm: DisplaysListVM, onSelect: @escaping (String) -> Void) {
        self.vm = vm
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            connectedSection
            virtualSection
            profilesSection
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 16)
        .frame(width: 220, alignment: .leading)
    }

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "DISPLAYS", count: vm.tiles.count)
            ForEach(vm.tiles) { tile in
                SidebarDisplayRow(tile: tile,
                                  isSelected: vm.isSelected(tile),
                                  onSelect: onSelect)
            }
        }
    }

    private var virtualSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "VIRTUAL", count: 0)
            EmptyHint("No virtual displays.", remoteID: "sidebar.virtual.empty")
            // Honest-refusal CTA — clicking sets virtualUnavailableMessage,
            // which surfaces in the registry as `sidebar.virtual.lastError`
            // so AI agents see "this isn't wired yet" instead of a silent
            // no-op. Visual pattern matches PROFILES' "+ Save current as…".
            Button { vm.refuseVirtualCreate() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                    Text("Add virtual display")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sidebar.virtual.add")
            .padding(.top, 2)

            if let msg = vm.virtualUnavailableMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .accessibilityIdentifier("sidebar.virtual.lastError")
            }
        }
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "PROFILES", count: vm.profiles.count)

            if vm.profiles.isEmpty {
                EmptyHint("No saved profiles.", remoteID: "sidebar.profiles.empty")
            } else {
                ForEach(vm.profiles, id: \.self) { name in
                    SidebarProfileRow(
                        name: name,
                        onApply: { onSelect("sidebar.profiles.row.\(name)") },
                        onDelete: { vm.removeProfile(named: name) }
                    )
                }
            }

            // Per design briefing: a "Save current as…" CTA at the bottom
            // of the section, not a `+` in the header.
            Button { onSelect("sidebar.profiles.add") } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                    Text("Save current as…")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sidebar.profiles.add")
            .padding(.top, 2)
        }
    }
}

/// Single profile row — subtle hover highlight (no idle border per
/// the design briefing's "Saved arrangements" treatment), inline
/// delete button that fades to ~30% opacity until pointer hover.
private struct SidebarProfileRow: View {
    let name: String
    let onApply: () -> Void
    let onDelete: () -> Void
    @State private var hovering: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onApply) {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(hovering ? Color.secondary.opacity(0.10) : .clear)
                }
                // CLAUDE.md responsiveness pillar — snap, don't fade.
                .animation(.easeOut(duration: 0.05), value: hovering)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sidebar.profiles.row.\(name)")
            // .buttonStyle(.plain) drops default AX press routing —
            // explicit accessibilityAction restores it so AXPress
            // actually invokes the action closure.
            .accessibilityAction { onApply() }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4).padding(.vertical, 3)
                    .opacity(hovering ? 0.85 : 0.30)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sidebar.profiles.row.\(name).delete")
            .accessibilityAction { onDelete() }
        }
        .onHover { hovering = $0 }
    }
}

private struct EmptyHint: View {
    let text: String
    let remoteID: String
    init(_ text: String, remoteID: String) { self.text = text; self.remoteID = remoteID }
    var body: some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .accessibilityIdentifier(remoteID)
    }
}
