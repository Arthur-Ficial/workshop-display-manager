#!/bin/bash
# lint-gui-archived.sh
#
# The active product is the Unix CLI/lib. The old Mac GUI code is preserved
# under Archive/ and must not be part of SwiftPM products, targets, or tests.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARCHIVE="Archive/gui/2026-05-09"
violations=0

fail() {
    if [ $violations -eq 0 ]; then
        echo "lint-gui-archived: active GUI artefacts found:" >&2
    fi
    echo "  - $1" >&2
    violations=$((violations + 1))
}

for path in \
    Sources/WDMMac \
    Sources/WDMMacRemote \
    Sources/WDMRemoteControl \
    Sources/wdm-mac \
    Sources/wdm-mac-control \
    Tests/WDMMacE2ETests \
    Tests/WDMMacRemoteTests \
    Tests/WDMRemoteControlTests
do
    [ -e "$path" ] && fail "$path must live under $ARCHIVE"
done

if grep -nE '"(WDMMac|WDMMacRemote|WDMRemoteControl|wdm-mac|wdm-mac-control)"' Package.swift >/tmp/wdm-gui-package-hits.$$ 2>/dev/null; then
    while IFS= read -r hit; do fail "Package.swift:$hit"; done </tmp/wdm-gui-package-hits.$$
fi
rm -f /tmp/wdm-gui-package-hits.$$

if [ ! -f "$ARCHIVE/README.md" ]; then
    fail "$ARCHIVE/README.md missing"
fi

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Move retired GUI code into $ARCHIVE and keep SwiftPM focused on wdm/WDMCore/WDMSystem/WDMKit/WDMCLI/WDMWeb." >&2
    exit 1
fi

echo "lint-gui-archived: ✓ GUI code is archived outside the active package"
