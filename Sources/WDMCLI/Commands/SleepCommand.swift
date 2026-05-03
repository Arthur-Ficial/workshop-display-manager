public enum SleepCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        deps.stderr.writeLine(
            "wdm: requesting system sleep (drains AppleHPM queue before unplug — see issue #1)"
        )
        try deps.controller.sleep(using: deps.sleeper)
        return ExitCodes.success
    }
}
