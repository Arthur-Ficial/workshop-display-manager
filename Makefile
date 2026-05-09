SWIFT ?= swift
PREFIX ?= /usr/local
CLI_TEST_SUITES := WDMCoreTests WDMSystemTests WDMKitTests WDMCLITests WDMWebTests

.PHONY: build build-all release release-all test test-all lint perf-cli smoke install clean demo-arrange-pipe golden-goal lint-gui-archived lint-cli-boundary lint-every-verb-has-e2e lint-file-size lint-function-size lint-cyclomatic-complexity lint-naming lint-public-surface lint-crash-regression lint-rendering-pixel-dims lint-no-fakes lint-github-tickets

build:
	$(SWIFT) build --product wdm

build-all:
	$(SWIFT) build

release:
	$(SWIFT) build --product wdm -c release -Xswiftc -warnings-as-errors

release-all:
	$(SWIFT) build -c release -Xswiftc -warnings-as-errors

test: build lint
	@for suite in $(CLI_TEST_SUITES); do \
	  echo "==> swift test --no-parallel --filter $$suite"; \
	  WDM_CLI_BINARY="$$(pwd)/.build/debug/wdm" $(SWIFT) test --no-parallel --filter "$$suite" || exit $$?; \
	done

test-all:
	$(SWIFT) test --no-parallel

lint: lint-gui-archived lint-cli-boundary lint-every-verb-has-e2e lint-no-fakes lint-file-size lint-function-size lint-cyclomatic-complexity lint-naming lint-public-surface lint-crash-regression lint-rendering-pixel-dims

perf-cli: release
	@bash scripts/perf-cli.sh

demo-arrange-pipe: build
	@bash scripts/demo-arrange-pipe.sh

lint-gui-archived:
	@bash scripts/lint-gui-archived.sh

lint-cli-boundary:
	@bash scripts/lint-cli-boundary.sh

lint-every-verb-has-e2e:
	@bash scripts/lint-every-verb-has-e2e.sh

lint-file-size:
	@bash scripts/lint-file-size.sh

lint-function-size:
	@bash scripts/lint-function-size.sh

lint-cyclomatic-complexity:
	@bash scripts/lint-cyclomatic-complexity.sh

lint-naming:
	@bash scripts/lint-naming.sh

lint-public-surface:
	@bash scripts/lint-public-surface.sh

lint-crash-regression:
	@bash scripts/lint-crash-regression.sh

lint-rendering-pixel-dims:
	@bash scripts/lint-rendering-pixel-dims.sh

lint-no-fakes:
	@bash scripts/lint-no-fakes.sh

lint-github-tickets:
	@bash scripts/lint-github-tickets.sh

golden-goal:
	@bash scripts/golden-goal.sh

smoke: release
	WDM_REAL_HARDWARE=1 .build/release/wdm list

install: release
	install -m 0755 .build/release/wdm $(PREFIX)/bin/wdm

clean:
	$(SWIFT) package clean
	rm -rf .build
