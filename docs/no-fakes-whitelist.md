# No-fakes whitelist

`scripts/lint-no-fakes.sh` rejects production code that references test-only env vars or stub markers. Files listed here are reviewed boundary points where test-fixture wiring is intentional and bounded.

## Provider factories — designed boundary

Each of these reads `WDM_TEST_FIXTURE` to decide whether to inject the fixture provider for a hermetic test, OR the real CoreGraphics/IOKit provider for production. This IS the test-injection boundary; no fakes leak past it.

Sources/WDMWeb/WDMWebControllerFactory.swift            # web frontend factory
Sources/WDMKit/DDC/DDCProviderFactory.swift             # DDC provider factory
Sources/WDMKit/HDR/HDRProviderFactory.swift             # HDR provider factory

## Documentation — describing the env var

Sources/WDMCLI/Runner/HelpText.swift                    # CLI --help text describes the env var
Sources/WDMKit/Format/ManpageFormatter.swift            # man page describes the env var
