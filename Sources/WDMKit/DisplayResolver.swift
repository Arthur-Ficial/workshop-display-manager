import WDMCore

/// Resolve the user-facing display alias ("main", "1", "2", …) into a CGDirectDisplayID.
public enum DisplayResolver {
    public static func resolve(_ alias: String, in snapshot: Snapshot) throws -> UInt32 {
        if alias == "main" {
            guard let m = snapshot.main else { throw CLIError.displayNotFound(0) }
            return m.id
        }
        guard let id = UInt32(alias) else {
            throw CLIError.usage("not a display id: '\(alias)'")
        }
        guard snapshot.display(id: id) != nil else {
            throw CLIError.displayNotFound(id)
        }
        return id
    }
}
