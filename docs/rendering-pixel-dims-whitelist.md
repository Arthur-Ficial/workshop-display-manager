# Rendering pixel-dims whitelist

`scripts/lint-rendering-pixel-dims.sh` rejects SCStreamConfiguration users that don't reference `backingScaleFactor`. Listed files are temporarily exempt while refactoring to crisp-rendering compliance is queued.

## Format

`<path>` per line.

## Backlog

Sources/WDMSystem/NativeStreamer.swift   # H.264 video recording — rewrites cfg.width/height from CGDisplayBounds; backingScaleFactor refactor is in M5/M6 backlog
