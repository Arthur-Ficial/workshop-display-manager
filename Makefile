SWIFT ?= swift
PREFIX ?= /usr/local

.PHONY: build test smoke smoke-mac-remote lint-glass lint-glass-env app-mac app-mac-release install clean fmt release

build:
	$(SWIFT) build

release:
	$(SWIFT) build -c release -Xswiftc -warnings-as-errors

test:
	$(SWIFT) test

# Reads/clicks the headless GUI through the remote API. The same flow the
# AI uses. Hermetic — builds, spawns wdm-mac, drives it via wdm-mac-control,
# tears down. Output is what an AI would see.
smoke-mac-remote: build
	@bash scripts/smoke-mac-remote.sh

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

# Wraps the wdm-mac executable in a real .app bundle with an Info.plist
# that opts into Liquid Glass (LSMinimumSystemVersion=26.0, no
# UIDesignRequiresCompatibility). SwiftPM bare executables don't get
# Liquid Glass — they need to be a proper bundled app.
app-mac: build
	@bash scripts/bundle-wdm-mac.sh debug

# Same, but the release config (used for `make install-mac` later).
app-mac-release: release
	@bash scripts/bundle-wdm-mac.sh release

smoke: release
	WDM_REAL_HARDWARE=1 .build/release/wdm list

install: release
	install -m 0755 .build/release/wdm $(PREFIX)/bin/wdm

clean:
	$(SWIFT) package clean
	rm -rf .build
