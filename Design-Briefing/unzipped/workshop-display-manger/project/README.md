# wdm — Workshop Display Manager

A high-fidelity, interactive design prototype of a macOS app for managing
multi-display setups: real monitors, virtual headless displays, AirPlay /
Sidecar targets, mirror chains, picture-in-picture mirrors, screen
recordings, and saved arrangements.

The prototype is a single-page React app rendered through Babel-in-the-
browser. There is no build step. Open `wdm.html` and the app is live.

---

## What the user can do

The app is one window: titlebar, left sidebar, central canvas, right
inspector, bottom status bar.

**Canvas (center).** A spatial editor. Each display is a tile positioned in
a shared coordinate space. Drag tiles to rearrange. Snap lines appear when
edges align. The tile shows the display's name, current mode, and an
identification badge (`01`, `02`, …) that maps to the alias used in the
CLI preview.

**Sidebar (left).** Two sections — and only two:

- **Connected** — a flat list of every surface present in the system:
  built-in screens, externals, AirPlay receivers, Sidecar iPads, virtual
  headless displays, and PiP windows. Each row shows an icon, the
  display's name, optional hints (`Virtual`, `PiP`, `mirror of 0X`), an
  issue indicator if the system flagged a problem, and a recording dot
  while a recording is active. Bottom of the section: one CTA — **+ Add
  virtual display**.
- **Saved arrangements** — named profiles (Workshop AM, Photo edit,
  Streaming, …). Click a row to apply. The currently-applied profile is
  highlighted. A **Save current as…** button at the bottom captures the
  current canvas state as a new profile.

**Inspector (right).** Context for the selected display. Eyebrow tag
(BUILT-IN / EXTERNAL DISPLAY / VIRTUAL DISPLAY / PIP WINDOW / AIRPLAY /
SIDECAR), name, status tags (`Main`, `Mirror of 0X`, `REC 00:14`,
`Headless`, `HDR`).

Sections, in order:

1. **Mode** — resolution × refresh dropdown with `@2x`/`@1x` HiDPI scale.
   Unsupported modes are listed but disabled with a tooltip explaining
   why. Changing mode goes through the Safe-tx flow (see below).
2. **Geometry** — rotation (0/90/180/270°) and flip (none / H / V).
   Hidden for PiP windows.
3. **Mirror** — *contextual action, not a list.*
   - If this display is mirroring another: "Mirroring **X**" + a Stop
     link.
   - If this display is the source for one or more mirrors: "Source for
     N displays" + a Stop all link.
   - Otherwise: **Mirror this display to…** expands an inline target
     picker. The source is implied (the selected display); the user just
     picks targets and applies. Defaults to "every other eligible
     display" so the most common case is one click.
4. **Actions** — Make main, Open PiP window, Record / Stop recording,
   Reset / reconnect…, Open Advanced.
5. **Identity** — vendor / model / serial / Core Graphics ID / alias.

**Status bar (bottom).** Ambient state, single source of truth for
"what's happening right now": daemon version, current profile name,
counts (`real · virt · pip`), active recording badge, last event
(timestamp + detail). Two toggles on the right — **Watch** (live event
log overlay) and **Advanced** (drawer with raw daemon output).

**Titlebar.** Traffic lights, app name, surface count, two icon buttons
(quick action / theme toggle).

---

## Interaction patterns

### Safe transactions

Every mutation that could leave the user looking at a black screen
(mode change, rotation, mirror, reset) routes through a **Safe-tx**
overlay. The system applies the change, shows a 10-second countdown
banner with **Keep** and **Revert** buttons, and auto-reverts if the
user doesn't confirm. This mirrors the "15-second confirm" convention
in macOS Display preferences.

### Mirror as an action, not an overview

