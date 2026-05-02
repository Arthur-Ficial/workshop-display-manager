import Foundation

/// One entry in a multi-display scene: a virtual-display spec, plus optional
/// wallpaper path and optional `--mirror-on <id>` for auto-PIP.
public struct SceneEntry: Sendable, Codable, Equatable, Hashable {
    public let spec: VirtualDisplaySpec
    public let wallpaper: String?
    public let mirrorOn: UInt32?

    public init(spec: VirtualDisplaySpec, wallpaper: String? = nil, mirrorOn: UInt32? = nil) {
        self.spec = spec
        self.wallpaper = wallpaper
        self.mirrorOn = mirrorOn
    }
}
