# ``WDMCore``

Pure value types and parsers that describe a macOS display configuration.

## Overview

`WDMCore` is the bottom of the `wdm` dependency stack. It contains nothing but
plain value types, parsers, formatters, and JSON codecs. No `import AppKit`,
no `import CoreGraphics`. This is what makes the unit tests for parsing,
formatting, and round-trip JSON cheap to run and trivially deterministic.

## Topics

### Value types

- ``Mode``
- ``Point``
- ``DisplayInfo``
- ``Snapshot``
