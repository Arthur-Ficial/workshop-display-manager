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
            SectionHeader(title: "VIRTUAL", count: 0) {
                Button {} label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                }
                .buttonStyle(.plain)
                .clickable(cornerRadius: 5)
                .accessibilityIdentifier("sidebar.virtual.add")
            }
            EmptyHint("No virtual displays.\nUse + to create one.",
                      remoteID: "sidebar.virtual.empty")
        }
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "PROFILES", count: vm.profiles.count)
            if vm.profiles.isEmpty {
                EmptyHint("No saved profiles.", remoteID: "sidebar.profiles.empty")
            } else {
                ForEach(vm.profiles, id: \.self) { name in
                    Button { onSelect("sidebar.profiles.row.\(name)") } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(name)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .clickable(cornerRadius: 5)
                    .accessibilityIdentifier("sidebar.profiles.row.\(name)")
                }
            }
        }
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
