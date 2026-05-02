import Foundation

/// Generates the groff/troff source for the wdm(1) man page.
/// One source of truth for the help text (also rendered by `wdm help`) so the
/// man page can never drift from what the binary actually does.
public enum ManpageFormatter {
    public static func render() -> String {
        let date = currentDate()
        return """
        .TH WDM 1 "\(date)" "wdm" "User Commands"
        .SH NAME
        wdm \\- workshop display manager
        .SH SYNOPSIS
        .B wdm
        .RI [ command ]
        .RI [ args... ]
        .SH DESCRIPTION
        .B wdm
        is a native macOS CLI for reading, editing, switching, mirroring, rotating,
        saving, and restoring every attached display. Every mutating command is
        wrapped in an atomic safe-transaction with auto-revert on cancel or
        timeout, so a misconfigured projector can never lock a workshop out of
        their screen.
        .SH COMMANDS
        .TP
        .B list [\\-\\-json]
        Enumerate displays.
        .TP
        .B get <id|main> [field] [\\-\\-json]
        Read one field of one display (id, name, mode, origin, rotation, main, online, mirror).
        .TP
        .B modes <id|main> [\\-\\-json]
        List available resolutions and refresh rates.
        .TP
        .B mode <id> <WxH@Hz> [\\-\\-no\\-confirm|\\-\\-confirm]
        Set the display mode. Goes through the safe-transaction confirmer.
        .TP
        .B main <id> [\\-\\-no\\-confirm|\\-\\-confirm]
        Set the primary display.
        .TP
        .B switch [\\-\\-no\\-confirm|\\-\\-confirm]
        Swap the main display between two displays in under a second.
        .TP
        .B cycle [\\-\\-no\\-confirm|\\-\\-confirm]
        Rotate the main forward through all online displays.
        .TP
        .B mirror <src> <dst> [\\-\\-no\\-confirm|\\-\\-confirm]
        Mirror src into dst.
        .TP
        .B unmirror <id> [\\-\\-no\\-confirm|\\-\\-confirm]
        Break a mirror relationship.
        .TP
        .B move <id> <x> <y> [\\-\\-no\\-confirm|\\-\\-confirm]
        Set the global-coordinate origin of a display.
        .TP
        .B rotate <id> <0|90|180|270> [\\-\\-no\\-confirm|\\-\\-confirm]
        Physically rotate a display. Apple Silicon limitations apply (see TROUBLESHOOTING).
        .TP
        .B brightness <id> [0.0..1.0] [\\-\\-no\\-confirm|\\-\\-confirm]
        Read or set the brightness on a 0..1 scale (built\\-in displays).
        .TP
        .B save <name>
        Snapshot the current display configuration to ~/.config/wdm/profiles/<name>.json.
        .TP
        .B restore <name> [\\-\\-no\\-confirm|\\-\\-confirm]
        Apply a saved profile through the safe-transaction confirmer.
        .TP
        .B profiles [\\-\\-json]
        List saved profiles.
        .TP
        .B completions <bash|zsh|fish>
        Emit a shell completion script.
        .TP
        .B manpage
        Emit this man page in groff source form.
        .TP
        .B version
        Print the version.
        .TP
        .B help
        Print the inline help.
        .SH "CONFIRMATION FLAGS"
        Every mutating command goes through a confirmer:
        .TP
        .B (default)
        Terminal prompt on stderr. Press y within 15s to keep, anything else reverts.
        .TP
        .B \\-\\-confirm
        Native macOS HUD overlay with a live countdown. SPACE to keep, any other key cancels, auto-revert at 0.
        .TP
        .B \\-\\-no\\-confirm
        Skip confirmation entirely. Useful in scripts.
        .SH "EXIT CODES"
        .TP
        0
        success
        .TP
        1
        generic failure
        .TP
        2
        usage error
        .TP
        3
        display not found
        .TP
        4
        mode not supported
        .TP
        5
        cancelled / safe-transaction reverted
        .TP
        6
        profile not found
        .TP
        7
        I/O error
        .TP
        8
        CoreGraphics or IOKit error
        .SH ENVIRONMENT
        .TP
        .B WDM_TEST_FIXTURE
        Path to a JSON fixture file. Switches the binary to a hermetic test backend.
        .TP
        .B WDM_PROFILES_DIR
        Override the default ~/.config/wdm/profiles directory.
        .TP
        .B WDM_NATIVE_CONFIRMER_STUB
        "yes" or "no" — replaces the native HUD with an automatic stub for tests.
        .TP
        .B WDM_AUTO_CONFIRM
        Set to "1" to replace the stdin prompt with auto-yes.
        .SH "SAFETY MODEL"
        Every mutating command is wrapped in a three-layer revert system:
        .IP \\(bu 2
        SafeTransaction snapshots the pre-state and re-applies it via ProfileApplier
        if the confirmer says no or times out.
        .IP \\(bu 2
        MutationDispatch persists the pre-state to profile 'last' before applying,
        so the user can recover with `wdm restore last` after a crash.
        .IP \\(bu 2
        CGCompleteDisplayConfiguration uses .permanently scope but
        CGRestorePermanentDisplayConfiguration is invoked if the CG commit itself fails.
        .SH AUTHOR
        Franz Enzenhofer / fullstackoptimization.com
        .SH "SEE ALSO"
        .BR displayplacer (1)

        """
    }

    private static func currentDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }
}
