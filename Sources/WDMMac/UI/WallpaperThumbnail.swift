import SwiftUI

/// Small chassis-shaped tile that previews a display's actual desktop
/// wallpaper. Powers the sidebar row's per-display preview so workshop
/// facilitators can identify each monitor at a glance from the live
/// background image.
///
/// Honest fallback per CLAUDE.md: if `url` is nil or unloadable, paints
/// the chassis fill colour instead of inventing a placeholder image.
public struct WallpaperThumbnail: View {
    public let url: URL?
    public let kind: ChassisKind
    public let isMain: Bool
    public let pixelSize: CGSize

    public init(url: URL?, kind: ChassisKind, isMain: Bool,
                pixelSize: CGSize = CGSize(width: 36, height: 22)) {
        self.url = url
        self.kind = kind
        self.isMain = isMain
        self.pixelSize = pixelSize
    }

    public var body: some View {
        let shape = ChassisShape(kind: kind)
        return ZStack {
            shape.fill(Color.black.opacity(0.45))
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.clear
                    }
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            shape.stroke(
                isMain ? Color.green.opacity(0.55) : Color.white.opacity(0.18),
                lineWidth: isMain ? 1.0 : 0.6
            )
        }
        .frame(width: pixelSize.width, height: pixelSize.height)
        .accessibilityHidden(true)
    }
}