Mirror state is shown ambiently in the sidebar (the `mirror of 0X` hint
on a row, the chain icon on the canvas tile) but **the mirror controls
live in the Inspector**, scoped to the selected display. There is no
separate "Mirror" section in the sidebar — the user enters the mirror
flow by selecting the source display and clicking "Mirror this display
to…".

### CLI preview

Every action emits an equivalent shell command in the Advanced drawer:

```
$ wdm mirror 1 2 3 --confirm
$ wdm rotate 4 90
$ wdm profile apply photo-edit
```

This is one of the prototype's design bets — surface the daemon's API as
a learning aid so power users can graduate to scripting.

### Recordings

Click **Record** in the Inspector to start recording the selected
display. A red dot appears on the sidebar row, a `REC` tag on the
inspector, and a `REC × N` badge in the status bar. The display tile
gains a thin red strip overlay. Recording the display the app itself
runs on is blocked (recursive capture).

### Issues

When the daemon reports a problem (unsupported mode requested, EDID
mismatch, AirPlay link weak), the affected display row gets a small
amber dot in the sidebar with a tooltip. The full message is in the
Advanced drawer.

---

## File layout

```
wdm.html              entry point — loads scripts in order
styles.css            all CSS — design tokens + component styles
tweaks-panel.jsx      starter Tweaks panel (host protocol + controls)
data.jsx              fixtures: display sets, modes, profiles, virtuals
stage.jsx             canvas + DisplayTile (drag, snap, render)
chrome.jsx            cross-cutting UI: Icon, SafeTx, AdvancedDrawer,
                      Toast, ResetSheet, VirtualSheet
mac-shell.jsx         macOS chrome: Titlebar, Sidebar, Inspector,
                      MirrorTargets, StatusBar
app.jsx               root <App>, state, action handlers, routing
```

Scripts share scope by attaching exports to `window` at the bottom of
each file (Babel transpiles each `<script type="text/babel">` into its
own IIFE):

```js
Object.assign(window, { Titlebar, Sidebar, Inspector, StatusBar });
```

`app.jsx` consumes those globals declared at the top:

```js
/* global React, ReactDOM, Icon, DISPLAYS_2, …, Titlebar, Sidebar,
   Inspector, StatusBar, SafeTx, AdvancedDrawer, … */
```

### Older versions

`wdm v1.html` and `wdm v2.html` are kept as historical references — the
v1 was a single big monolith with segment tabs (Stage / Profiles /
Recordings / 60s Story); v2 split into modules but still had the
duplicated Mirror section in the sidebar. The current `wdm.html` is the
DRY pass: one source of truth per concept.

---

## Design system

### Type

System font stack (`-apple-system, BlinkMacSystemFont, "SF Pro Text",
…`). Sizes are tight on purpose — this is dense pro tooling, not a
landing page.

| Token            | Size  | Use                                  |
|------------------|-------|--------------------------------------|
| eyebrow          | 10.5px / 700 / 0.06em tracking | Section caps |
| body-sm          | 12px  | Sidebar rows, inspector body        |
| body             | 13px  | Default                             |
| title            | 15px  | Inspector display name              |
| mono             | 11.5px `ui-monospace` | CLI, identity, modes |

### Color

Tokens live at the top of `styles.css` and switch on
`html[data-theme="dark"]`. The accent color follows the active profile:
each profile carries its own `--accent`, applied via inline style on
`<html>`.

| Token         | Light                | Dark                  |
|---------------|----------------------|-----------------------|
| `--bg-0`      | window background    | window background     |
| `--bg-1`      | sidebar / inspector  | sidebar / inspector   |
| `--bg-2`      | hover, code blocks   | hover, code blocks    |
| `--fg-0..4`   | text scale           | text scale            |
| `--hair-1/2`  | dividers, borders    | dividers, borders     |
| `--accent`    | profile-driven       | profile-driven        |
| `--err`       | red                  | red                   |
| `--warn`      | amber                | amber                 |
| `--ok`        | green                | green                 |

