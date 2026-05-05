# Distribution

`wdm` ships as a Developer ID-signed, notarized macOS binary set for direct download. **Not on the Mac App Store** — see `docs/adr/0001-developer-id-not-mas.md` for the architectural reasons.

## Components

| Binary | Purpose |
|---|---|
| `wdm` | CLI — every workshop display operation, scriptable, one binary |
| `WDMMac.app` | Native macOS GUI on top of the same lib (signed Developer ID, hardened runtime, notarized) |
| `wdm-mac-control` | Companion CLI to drive WDMMac.app's remote API (`agent-browser`-style) |
| `wdm-web` | Proof-of-concept HTTP frontend (not a shipped product) |

## Install — GUI

```sh
# Download
curl -LO https://github.com/Arthur-Ficial/workshop-display-manager/releases/download/v0.2.0/WDMMac-0.2.0.zip
unzip WDMMac-0.2.0.zip -d /Applications/
open /Applications/WDMMac.app
```

The first launch will prompt for **Screen Recording** permission (needed for Flip H/V's overlay). Grant it once — notarized bundles persist the grant across rebuilds.

## Install — CLI

```sh
git clone git@github.com:Arthur-Ficial/workshop-display-manager.git
cd workshop-display-manager
make install          # copies .build/release/wdm to /usr/local/bin/
wdm version
```

(A signed standalone `wdm` binary in the GitHub release archive is on the v1.0.0 backlog.)

## Permissions

`wdm` and `WDMMac.app` need:

- **Screen Recording** — for Flip H/V's overlay, PiP, screenshot, record (anything that uses ScreenCaptureKit).
- **Accessibility** — only when using `wdm focus` / `wdm follow` / `wdm move-window` (window-management utilities). The display-manipulation core (mode/main/mirror/move/rotate/profiles) needs nothing.

System Settings → Privacy & Security → Screen Recording (or Accessibility) → toggle wdm-mac.

## Updating

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Arthur-Ficial/workshop-display-manager/main/scripts/wdm-update.sh)
```

The script downloads the latest GitHub release zip, replaces `/Applications/WDMMac.app`, and re-launches. Plain shell — no auto-updater dependency yet (see `docs/adr/0002-auto-update-deferred.md`).

## Verifying authenticity

After download:

```sh
spctl -a -t exec -vv /Applications/WDMMac.app
# Expected:
#   /Applications/WDMMac.app: accepted
#   source=Notarized Developer ID
#   origin=Developer ID Application: Franz Enzenhofer (7D2YX5DQ6M)
xcrun stapler validate /Applications/WDMMac.app
# Expected: "The validate action worked!"
```

## Uninstall

```sh
rm -rf /Applications/WDMMac.app
sudo rm -f /usr/local/bin/wdm
```

Settings + saved profiles live under `~/.config/wdm/` — remove if you want a clean slate:

```sh
rm -rf ~/.config/wdm/
```
