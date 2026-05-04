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
            ForEach(vm.tiles) { SidebarDisplayRow(tile: $0, onSelect: onSelect) }
        }
    }

    private var virtualSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "VIRTUAL", count: 0) {
                Button {} label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sidebar.virtual.add")
            }
            EmptyHint("No virtual displays.\nUse + to create one.",
                      remoteID: "sidebar.virtual.empty")
        }
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "PROFILES", count: 0)
            EmptyHint("No saved profiles.", remoteID: "sidebar.profiles.empty")
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
