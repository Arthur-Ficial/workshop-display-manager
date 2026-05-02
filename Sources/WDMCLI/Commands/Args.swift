/// Tiny helper for command argument parsing.
/// A token is a "flag" iff it begins with "--". Negative numbers are positional.
public enum Args {
    public static func positional(_ args: [String]) -> [String] {
        args.filter { !$0.hasPrefix("--") }
    }

    public static func has(_ args: [String], flag: String) -> Bool {
        args.contains(flag)
    }

    public static func flagString(_ args: [String], name: String) -> String? {
        guard let index = args.firstIndex(of: name),
              args.count > index + 1 else { return nil }
        return args[index + 1]
    }

    public static func flagInt(_ args: [String], name: String) -> Int? {
        flagString(args, name: name).flatMap(Int.init)
    }
}
