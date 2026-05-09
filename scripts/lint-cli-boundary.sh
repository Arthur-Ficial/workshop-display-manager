#!/bin/bash
# CLI command files parse argv, call WDMKit, and format output. They must not
# reach through CLIDeps to provider/profile stores directly.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

violations=$(rg -n "deps\\.(provider|profileStore)" Sources/WDMCLI/Commands \
    -g '*.swift' \
    -g '!MutationDispatch.swift' || true)

if [ -n "$violations" ]; then
    echo "lint-cli-boundary: command files must not use deps.provider/profileStore directly:" >&2
    echo "$violations" >&2
    exit 1
fi

echo "lint-cli-boundary: ✓ CLI commands route display/profile work through WDMKit"
