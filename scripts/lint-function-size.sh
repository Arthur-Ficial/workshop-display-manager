#!/bin/bash
# lint-function-size.sh
#
# Enforces CLAUDE.md "SUPER MODULAR" pillar: every Swift function /
# initializer / closure-as-property body MUST be ≤ 30 lines (declaration
# brace to matching close brace, inclusive).
#
# Implementation: pure-stdlib Python (macOS ships 3.x). No third-party
# AST dep. Brace-depth scan with single-quote / double-quote / triple-
# quote / line-comment / block-comment awareness — sufficient for
# production Swift.
#
# Whitelist: docs/function-size-whitelist.md — `<file>:<func>` per row
# during the refactor-backlog phase.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LIMIT=30
WHITELIST_FILE="docs/function-size-whitelist.md"

if ! command -v python3 >/dev/null 2>&1; then
    echo "lint-function-size: python3 missing — required to parse Swift" >&2
    exit 2
fi

python3 - "$LIMIT" "$WHITELIST_FILE" <<'PY' "$@"
import os, re, sys, pathlib

limit       = int(sys.argv[1])
whitelist_p = sys.argv[2]
root        = pathlib.Path(".")

# Whitelist lines: "<path>:<func-name>" — same shape as a stack frame.
allow = set()
if pathlib.Path(whitelist_p).exists():
    for line in pathlib.Path(whitelist_p).read_text().splitlines():
        line = line.strip()
        if line.startswith("Sources/") and ":" in line:
            allow.add(line.split()[0])

DECL = re.compile(r'(^|\s)(func|init|deinit)\s+([A-Za-z_][A-Za-z0-9_]*)?')

def scan(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    n = len(text)
    i = 0
    in_line_comment = False
    in_block_comment = 0
    in_single = False
    in_triple = False
    line = 1
    findings = []
    while i < n:
        ch = text[i]
        if ch == '\n':
            line += 1
            in_line_comment = False
            i += 1; continue
        if in_line_comment:
            i += 1; continue
        if in_block_comment > 0:
            if text[i:i+2] == "/*": in_block_comment += 1; i += 2; continue
            if text[i:i+2] == "*/": in_block_comment -= 1; i += 2; continue
            i += 1; continue
        if in_triple:
            if text[i:i+3] == '"""': in_triple = False; i += 3; continue
            i += 1; continue
        if in_single:
            if ch == "\\" and i+1 < n: i += 2; continue
            if ch == '"': in_single = False
            i += 1; continue
        # Comments / strings start
        if text[i:i+2] == "//": in_line_comment = True; i += 2; continue
        if text[i:i+2] == "/*": in_block_comment = 1; i += 2; continue
        if text[i:i+3] == '"""': in_triple = True; i += 3; continue
        if ch == '"': in_single = True; i += 1; continue
        # Look for func/init/deinit declarations
        if ch in "fid":
            tail = text[max(i-1,0):i+8]
            m = DECL.match(text[max(i-1,0):])
            if m and (i == 0 or not text[i-1].isalnum() and text[i-1] != "_"):
                kind = m.group(2)
                name = m.group(3) or kind
                # Find the next "{" after balancing parentheses (signature).
                paren = 0
                j = i + len(kind)
                while j < n:
                    cj = text[j]
                    if cj == '\n':
                        # advance line counter only when we leave the signature
                        pass
                    if cj == '(': paren += 1
                    elif cj == ')': paren -= 1
                    elif cj == '{' and paren == 0:
                        break
                    elif cj == ';' and paren == 0:
                        # protocol decl with no body
                        j = -1
                        break
                    j += 1
                if j < 0 or j >= n:
                    i += 1; continue
                # j points at the opening brace
                start_line = text.count('\n', 0, j) + 1
                depth = 0
                k = j
                # Walk to matching close brace, ignoring strings/comments inside.
                lc = False; bc = 0; sg = False; tr = False
                while k < n:
                    c = text[k]
                    if c == '\n':
                        lc = False
                    if lc: k += 1; continue
                    if bc:
                        if text[k:k+2] == '*/': bc -= 1; k += 2; continue
                        if text[k:k+2] == '/*': bc += 1; k += 2; continue
                        k += 1; continue
                    if tr:
                        if text[k:k+3] == '"""': tr = False; k += 3; continue
                        k += 1; continue
                    if sg:
                        if c == '\\' and k+1 < n: k += 2; continue
                        if c == '"': sg = False
                        k += 1; continue
                    if text[k:k+2] == '//': lc = True; k += 2; continue
                    if text[k:k+2] == '/*': bc = 1; k += 2; continue
                    if text[k:k+3] == '"""': tr = True; k += 3; continue
                    if c == '"': sg = True; k += 1; continue
                    if c == '{': depth += 1
                    elif c == '}':
                        depth -= 1
                        if depth == 0:
                            end_line = text.count('\n', 0, k) + 1
                            length = end_line - start_line + 1
                            if length > limit:
                                findings.append((str(path), name, start_line, end_line, length))
                            break
                    k += 1
                i = k + 1
                continue
        i += 1
    return findings

violations = []
for f in sorted(root.glob("Sources/**/*.swift")):
    rel = str(f)
    for fname, name, s, e, ln in scan(f):
        # Whitelist key: path:name
        key = f"{rel}:{name}"
        if key in allow:
            continue
        violations.append((rel, name, s, e, ln))

if violations:
    print("lint-function-size: functions exceeding %d lines:" % limit, file=sys.stderr)
    for rel, name, s, e, ln in violations:
        print(f"  - {rel}:{name} (lines {s}-{e}, {ln} lines)", file=sys.stderr)
    print(file=sys.stderr)
    print("Per CLAUDE.md \"SUPER MODULAR\": functions >30 lines hide bugs.", file=sys.stderr)
    print("Extract helpers. If the function is generated or otherwise must", file=sys.stderr)
    print("exceed the limit, add a `<path>:<func-name>` row to", file=sys.stderr)
    print(f"{whitelist_p} with a one-line justification.", file=sys.stderr)
    sys.exit(1)

print(f"lint-function-size: ✓ all functions ≤ {limit} lines")
PY
