SWIFT ?= swift
PREFIX ?= /usr/local

.PHONY: build test release smoke smoke-mac-remote e2e-fullflow lint-glass lint-glass-env lint-remote-coverage lint-no-gui-logic lint-gui-parity lint-github-tickets lint-every-verb-has-e2e lint-file-size lint-function-size lint-cyclomatic-complexity lint-naming lint-public-surface lint-crash-regression lint-rendering-pixel-dims lint-no-fakes lint-icon-completeness generate-icon golden-goal app-mac app-mac-release install clean demo-arrange-pipe

build:
	$(SWIFT) build

release:
	$(SWIFT) build -c release -Xswiftc -warnings-as-errors

test:
	$(SWIFT) test

# Hermetic demo of CLAUDE.md's "every GUI interaction reproducible from
# a pipe" litmus test, applied to drag-to-rearrange:
#   wdm arrange list --json | jq '...' | wdm arrange set @-
# Proves the SSOT property — the GUI's drag-end commit and this CLI
# pipe call exactly the same WDMController op.
demo-arrange-pipe: build
	@bash scripts/demo-arrange-pipe.sh

# Reads/clicks the headless GUI through the remote API. The same flow the
# AI uses. Hermetic — builds, spawns wdm-mac, drives it via wdm-mac-control,
# tears down. Output is what an AI would see.
smoke-mac-remote: build
	@bash scripts/smoke-mac-remote.sh

# Visible end-to-end: spawns wdm-mac headed, drives every clickable
# remoteID + opens Settings + flips appearance + closes both windows
# entirely through /ui/* — no osascript anywhere. Watch your screen.
e2e-fullflow: app-mac
	@pkill -9 -f wdm-mac 2>/dev/null || true
	@sleep 1
	@rm -rf "$$HOME/.cache/wdm-headed-tests"
	@WDM_MAC_APP=$$(pwd)/.build/debug/WDMMac.app \
	  WDM_HEADED_E2E=1 WDM_HEADED_FULL=1 \
	  $(SWIFT) test --filter HeadedFullFlowTest 2>&1 \
	  | grep -E "\\[|✓|✘|recorded|passed|failed|saved" || true

# Forbids non-Liquid-Glass chrome in Sources/WDMMac/. Catches Material.thinMaterial,
# .ultraThickMaterial, solid Color backgrounds on chrome, and files under Views/
# that don't reference at least one Liquid Glass primitive.
lint-glass:
	@bash scripts/lint-liquid-glass.sh

# Verifies the toolchain has every requirement to render Liquid Glass:
# macOS 26+, Xcode 26+, Swift 6+, macOS 26 SDK, NSGlassEffectView header,
# SwiftUI Glass struct, NSBezelStyleGlass.
lint-glass-env:
	@bash scripts/lint-liquid-glass-env.sh

# Forbids GUI elements that aren't reachable from an automated e2e test.
# Every Button/Picker/Toggle in WDMMac must declare .accessibilityIdentifier;
# every accessibilityIdentifier must be referenced from a test or smoke;
# every window the app opens must have a close-button test
# (wdm_close_window).
lint-remote-coverage:
	@bash scripts/lint-remote-coverage.sh

# Forbids `extension <LibType>` in Sources/WDMMac and Sources/WDMMacRemote.
# Enforces "no business logic in GUI": adding methods/properties to a lib
# type from the GUI is a textbook DRY break — the next frontend would have
# to reimplement the same logic. Lib types live in WDMCore/WDMSystem/WDMKit;
# extensions belong there too. Catches the class of bug that motivated
# pulling Flip.toggling / Flip.hasAxis out of DisplaysListVM into WDMCore.
lint-no-gui-logic:
	@bash scripts/lint-no-gui-logic.sh

# Forbids CLI verbs without a GUI surface (or vice versa). Allowlist of
# intentional CLI-only verbs lives in docs/cli-only-verbs.md. Catches
# the "I added a CLI command but forgot the button" class of regression.
lint-gui-parity:
	@bash scripts/lint-gui-parity.sh

# Asserts every milestone in tasks/golden-goal-spec.md has a GitHub
# issue (open or closed). Soft-fails when offline / unauthenticated;
# set WDM_LINT_TICKETS_STRICT=1 to enforce.
lint-github-tickets:
	@bash scripts/lint-github-tickets.sh

# Forbids CLI commands without an e2e test. CLAUDE.md iron law: a
# feature without an e2e test does not exist. Discovers commands from
# Sources/WDMCLI/Commands/*Command.swift and asserts each verb appears
# as a string literal in Tests/WDMCLITests/**/*.swift.
lint-every-verb-has-e2e:
	@bash scripts/lint-every-verb-has-e2e.sh

