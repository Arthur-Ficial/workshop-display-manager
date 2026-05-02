# Contributing

`wdm` is private but the contribution process is the same as for an open project — except the iron law (`CLAUDE.md`) is non-negotiable.

## The iron law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
EVERY FEATURE HAS AN AUTOMATED END-TO-END TEST.
```

If you wrote production code without a failing test first: **delete it, re-read `CLAUDE.md`, start the cycle.** Do not "adapt" the deleted code while writing the test — implement fresh from the test.

## How to add a feature

1. **Decide the user-facing surface.** What command do they type? What does it print? What's the exit code?
2. **Write the failing e2e test first.** Spawn `CLIRunner.run` against a fixture with the expected args. Assert on stdout, stderr, exit code, and (for mutations) the post-state of the fixture.
3. **Run it. Watch it fail. With the right error.** If the test passes immediately or fails for an unexpected reason, the test is wrong.
4. **Write the minimum code to make it pass.** No extra options, no speculative abstraction, no logging.
5. **Run the full suite.** Other tests must still pass.
6. **Refactor on green only.**
7. **Update the man page and README** if the user surface changed.
8. **One feature, one commit.** Single-purpose commit message.

## Modular constraints

These shape every change:

- **One public type per file.** File name = type name.
- **Files ≤ 150 lines. Functions ≤ 30 lines.** Over the limit → split.
- **Default to `internal`.** `public` is a promise.
- **No singletons or `static var shared`** (one exception: `KeyBoxStash` for the C event-tap callback).
- **No "and" in names.** `parseAndValidate` → `parse` and `validate`.
- **Effects at the edges.** I/O, CG, the filesystem live in `WDMSystem`. Logic in `WDMCore` is effect-free.

## Running tests

```sh
make test                                 # hermetic e2e suite
swift test --filter SomeSpecificSuite     # one suite
WDM_REAL_HARDWARE=1 swift test            # opt-in hardware smoke
```

## Build before commit

```sh
make release    # warnings-as-errors must be clean
make test       # zero failures
```

A pre-commit hook is provided at `scripts/pre-commit.sh`:

```sh
git config core.hooksPath scripts
```

It runs `swift format lint`, `make release`, and `make test` before every commit.

## Code style

- Two-space indent.
- One public type per file.
- Comments only when the WHY is non-obvious. Don't explain WHAT — well-named identifiers do that.
- No emoji in source unless the user explicitly asks.
- Default to `internal`; `public` is a deliberate promise.

## Commit messages

```
short summary in imperative form (lowercase, ≤72 chars)

optional body explaining the WHY, wrapped at 80 cols. Don't restate
WHAT the diff does — that's already in the diff.

If this commit completes a numbered task in /Users/.../plans/<plan>.md,
note the task number.
```

No `Co-Authored-By` lines unless the user explicitly asks.

## Adding a new subcommand

1. `Tests/WDMCLITests/<Name>CommandE2ETests.swift` — failing first.
2. `Sources/WDMCLI/Commands/<Name>Command.swift` — `public enum <Name>Command { static func run(args:deps:) -> Int32 }`.
3. Add a case to the switch in `Sources/WDMCLI/Runner/CLIRunner.swift`.
4. Add the verb to `CompletionsFormatter.commands` so all shells pick it up.
5. Update `Sources/WDMCLI/Runner/HelpText.swift`.
6. Update `Sources/WDMCLI/Format/ManpageFormatter.swift`.
7. Update `README.md`'s command table.
8. Run all tests. Commit.

## Adding a new mutating verb

Same as above, but the command's `run` body uses `MutationDispatch.dispatch`:

```swift
return try MutationDispatch.dispatch(
    deps: deps, args: args,
    description: "Did the thing to \(label)"
) {
    try deps.provider.doTheThing(...)
}
```

The `description` is what the user sees in the confirm HUD / stderr prompt. Make it specific and use the resolved display name when applicable.
