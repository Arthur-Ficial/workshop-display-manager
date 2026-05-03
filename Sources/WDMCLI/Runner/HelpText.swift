public enum HelpText {
    public static let body = """
    wdm — workshop display manager

    USAGE
      wdm <command> [args]

    COMMANDS
      list [--json]                       enumerate displays
      get <id|main> [field] [--json]      read one field of one display
      edid <id|main> [--raw|--json]       parsed EDID + stable per-display identity
      modes <id|main> [--json]            list available modes
      mode <id> <WxH@Hz> [--no-confirm]   set display mode (safe-tx)
      scale <id> <WxH> | looks-like <WxH> | list   logical-resolution shortcut over `mode`
      main <id> [--no-confirm]            set primary display (safe-tx)
      switch [--no-confirm]               swap main between two displays
      cycle  [--no-confirm]               rotate main forward through all displays
      mirror <src> <dst> [--no-confirm]   mirror src→dst
      unmirror <id> [--no-confirm]        break mirror
      move <id> <x> <y> [--no-confirm]    set arrangement origin
      rotate <id> <0|90|180|270>          physical rotation
      flip <id> <none|h|v|hv|off> [--no-confirm]  framebuffer flip (IOKit)
      flip-overlay <id> <axis> [--duration-ms N]  software overlay flip (any Mac)
      pip <src> [--on <dst>] [--size WxH] [--flip <axis>] [--remote] [--duration-ms N]
                                          movable picture-in-picture mirror;
                                          --remote forwards mouse+keys to source (AX)
      brightness <id> [0.0..1.0]          read or set brightness (built-in)
      save <name>                         snapshot to ~/.config/wdm/profiles/<name>.json
      restore <name> [--no-confirm]       apply named profile
      profiles [--json]                   list saved profiles
      profiles remove <name>              delete a saved profile
      watch [--json] [--max-events N]     stream display reconfiguration events
      workshop start --audience <id>      switch main to audience, save pre-state
      workshop stop                       restore the pre-workshop arrangement
      daemon [install] [--max-events N]   run / install the auto-restore daemon
      doctor probe [<id>] [--json]        diagnose what wdm sees per display
      doctor disconnect <id> [--duration-ms N]  soft-disconnect (CGDisplayCapture; release on SIGTERM)
      virtual create --name <s> [--mode WxH@Hz] [--hidpi] [--mirror-on <id>] [--duration-ms N]
                                          create a virtual display; --mirror-on auto-spawns a PIP
      virtual list                        list connected displays (incl. virtual)
      virtual remove <id|name|--all>      SIGTERM the owning create process(es)
      virtual save <name> [--at-login]    snapshot running virtuals; --at-login installs a LaunchAgent
      virtual restore <name> [--dry-run]  re-spawn each saved spec
      scene <name> [--dry-run]            multi-display scene orchestrator (JSON)
      move-window <pattern> --to <id|main>  AX-place frontmost window onto display
      focus <id|main>                     warp cursor + raise topmost window on display
      stream <id|main> --hls <dir>|--rtmp <url> --duration <sec>
                                          live broadcast via ffmpeg
      screenshot <id|main> --out <path>   capture display framebuffer to PNG
      shot-all --dir <path>               capture every active display to <dir>/display-<id>.png
      record <id|main> --out <path> --duration <sec>  record display to .mov (H.264)
      sleep                               sleep the Mac (drains AppleHPM — issue #1)
      hotkeys list|set|delete|reset       configure global keyboard shortcuts
      hotkeys daemon|install|uninstall|status   run / install the listener daemon
      ddc brightness|contrast|volume <id> [0..1]   external monitor control via DDC/CI
      ddc input <id> <hdmi1|dp|usbc|...>  switch external monitor input source
      ddc get|set <id> 0xNN [value]       raw VCP read / write
      hdr <id> [on|off]                   read / toggle HDR (HDR-capable displays only)
      rename <id> <name> [--system]       set a friendly name (alias by default;
                                          --system writes an EDID override plist)
      rename <id> --remove                drop the alias for a display
      completions <bash|zsh|fish>         shell completion script
      manpage                             groff source for wdm(1)
      version                             print version
      help                                show this text

    CONFIRMATION FLAGS (apply to all mutating commands)
      (default)        terminal prompt on stderr (`y` within 15s to keep)
      --confirm        native Mac popup with countdown (SPACE to keep, any other
                       key to cancel, auto-revert at 0)
      --no-confirm     skip confirmation entirely

    ENVIRONMENT
      WDM_TEST_FIXTURE              hermetic test backend; path to JSON fixture.
      WDM_PROFILES_DIR              override default ~/.config/wdm/profiles
      WDM_NATIVE_CONFIRMER_STUB     "yes"|"no" — replaces popup with stub (tests).
      WDM_AUTO_CONFIRM=1            replaces stdin prompt with auto-yes.
      WDM_REAL_HARDWARE=1           opt-in for real-hardware smoke tests.
      WDM_TEST_EVENTS_FILE          file-backed event stream for `watch` tests.
      WDM_TEST_OVERLAY_LOG          recording flipper for `flip-overlay` tests.
      WDM_TEST_PIP_LOG              recording flipper for `pip` tests.
      WDM_TEST_SLEEP_LOG            recording sleeper for `sleep` tests.
      WDM_FIXTURE_FAIL_ROTATE=1     simulate hot-unplug mid-mutation (tests).

    """
}
