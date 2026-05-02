# wdm — Workshop Display Manager

A native macOS CLI for reading, editing, switching, mirroring, rotating, saving, and restoring every aspect of every attached display. Built TDD red→green, every feature 100% e2e tested, pure UNIX style, super-modular Swift.

```
wdm list
wdm switch                    # swap main between two displays in <1s
wdm cycle                     # rotate main forward through all displays
wdm mode 2 1920x1080@60       # set resolution+refresh (auto-revert in 15s if no confirm)
wdm save workshop-room-A
wdm restore workshop-room-A
```

See `CLAUDE.md` for the contributor contract (TDD iron law, modularity rules, UNIX style, exit codes, safety model).

## Build

```
make build      # debug
make release    # warnings-as-errors release
make test       # hermetic e2e suite
make install    # /usr/local/bin/wdm
```

Private. Closed source. Not licensed for external use.
