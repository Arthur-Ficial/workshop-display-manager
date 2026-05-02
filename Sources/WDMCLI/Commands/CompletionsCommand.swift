public enum CompletionsCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let shell = pos.first else {
            throw CLIError.usage("usage: wdm completions <bash|zsh|fish>")
        }
        switch shell {
        case "bash": deps.stdout.write(CompletionsFormatter.bash())
        case "zsh":  deps.stdout.write(CompletionsFormatter.zsh())
        case "fish": deps.stdout.write(CompletionsFormatter.fish())
        default:
            throw CLIError.usage("unknown shell '\(shell)' — supported: bash, zsh, fish")
        }
        return ExitCodes.success
    }
}
