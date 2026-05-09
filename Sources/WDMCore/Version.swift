import Foundation

/// Single source of truth for the wdm version string.
///
/// All other places that reference the version (`wdm version` CLI output,
/// the man page, release artefact names) MUST read from here. The
/// `Tests/WDMCoreTests/VersionSingleSourceTests.swift` test enforces this
/// with a hermetic grep.
///
/// Version bumps go through `scripts/release.sh <version>` which
/// rewrites this file's `current` constant and builds the release binary.
/// Per CLAUDE.md "no third-party runtime deps" — the constant is plain Swift;
/// SwiftPM build plugins for git-tag derivation are deferred to a later
/// milestone.
public enum Version: Sendable {
    /// Marketing version (semver). Updated by `scripts/release.sh`.
    public static let current: String = "2.0.0"
}
