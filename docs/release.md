# Release process

Maintainer-only. The full release pipeline is automated; this doc explains how it's wired so you can debug it.

## TL;DR

```sh
# from a clean main with all tests green:
git tag v0.x.0
git push origin v0.x.0
# wait for the release workflow to complete
gh release view v0.x.0
```

The workflow signs, notarizes, staples, archives, checksums, and creates the GitHub release with auto-generated notes.

## Pipeline stages

`.github/workflows/release.yml` runs on every `v*` tag push:

1. **Checkout** at the tag.
2. **Set up Swift** (toolchain matching `swift-tools-version` in `Package.swift`).
3. **Tests** — `make test` must pass (hermetic, no real hardware).
4. **Release build** — `make release` (`-warnings-as-errors`).
5. **Code-sign** the binary with the Developer-ID Application identity:
   ```sh
   codesign --force --options runtime --timestamp \
     --sign "Developer ID Application: Franz Enzenhofer (7D2YX5DQ6M)" \
     .build/release/wdm
   ```
6. **Submit for notarization** with `xcrun notarytool`:
   ```sh
   xcrun notarytool submit wdm.zip \
     --apple-id "$APPLE_ID_USERNAME" \
     --password "$APPLE_ID_PASSWORD" \
     --team-id "$APPLE_TEAM_ID" \
     --wait
   ```
7. **Staple** the ticket: `xcrun stapler staple .build/release/wdm`.
8. **Tar + checksum**:
   ```sh
   tar -czf wdm-${VERSION}-arm64-macos.tar.gz -C .build/release wdm
   shasum -a 256 wdm-${VERSION}-arm64-macos.tar.gz > wdm-${VERSION}-arm64-macos.tar.gz.sha256
   ```
9. **Generate release notes** from commits since previous tag.
10. **`gh release create`** uploads tarball + checksum.
11. **Bump Homebrew formula** (separate workflow in `Arthur-Ficial/homebrew-wdm` triggered by repository_dispatch).

## GitHub repo secrets required

| Secret | Description |
|---|---|
| `APPLE_ID_USERNAME` | Your Apple ID (the email you use to sign in to App Store Connect) |
| `APPLE_ID_PASSWORD` | An app-specific password generated at appleid.apple.com |
| `APPLE_TEAM_ID` | `7D2YX5DQ6M` (Franz's team) |
| `APPLE_DEVELOPER_ID_CERT_P12_BASE64` | The P12 export of the Developer-ID Application cert, base64-encoded |
| `APPLE_DEVELOPER_ID_CERT_PASSWORD` | The P12 export password |
| `HOMEBREW_TAP_TOKEN` | A fine-grained PAT with `contents:write` on `Arthur-Ficial/homebrew-wdm` |

The cert and key live at `~/dev/apple-dev-id/` per `~/.claude/CLAUDE.md`. Re-export with:

```sh
security export -k ~/Library/Keychains/login.keychain-db -t identities \
    -f pkcs12 -P "<password>" -o /tmp/devid.p12
base64 -i /tmp/devid.p12 | pbcopy
```

…then paste into the repo secret.

## Verifying a release locally

```sh
# Pretend to be a fresh user:
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
gh release download v0.x.0 -p '*.tar.gz'
gh release download v0.x.0 -p '*.sha256'

# Verify checksum
shasum -a 256 -c *.sha256

# Unpack
tar -xzf wdm-*.tar.gz

# Verify code signature
codesign --verify --strict --verbose=4 ./wdm

# Verify notarization
spctl --assess --type install --verbose ./wdm

# Try it
./wdm version
```

If any step fails, the release is bad. Don't bump Homebrew until everything passes.

## Rolling back

```sh
gh release delete v0.x.0 -y
git tag -d v0.x.0
git push origin :refs/tags/v0.x.0
```

Then fix the bug, bump the version (don't reuse the tag), and re-tag.

## Versioning

Semantic versioning. Pre-1.0:

- **0.x.0** — new features; may include API breakage in CLI surface
- **0.x.y** — patches; no surface changes
- **1.0.0** — first stable release. From there, surface changes need a major bump.
