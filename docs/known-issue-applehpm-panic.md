# Known macOS kernel bug: `AppleHPM` panic on projector cable hot-swap

> Tracking issue: [`Arthur-Ficial/workshop-display-manager#1`](https://github.com/Arthur-Ficial/workshop-display-manager/issues/1)
> Companion: [`Arthur-Ficial/cable-detective#2`](https://github.com/Arthur-Ficial/cable-detective/issues/2)

## TL;DR

On macOS 26.3.x (Darwin 25.3.0, build `25D2128`) running on Apple Silicon, **plugging or unplugging the USB-C cable between your Mac and an external display / projector** can hard-panic the kernel inside `com.apple.driver.AppleHPM 3.4.4`. wdm's audience — workshop teachers, conference speakers, hot-deskers — does this dozens of times a day, so wdm users hit this Apple bug far more often than the average Mac user.

This is **not** a bug in wdm. wdm is a pure user-space Swift CLI (CoreGraphics layer, no kernel extension); it cannot cause a kernel panic. The crash fires inside Apple's closed-source `AppleHPM` kext during the USB-C **Power Delivery** + **DisplayPort Alt Mode** handshake.

## Why wdm users see it most

- `wdm workshop start --audience N` → plug projector cable
- `wdm workshop stop` → unplug projector cable
- Repeat 5–20× per workshop

Every plug or unplug is a chance for AppleHPM's PD ↔ DP-AltMode marshalling bug to fire.

## Recovery

The good news: wdm is designed for exactly this kind of mid-session disruption.

```sh
wdm restore last      # reapply the pre-crash arrangement after reboot
wdm restore desk-A    # or apply a named profile
```

`~/.config/wdm/profiles/last.json` is written before every mutation, so a kernel panic mid-workshop loses at most the in-flight change.

## Workaround in workshop flow

In order of effectiveness:

1. **Sleep the Mac before unplugging the projector cable** — `pmset sleepnow`, or close the lid. Drains AppleHPM's event queue and avoids the race. Cheapest fix.
2. **Use a powered USB-C dock; unplug from the dock side, not the laptop** — keeps the Mac's port in a steady PD state.
3. **HDMI** if your projector has it — bypasses USB-C PD/DP-AltMode entirely.

## Confirmed environment

| | |
|---|---|
| Hardware | T8112 (M2 MacBook Air, 24 GB) |
| OS build | 26.3.1 (`25D2128`) |
| Kernel | Darwin 25.3.0 / xnu-12377.91.3~2 |
| Triggering kext | `com.apple.driver.AppleHPM 3.4.4` (UUID `F745548E-3F82-32D4-9C99-1EDFAA86FC34`) |
| Reproducibility | Hit 3× in one day on a single machine |

## Fingerprint

| Field | Value |
|---|---|
| ESR | `0x96000005` (Data Abort, translation fault L1, EL1 read) |
| FAR | `0x38` / `0x3a` / `0x3f` (matches `x1` each panic) |
| Faulting PC offset | kernel `+0x95D870` |
| Direct caller offset | kernel `+0x956E34` |
| AppleHPM call frames | `+0xA700` and `+0x6A78` |
| Constant in `x9`/`x27` | `0x00000000e3ff842b` |

`x1` is being dereferenced as a pointer despite holding a small scalar (PD response code or payload offset). Type-confusion in AppleHPM's PD ↔ DP-AltMode marshalling — fix has to come from Apple. Filed via Feedback Assistant.

## Filed with Apple

Apple Feedback Assistant — see `feedback-assistant-kernel-panic-applehpm.md` in `~/dev/temp/` for the submission text and panic-log paths (`/Library/Logs/DiagnosticReports/panic-full-2026-05-02-{084136,152605,154736}.0002.panic`).
