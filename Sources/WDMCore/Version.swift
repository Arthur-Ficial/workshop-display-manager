import Foundation

/// Single source of truth for the wdm version string.
///
/// All other places that reference the version (Info.plist via
/// scripts/bundle-wdm-mac.sh, Sources/WDMMac/Views/Settings/AboutPane.swift,
/// `wdm version` CLI output, the man page) MUST read from here. The
/// `Tests/WDMCoreTests/VersionSingleSourceTests.swift` test enforces
/// this with a hermetic grep.
///
/// Version bumps go through `scripts/release.sh <version>` which
/// rewrites this file's `current` constant, sets CFBundleVersion to
/// the git short SHA, builds the release binary + signs + notarizes
/// the bundle, and stables the result. Per CLAUDE.md "no third-party
/// runtime deps" — the constant is plain Swift; SwiftPM build plugins
/// for git-tag derivation are deferred to a later milestone.
public enum Version: Sendable {
    /// Marketing version (semver). Updated by `scripts/release.sh`.
    public static let current: String = "0.2.0"
}
