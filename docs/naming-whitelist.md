# Naming whitelist

`scripts/lint-naming.sh` rejects function names with an "and" segment (per CLAUDE.md SUPER MODULAR — "and" = two responsibilities in one function). Whitelist exempts existing names while refactoring is queued.

## Format

`<path>:<func-name>` per line.

## Backlog

Sources/WDMWeb/WDMWebServer.swift:sendAndClose                            # same pattern as RemoteControlServer
Sources/WDMCLI/Commands/DaemonCommand.swift:watchAndRestore               # daemon main-loop convenience — split when DaemonCommand refactored
Sources/WDMKit/Operations/WDMControllerDaemon.swift:watchAndRestore        # same pattern