All translucent overlays use `oklch(from var(--accent) l c h / α)` so
the alpha mixes work in any theme/profile combo.

### Components

- `mac-titlebar` — fixed-height (38px) with traffic lights left,
  centered title, action buttons right.
- `sb-section` / `sb-row` — sidebar list; `sb-row` supports icon,
  label, hint, kbd hint, issue dot, recording dot, trash button, main
  tag.
- `mac-inspector` — vertical stack of `ins-section` blocks; each has
  `ins-label` (eyebrow) + content.
- `mode-select` — disclosure dropdown; current mode visible in the
  trigger; menu lists all modes with check / unsupported state.
- `MirrorTargets` — inline picker rendered inside the Inspector's
  Mirror section. Source is implied; targets default to "all other
  eligible displays".
- `SafeTx` — overlay banner; auto-reverts on countdown end.
- `AdvancedDrawer` — bottom drawer with CLI preview, daemon logs, EDID
  blob, and a JSON view of state.
- `Toast` — top-right ephemeral notifications.

### Spacing & radii

8-pt grid where possible; tighter (4 / 6 / 8 / 12) inside dense surfaces
like the sidebar. Radii: `4px` chips, `6px` rows, `8px` panels, `10px`
sheets, `14px` window.

---

## State model

`app.jsx` owns everything. Top-level state shape:

```ts
{
  displays:     Display[],          // real connected screens
  virtuals:     Display[],          // virtual headless
  pips:         Display[],          // PiP windows
  recordings:   Recording[],        // active recordings
  profiles:     Profile[],          // saved arrangements (from data.jsx)
  selected:     id | null,          // currently-inspected surface
  currentProfileId: id | null,
  tx:           SafeTx | null,      // pending confirmation
  toasts:       Toast[],
  events:       Event[],            // for status bar + Watch overlay
  watchOn:      bool,
  advOpen:      bool,
  cli:          { args, flags }     // last-emitted CLI command
}
```

Mutations are funneled through `onMutate({ kind, id, ...payload })`.
Side-effects (toast, event, CLI preview) are emitted in the same pass.

### Mirror semantics

A mirror is represented as `display.mirroredFrom = otherId`. There is
no separate "mirror table". Helpers derive the inverse view (sources →
targets) when needed for the Inspector's mirror state line. Unmirroring
is just `mirroredFrom = null`.

---

## Tweaks

A floating Tweaks panel (toolbar toggle) exposes:

- **Display set** — 2 / 3 / 4 surface scenarios.
- **Theme** — Light / Dark.
- **Density** — Comfortable / Compact.
- **Profile palette** — Workshop / Photo / Stream.
- **Show snap lines** — debug toggle.

Defaults are wrapped in the `EDITMODE-BEGIN` / `EDITMODE-END` markers
in `app.jsx` so the host can persist edits.

---

## Conventions and non-negotiables

- **One concept, one place.** Mirror state shows in the sidebar as a
  hint; mirror *controls* are in the Inspector. Profiles are listed in
  the sidebar; there is no profile sheet, no profile tab. Recordings
  are surfaced where they're relevant (sidebar dot, inspector tag,
  status badge); there is no Recordings tab.
- **No empty placeholders.** If a section has nothing to show, it
  collapses or the action is hidden. We don't reserve space for things
  that aren't there.
- **The canvas is the app.** No view-mode tabs swap it out.
- **Every mutation has a CLI form.** If you can't write the command,
  the action shouldn't exist.
- **macOS conventions where they exist.** Traffic lights top-left,
  inspector right, status bar bottom. ⌘K opens the quick-action
  palette. Safe-tx mirrors the system's display-confirm dialog.

---

## Running locally

Open `wdm.html` directly in a browser. No server, no build. Babel
in-browser transpiles JSX on load.

For sharper print / screenshot output, the canvas auto-scales to the
viewport but stays pixel-snapped at 1× when the window matches the
designed width.
