# Distribution

`wdm` currently ships as a source-built macOS CLI. The active release artefact is
the `wdm` executable. The archived Mac GUI distribution notes live under
`Archive/gui/2026-05-09/docs/adr/`.

## Components

| Binary | Purpose |
|---|---|
| `wdm` | Primary Unix CLI for display operations. |
| `wdm-web` | Local proof-of-concept HTTP frontend, not a shipped product. |

## Install From Source

```sh
git clone git@github.com:Arthur-Ficial/workshop-display-manager.git
cd workshop-display-manager
make release
make install
wdm version
```

Default install path is `/usr/local/bin/wdm`. Override with:

```sh
PREFIX="$HOME/.local" make install
```

## Permissions

Most display configuration operations use CoreGraphics/IOKit and need no extra
permission prompt.

Some commands require macOS privacy permissions:

- **Screen Recording**: `flip-overlay`, `pip`, `screenshot`, `shot-all`,
  `record`, `stream`.
- **Accessibility**: `focus`, `follow`, `move-window`, `tile-app`, and remote
  PiP input forwarding.

## Verify A Local Build

```sh
make test
make perf-cli
make smoke        # opt-in real display read smoke
```

`make test` is fixture-backed and hermetic. `make smoke` sets
`WDM_REAL_HARDWARE=1` and reads real display state.

## Uninstall

```sh
sudo rm -f /usr/local/bin/wdm
rm -rf ~/.config/wdm
```
