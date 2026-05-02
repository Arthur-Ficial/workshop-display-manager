# ``WDMCLI``

Command parsing, dispatch, output, profile storage, and the safe-transaction
confirmer system that drives every mutating verb in `wdm`.

## Overview

`WDMCLI` consumes ``WDMSystem/DisplayProvider`` only through its protocol
abstraction. That's why every user-facing command can be exercised end-to-end
in a hermetic test by spawning ``CLIRunner/run(args:env:stdout:stderr:)`` against a
``WDMSystem/FixtureDisplayProvider``. No real hardware required for tests; no
fake test path baked into production for hardware.

## Topics

### Entry point

- ``CLIRunner``
- ``CLIDeps``
- ``CLIError``
- ``ExitCodes``

### Output

- ``OutputWriter``
- ``StreamOutputWriter``
- ``BufferOutputWriter``

### Safety

- ``Confirmer``
- ``SafeTransaction``
- ``StdinConfirmer``
- ``NativePopupConfirmer``
- ``AutoYesConfirmer``
- ``AutoNoConfirmer``

### Profiles

- ``ProfileStore``
- ``ProfileApplier``

### Formatters

- ``JSONFormatter``
- ``SnapshotTableFormatter``
- ``CompletionsFormatter``
- ``ManpageFormatter``
