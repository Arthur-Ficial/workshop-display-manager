SWIFT ?= swift
PREFIX ?= /usr/local

.PHONY: build test smoke install clean fmt release

build:
	$(SWIFT) build

release:
	$(SWIFT) build -c release -Xswiftc -warnings-as-errors

test:
	$(SWIFT) test

smoke: release
	WDM_REAL_HARDWARE=1 .build/release/wdm list

install: release
	install -m 0755 .build/release/wdm $(PREFIX)/bin/wdm

clean:
	$(SWIFT) package clean
	rm -rf .build
