#!/bin/bash
# lint-gui-parity.sh
#
# Enforces CLAUDE.md "Unix-CLI parity (non-negotiable)": every CLI verb
# either has a GUI surface OR is on the documented `docs/cli-only-verbs.md`
# allowlist. A verb in neither is a SSOT violation — the CLI works but
# the GUI is silently incomplete.
#
# Discovery:
#   - CLI verbs come from Sources/WDMCLI/Commands/*Command.swift filenames
#     (CamelCase → kebab-case, drop "Command" suffix).
#   - Allowlist comes from the canonical-form table in docs/cli-only-verbs.md
#     (lines matching `| <verb> | ... |`).
#   - GUI surfaces come from Sources/WDMMac/** and Sources/WDMMacRemote/**:
#     a verb is "covered" iff its kebab-case token OR the controller method
#     it calls appears as text in any GUI source file.
#
# Exit code: 0 if every non-allowlisted verb is covered, 1 otherwise.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# CamelCase -> kebab-case. "FlipOverlay" -> "flip-overlay", "DDC" -> "ddc",
# "EDID" -> "edid", "MoveWindow" -> "move-window".
camel_to_kebab() {
    sed -E 's/([A-Z]+)([A-Z][a-z])/\1-\2/g; s/([a-z0-9])([A-Z])/\1-\2/g' \
        | tr '[:upper:]' '[:lower:]'
}

# kebab-case -> camelCase. "flip-overlay" -> "flipOverlay", "move-window"
# -> "moveWindow". macOS sed doesn't support \U; use a portable awk.
kebab_to_camel() {
    awk '{
        n = split($0, parts, "-")
        out = parts[1]
        for (i = 2; i <= n; i++) {
            out = out toupper(substr(parts[i],1,1)) substr(parts[i],2)
        }
        print out
    }'
}

# Allowlisted verbs from the canonical-form markdown table. Row format:
# `| <verb> | <controller-method-or-marker> | <justification> |`
# Skip the header (verb literally equals "verb") and the divider row.
ALLOWLIST=$(awk -F'|' 'NF >= 4 {
    v = $2
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
    if (v == "" || v == "verb" || v ~ /^-+$/) next
    # Sanity: verbs are lowercase kebab-case with optional space (for sub-verbs).
    if (v !~ /^[a-z][a-z0-9 -]*$/) next
    print v
}' docs/cli-only-verbs.md)

# Discover CLI verbs.
VERBS=$(for f in Sources/WDMCLI/Commands/*Command.swift; do
    [ -e "$f" ] || continue
    base=$(basename "$f" Command.swift)
    [ -z "$base" ] && continue
    [ "$base" = "Args" ] && continue
    [ "$base" = "Mutation" ] && continue   # MutationDispatch.swift is shared infra
    [ "$base" = "MutationDispatch" ] && continue
    echo "$base" | camel_to_kebab
done | sort -u)

# Resolve which controller method(s) a given CLI command file calls.
# Returns a space-separated list of method names. Empty if none found.
controller_methods_for() {
    local cmdfile="$1"
    grep -hoE 'controller\.[a-zA-Z]+|deps\.controller\.[a-zA-Z]+' "$cmdfile" 2>/dev/null \
        | sed -E 's/^.*controller\.//' \
        | sort -u \
        | tr '\n' ' '
}

violations=0
while IFS= read -r verb; do
    [ -z "$verb" ] && continue
    # Skip if allowlisted.
    if echo "$ALLOWLIST" | grep -qFx "$verb"; then
        continue
    fi
    camel=$(echo "$verb" | kebab_to_camel)
    # Find the original Command file to extract its controller method(s).
    # CLI verb "flip-overlay" -> "FlipOverlayCommand.swift".
    cmd_camel=$(echo "$verb" | awk '{
        n = split($0, p, "-"); out = ""
        for (i = 1; i <= n; i++) out = out toupper(substr(p[i],1,1)) substr(p[i],2)
        print out
    }')
    cmdfile="Sources/WDMCLI/Commands/${cmd_camel}Command.swift"
    cmethods=""
    [ -e "$cmdfile" ] && cmethods=$(controller_methods_for "$cmdfile")

    # Coverage signal — at least ONE of:
    # (a) kebab verb token used as a remoteID segment (e.g., "inspector.flip"),
    # (b) camelCase verb invoked as a method/property (e.g., ".flipOverlay("),
    # (c) any controller method called by the CLI command also called in GUI.
    covered=0
    if grep -rqE "[.\"]${verb}([.\" ]|$)" Sources/WDMMac Sources/WDMMacRemote --include='*.swift' 2>/dev/null; then
        covered=1
    elif grep -rqE "\\.${camel}\\b" Sources/WDMMac Sources/WDMMacRemote --include='*.swift' 2>/dev/null; then
        covered=1
    elif [ -n "$cmethods" ]; then
        for m in $cmethods; do
            if grep -rqE "\\.${m}\\b" Sources/WDMMac Sources/WDMMacRemote --include='*.swift' 2>/dev/null; then
                covered=1
                break
            fi
        done
    fi

    if [ $covered -eq 1 ]; then
        continue
    fi

    if [ $violations -eq 0 ]; then
        echo "lint-gui-parity: CLI verbs without GUI surface (and not on allowlist):" >&2
    fi
    echo "  - $verb (camel: $camel; controller methods: ${cmethods:-none-detected})" >&2
    violations=$((violations + 1))
done <<< "$VERBS"

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Either expose the verb in the GUI (Sources/WDMMac or Sources/WDMMacRemote)" >&2
    echo "or add it to the canonical-form table in docs/cli-only-verbs.md with a justification." >&2
    exit 1
fi

echo "lint-gui-parity: ✓ every CLI verb has a GUI surface or is on the documented allowlist"