# Forbids any Sources/**/*.swift > 150 lines (CLAUDE.md "SUPER MODULAR").
# Existing offenders carry a temporary entry in docs/file-size-whitelist.md
# while refactor-backlog issues track each one.
lint-file-size:
	@bash scripts/lint-file-size.sh

# Forbids any Swift function/init/deinit > 30 lines (CLAUDE.md
# "SUPER MODULAR"). Existing offenders carry a temporary entry in
# docs/function-size-whitelist.md while refactor-backlog issues
# track each one.
lint-function-size:
	@bash scripts/lint-function-size.sh

# Forbids any function with cyclomatic complexity > 7 (CLAUDE.md
# "SUPER MODULAR"). Counts if/case/while/for/&&/||/?:/catch/guard
# branches. Existing offenders carry temporary entries in
# docs/cyclomatic-whitelist.md.
lint-cyclomatic-complexity:
	@bash scripts/lint-cyclomatic-complexity.sh

# Forbids "and" segments in function names (= two responsibilities) and
# grab-bag filenames (Utilities/Helpers/Extensions/Misc/Common.swift).
lint-naming:
	@bash scripts/lint-naming.sh

# Soft warning for public symbols without a cross-module consumer
# (CLAUDE.md "default to internal"). Strict mode: WDM_LINT_PUBLIC_SURFACE_STRICT=1.
lint-public-surface:
	@bash scripts/lint-public-surface.sh

# Forbids known crash-generating patterns: Task { try? await stop() },
# signal(SIG_IGN) in libs, unscoped activation-policy switches.
# See CLAUDE.md NO CRASHES + commit 61d307e.
lint-crash-regression:
	@bash scripts/lint-crash-regression.sh

# Capture / render code MUST set contentsScale = backingScaleFactor;
# scalesToFit = true is forbidden. CLAUDE.md CRISP-AS-DAY RENDERING.
lint-rendering-pixel-dims:
	@bash scripts/lint-rendering-pixel-dims.sh

# Production code must not reference WDM_TEST_FIXTURE or stub markers
# outside the documented factory boundary (docs/no-fakes-whitelist.md).
lint-no-fakes:
	@bash scripts/lint-no-fakes.sh

# Asserts every Apple icon slot in the appiconset is present at the
# right dimensions. Run after scripts/generate-icon.sh to verify.
lint-icon-completeness:
	@bash scripts/lint-icon-completeness.sh

# Renders the wdm placeholder icon and slices it into every Apple
# icon slot. Run once; commit the resulting PNGs.
generate-icon:
	@bash scripts/generate-icon.sh

# Acceptance ledger for the ship-ready goal. 10 lines of evidence:
# release build, swift test, headed e2e, every lint, codesign,
# notarization, CLI/Web/GUI parity, every-verb e2e, every-GUI-element
# e2e, soak. Lines that depend on yet-unwritten lints / artefacts
# print DEFERRED with the milestone that unblocks them. The DEFERRED
# count must monotonically decrease milestone-over-milestone.
golden-goal:
	@bash scripts/golden-goal.sh

# Wraps the wdm-mac executable in a real .app bundle with an Info.plist
# that opts into Liquid Glass (LSMinimumSystemVersion=26.0, no
# UIDesignRequiresCompatibility). SwiftPM bare executables don't get
# Liquid Glass — they need to be a proper bundled app.
app-mac: build
	@bash scripts/bundle-wdm-mac.sh debug
	@$(MAKE) -s install-mac BUNDLE=.build/debug/WDMMac.app

# Same, but the release config (used for `make install-mac` later).
app-mac-release: release
	@bash scripts/bundle-wdm-mac.sh release
	@$(MAKE) -s install-mac BUNDLE=.build/release/WDMMac.app

# Atomically replace /Applications/WDMMac.app with the freshly-built
# bundle so there is exactly ONE installed version at any time. Runs
# automatically after `make app-mac` / `make app-mac-release` so every
# build of the app is the live install. Falls back to a temp directory
# move so the kill-and-replace is atomic from Finder's POV.
install-mac:
	@if [ -z "$$BUNDLE" ]; then echo "install-mac: BUNDLE=<path> required"; exit 2; fi
	@if [ ! -d "$$BUNDLE" ]; then echo "install-mac: $$BUNDLE missing"; exit 2; fi
	@pkill -9 -f "/Applications/WDMMac.app/Contents/MacOS/wdm-mac" 2>/dev/null || true
	@rm -rf /Applications/WDMMac.app /Applications/__MACOSX 2>/dev/null || true
	@cp -R "$$BUNDLE" /Applications/
	@echo "install-mac: ✓ /Applications/WDMMac.app replaced from $$BUNDLE"

smoke: release
	WDM_REAL_HARDWARE=1 .build/release/wdm list

install: release
	install -m 0755 .build/release/wdm $(PREFIX)/bin/wdm

clean:
	$(SWIFT) package clean
	rm -rf .build
