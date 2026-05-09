# Known Test Flakes

There are no active disabled-test flakes in the current CLI/lib/web package.

If a test is disabled in `Tests/`, its `.disabled("...")` reason must link to a
heading in this file:

```swift
@Test(.disabled("short reason (see docs/known-flakes.md#example-anchor)"))
```

`Tests/WDMCLITests/DisabledTestsHaveLinkTest.swift` enforces both the link and
the anchor existence.
