import SwiftUI

/// Profiles tab content. Full-pane list of saved arrangements with
/// big "Apply" / "Delete" affordances. Mirrors the sidebar PROFILES
/// section but uses the whole center column so workshop facilitators
/// can manage many profiles at once.
public struct ProfilesPaneView: View {
    @ObservedObject var vm: DisplaysListVM

    public init(vm: DisplaysListVM) { self.vm = vm }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved arrangements").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("+ Save current as…") { vm.saveCurrentAsProfile() }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .clickable()
                    .accessibilityIdentifier("profiles.pane.save")
            }
            if vm.profiles.isEmpty {
                Text("No saved profiles yet. Click \"+ Save current as…\" to create one.")
                    .foregroundStyle(.secondary).padding(.top, 24)
            } else {
                ForEach(vm.profiles, id: \.self) { name in
                    profileRow(name: name)
                }
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("profiles.pane")
    }

    private func profileRow(name: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(.green)
            Text(name).font(.system(size: 14, weight: .medium))
            Spacer()
            Button("Apply") { vm.restoreProfile(named: name) }
                .buttonStyle(.plain)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .clickable()
                .accessibilityIdentifier("profiles.pane.row.\(name).apply")
            Button("Delete") { vm.removeProfile(named: name) }
                .buttonStyle(.plain)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .clickable()
                .accessibilityIdentifier("profiles.pane.row.\(name).delete")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background { RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04)) }
    }
}
