/// Tiny helper for command argument parsing.
/// A token is a "flag" iff it begins with "--". Negative numbers are positional.
public enum Args {
    public static func positional(_ args: [String]) -> [String] {
        args.filter { !$0.hasPrefix("--") }
    }

    public static func has(_ args: [String], flag: String) -> Bool {
        args.contains(flag)
    }
}
