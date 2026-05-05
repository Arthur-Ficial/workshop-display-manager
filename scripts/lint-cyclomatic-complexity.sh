#!/bin/bash
# lint-cyclomatic-complexity.sh
#
# Enforces CLAUDE.md "SUPER MODULAR": every function's cyclomatic
# complexity (branch count) MUST be ≤ 7. Counts: if, else if, switch
# case, while, for, &&, ||, ?:, catch — every decision point that
# adds a path through the function body.
#
# Implementation: same brace-balanced Python scanner as
# lint-function-size.sh; counts decision-keyword occurrences per
# function body (excluding strings, comments, nested string literals).
#
# Whitelist: docs/cyclomatic-whitelist.md — same `<path>:<func>` shape.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LIMIT=7
WHITELIST_FILE="docs/cyclomatic-whitelist.md"

if ! command -v python3 >/dev/null 2>&1; then
    echo "lint-cyclomatic-complexity: python3 missing" >&2
    exit 2
fi

python3 - "$LIMIT" "$WHITELIST_FILE" <<'PY'
import os, re, sys, pathlib

limit       = int(sys.argv[1])
whitelist_p = sys.argv[2]

allow = set()
if pathlib.Path(whitelist_p).exists():
    for line in pathlib.Path(whitelist_p).read_text().splitlines():
        line = line.strip()
        if line.startswith("Sources/") and ":" in line:
            allow.add(line.split()[0])

# Decision tokens. Word-boundary anchored.
DECISION = re.compile(r'\b(if|else\s+if|switch|case|while|for|catch|guard)\b|&&|\|\||\?[^?:]*:')

def scan(path):
    text = path.read_text(encoding="utf-8")
    n = len(text); i = 0
    lc = bc = sg = tr = False; bcd = 0
    findings = []
    DECL = re.compile(r'(^|[^A-Za-z0-9_])(func|init|deinit)([\s(])')
    while i < n:
        # cheap state machine
        if i+2 < n and text[i:i+2] == '//':
            while i < n and text[i] != '\n': i += 1; continue
        if i+2 < n and text[i:i+2] == '/*':
            i += 2
            while i < n - 1 and text[i:i+2] != '*/': i += 1
            i += 2; continue
        if i+3 < n and text[i:i+3] == '"""':
            i += 3
            while i < n - 2 and text[i:i+3] != '"""': i += 1
            i += 3; continue
        if text[i] == '"':
            i += 1
            while i < n and text[i] != '"':
                if text[i] == '\\' and i+1 < n: i += 2; continue
                i += 1
            i += 1; continue
        # Look for decl
        m = DECL.match(text[max(i-1,0):])
        if m and (i == 0 or not text[i-1].isalnum() and text[i-1] != "_"):
            kind = m.group(2)
            # Get the function name (next ident).
            jstart = i + len(kind)
            j = jstart
            while j < n and not text[j].isalnum() and text[j] != '_': j += 1
            name = ''
            while j < n and (text[j].isalnum() or text[j] == '_'):
                name += text[j]; j += 1
            if not name: name = kind
            # Find opening brace
            paren = 0
            while j < n:
                c = text[j]
                if c == '(': paren += 1
                elif c == ')': paren -= 1
                elif c == '{' and paren == 0: break
                elif c == ';' and paren == 0: j = -1; break
                j += 1
            if j < 0 or j >= n: i += 1; continue
            start = j
            depth = 0
            k = j
            while k < n:
                c = text[k]
                if k+1 < n and text[k:k+2] == '//':
                    while k < n and text[k] != '\n': k += 1; continue
                if k+1 < n and text[k:k+2] == '/*':
                    k += 2
                    while k < n - 1 and text[k:k+2] != '*/': k += 1
                    k += 2; continue
                if k+2 < n and text[k:k+3] == '"""':
                    k += 3
                    while k < n - 2 and text[k:k+3] != '"""': k += 1
                    k += 3; continue
                if c == '"':
                    k += 1
                    while k < n and text[k] != '"':
                        if text[k] == '\\' and k+1 < n: k += 2; continue
                        k += 1
                    k += 1; continue
                if c == '{': depth += 1
                elif c == '}':
                    depth -= 1
                    if depth == 0: break
                k += 1
            body = text[start:k]
            count = 1 + len(DECISION.findall(body))
            if count > limit:
                findings.append((str(path), name, count))
            i = k + 1
            continue
        i += 1
    return findings

violations = []
for f in sorted(pathlib.Path(".").glob("Sources/**/*.swift")):
    rel = str(f)
    for fname, name, c in scan(f):
        key = f"{rel}:{name}"
        if key in allow: continue
        violations.append((rel, name, c))

if violations:
    print("lint-cyclomatic-complexity: functions exceeding complexity %d:" % limit, file=sys.stderr)
    for rel, name, c in violations:
        print(f"  - {rel}:{name} (complexity {c})", file=sys.stderr)
    print(file=sys.stderr)
    print("Per CLAUDE.md \"SUPER MODULAR\": cyclomatic complexity > 7 hides bugs.", file=sys.stderr)
    print("Extract a helper or invert the condition.", file=sys.stderr)
    sys.exit(1)

print(f"lint-cyclomatic-complexity: ✓ all functions ≤ complexity {limit}")
PY
