# Workflows

Concrete walkthroughs for the three most common multi-display situations.

---

## 1. One-projector workshop

You arrive at a venue. There's an HDMI cable. You want to:

1. Save your current desk setup so you can restore it on the way home.
2. Plug in the projector.
3. Have your Keynote / browser / IDE on the projector.
4. Verify resolution looks right.
5. After the talk, restore your desk.

```sh
# Before leaving home (one time):
wdm save desk
# ✓ saved profile 'desk'

# At the venue, after plugging in the projector:
wdm list
# ID  NAME                     MODE          ORIGIN  ROT  MAIN  MIRROR
# 1   Built-in Retina Display  1470x956@60   0,0     0    *     -
# 2   ACME Projector 1080      1920x1080@60  1470,0  0          -

# Make the projector main with a confirmation HUD:
wdm switch --confirm
# (HUD appears: "Switched main to ACME Projector 1080. Press SPACE to keep…")
# Press SPACE.

# Verify the resolution is right; if not:
wdm modes 2
wdm mode 2 1920x1080@60 --confirm

# Save the workshop config:
wdm save acme-room

# Run the workshop.

# After:
wdm restore desk
```

If anything goes wrong mid-talk (you accidentally `Cmd-Q`'d wdm in front of your audience), `wdm restore last` brings back the pre-mutation state.

---

## 2. Hot-desking dock setup with auto-restore

You hot-desk between three shared desks. Each has a different external monitor at a slightly different position. You want plugging in the dock to "just work."

```sh
# At desk A (one-time setup, after arranging the displays the way you like):
wdm save desk-A

# At desk B:
wdm save desk-B

# At desk C:
wdm save desk-C
```

Now the named profiles are saved. You restore them by hand:

```sh
wdm restore desk-A
```

Or, scripted, by listening to display-add events (Phase 2 feature):

```sh
wdm watch --json | jq -r 'select(.kind=="added")' | xargs -n1 wdm restore desk-A --no-confirm
```

The Phase 2 daemon (`wdm daemon install`) makes this fully automatic: when the EDID set of connected displays matches a previously-saved profile, the daemon restores it without you running anything.

---

## 3. Dual-projector + iPad sidecar

Conference talk with two projectors and an iPad showing your speaker notes.

```sh
wdm list
# ID  NAME             MODE           ORIGIN     ROT  MAIN  MIRROR
# 1   Built-in         1470x956@60    0,0        0    *     -
# 2   Main Projector   1920x1080@60   1470,0     0          -
# 3   Stage Right Proj 1920x1080@60   3390,0     0          -
# 4   iPad Sidecar     2160x1620@60   -2160,0    0          -

# 1. Mirror your built-in to both projectors so the audience sees what you see:
wdm mirror 1 2 --no-confirm
wdm mirror 1 3 --no-confirm

# 2. iPad shows speaker notes (NOT mirrored — extended desktop):
#    (already extended by default — nothing to do)

# 3. Save the config:
wdm save talk-twin-proj

# Run the talk.

# After:
wdm unmirror 2 --no-confirm
wdm unmirror 3 --no-confirm
wdm restore desk
```

---

## Tips

### Use `--confirm` for irreversible-looking changes

Resolution changes and main-swaps look like the screen "broke" for a second. `--confirm` shows the macOS HUD with a 15-second auto-revert, so you always have a safety net. Bind it to a hotkey for one-touch confirmation.

### Use `--no-confirm` in scripts

Scripts can't press SPACE. Always pass `--no-confirm` from a script. The pre-mutation snapshot is *still* persisted to `last`, so manual recovery remains possible.

### Use `wdm get <id> <field>` for shell composition

```sh
if [ "$(wdm get main name)" = "ACME Projector 1080" ]; then
    osascript -e 'set Volume 4'   # raise volume on workshop projector
fi
```

### Watch events to trigger automation

```sh
wdm watch --json | while read event; do
    case "$(echo "$event" | jq -r .kind)" in
        added)   say "display added" ;;
        removed) say "display removed" ;;
    esac
done
```

(`wdm watch` ships in v0.3.0.)
