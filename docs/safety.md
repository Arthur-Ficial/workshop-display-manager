# Safety model

Every mutating command in `wdm` is wrapped in three independent revert layers. They compose: each layer catches failures the layer above did not, so that **no combination of user mistake, process death, or CoreGraphics misbehaviour leaves the user staring at a black projector**.

## The three layers

### 1. `SafeTransaction` — in-process snapshot + revert on cancel

Implemented in `Sources/WDMCLI/Safety/SafeTransaction.swift`.

```
┌──────────────────────────────────────────────┐
│  let before = try provider.snapshot()        │
│  let result = try apply()                    │  ← call the mutation
│  guard result == .applied else { return }    │
│  if confirmer.confirm(message: ..., t: 15) { │
│      return .applied                         │  ← user said yes
│  }                                           │
│  try ProfileApplier.apply(target: before)    │  ← revert
│  return .reverted                            │
└──────────────────────────────────────────────┘
```

The confirmer is plug-and-play:

- **Default**: `StdinConfirmer` writes a prompt to stderr and reads stdin with a 15-second timeout (using `poll`).
- **`--confirm`**: `NativePopupConfirmer` shows a translucent macOS HUD overlay with a draining progress bar and a live ticking countdown; SPACE keeps, any other key cancels.
- **`--no-confirm`**: `AutoYesConfirmer` returns `true` without prompting. Use in scripts.

`ProfileApplier` is pure: it computes the diff between two `Snapshot`s and dispatches the minimum set of mutations to bring the live state back to `before`. This is why revert is safe to call from any failure path — it doesn't blindly re-run commands, it diffs.

### 2. `last` profile — crash-recovery snapshot

Implemented in `Sources/WDMCLI/Commands/MutationDispatch.swift`.

```
┌──────────────────────────────────────────────┐
│  let preState = try provider.snapshot()      │
│  try? deps.profileStore.save(name: "last",   │
│                              snapshot: preState)│  ← persist BEFORE apply
│  let result = try SafeTransaction.run(...)   │
└──────────────────────────────────────────────┘
```

Every mutation persists the pre-state to `~/.config/wdm/profiles/last.json` before it tries anything. If the process is killed mid-mutation (kernel panic, SIGKILL, `pkill wdm`), the user can recover with:

```sh
wdm restore last
```

This is layered *under* `SafeTransaction`: the in-memory snapshot handles the common case of "user changed their mind", while `last` handles the catastrophic case of "the process is gone, I have to do this from a fresh shell".

### 3. `CGRestorePermanentDisplayConfiguration` — last-resort CG-level revert

Implemented in `Sources/WDMSystem/CGDisplayProvider.swift`.

```
┌──────────────────────────────────────────────┐
│  CGBeginDisplayConfiguration(&config)        │
│  ... configure ...                           │
│  let err = CGCompleteDisplayConfiguration(   │
│              config, .permanently)           │
│  if err != .success {                        │
│      CGRestorePermanentDisplayConfiguration()│  ← system-level revert
│      throw configurationFailed(...)          │
│  }                                           │
└──────────────────────────────────────────────┘
```

If CoreGraphics itself fails during the commit (rare — usually means the kernel rejected the configuration), we fire `CGRestorePermanentDisplayConfiguration()` which restores whatever the system considers "permanent" before the failed commit. The error then propagates up, where `SafeTransaction` will *also* revert via `ProfileApplier`, but by that point the system has already recovered the live state.

## Sequence diagram: a `--confirm` swap that the user lets timeout

```
User       wdm                     SafeTransaction      Provider     Confirmer
  │         │                            │                 │            │
  │  switch │                            │                 │            │
  │ ────────►                            │                 │            │
  │         │ snapshot pre-state to      │                 │            │
  │         │ profile 'last'             │                 │            │
  │         │ ──────────────────────────►│                 │            │
  │         │                            │ snapshot()      │            │
  │         │                            │ ──────────────► │            │
  │         │                            │ ◄──────────────┐│            │
  │         │                            │ apply (setMain) │            │
  │         │                            │ ──────────────► │            │
  │         │                            │ ◄──────────────┐│            │
  │         │                            │ confirm("Switched main…") │  │
  │         │                            │ ────────────────────────► │  │
  │         │                            │                 │  (15s)  │  │
  │         │                            │ ◄─ false (timeout)───── │  │
  │         │                            │ ProfileApplier.apply(   │  │
  │         │                            │   target: pre-state)    │  │
  │         │                            │ ──────────────► │       │  │
  │         │ ◄ exit 5 "change reverted" │                 │       │  │
```

## What we don't try to protect against

- **The user runs `wdm` as root and rewrites their display config to something the kernel can't drive.** That's a kernel-level recovery (logout / reboot), not us.
- **The user's `~/.config/wdm` directory is on a unmounted drive.** `wdm restore last` will fail; the in-memory `SafeTransaction` still works for the current session.
- **Hot-pluggable display goes away mid-mutation.** `CGCompleteDisplayConfiguration` will return `.illegalArgument`, layer 3 fires, transaction aborts, layer 1 reverts via diff.

This three-layer model is the core of why `wdm` is safe to use in a workshop. You can confidently run `wdm switch --confirm` from a stage and know that, no matter what happens, your screen will come back.
