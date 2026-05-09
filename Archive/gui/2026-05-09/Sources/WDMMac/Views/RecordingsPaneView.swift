import SwiftUI

/// Recordings tab content. Lists recently-saved screen recordings
/// produced by the Inspector Record action. Each row reveals the file
/// in Finder. Honest fallback per CLAUDE.md: empty state when no
/// recording has been made this session.
public struct RecordingsPaneView: View {
    @ObservedObject var vm: DisplaysListVM

    public init(vm: DisplaysListVM) { self.vm = vm }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recordings").font(.system(size: 16, weight: .semibold))
            if let path = vm.lastRecordingPath {
                recordingRow(path: path)
            } else {
                Text("No recordings yet. Select a display in the Stage tab and click Record in the Inspector.")
                    .foregroundStyle(.secondary).padding(.top, 24)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("recordings.pane")
    }

    private func recordingRow(path: String) -> some View {
        let fileName = (path as NSString).lastPathComponent
        return HStack(spacing: 10) {
            Image(systemName: "record.circle")
                .foregroundStyle(.red)
            VStack(alignment: .leading) {
                Text(fileName).font(.system(size: 13, weight: .medium))
                Text(path).font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button("Reveal") {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [URL(fileURLWithPath: path)]
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .clickable()
            .accessibilityIdentifier("recordings.pane.row.reveal")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background { RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04)) }
    }
}
