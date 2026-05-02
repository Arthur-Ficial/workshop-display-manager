public enum HelpText {
    public static let body = """
    wdm — workshop display manager

    USAGE
      wdm <command> [args]

    COMMANDS
      list [--json]                       enumerate displays
      get <id|main> [field] [--json]      read one field of one display
      modes <id|main> [--json]            list available modes
      mode <id> <WxH@Hz> [--no-confirm]   set display mode (safe-tx)
      main <id> [--no-confirm]            set primary display (safe-tx)
      switch [--no-confirm]               swap main between two displays
      cycle  [--no-confirm]               rotate main forward through all displays
      mirror <src> <dst> [--no-confirm]   mirror src→dst
      unmirror <id> [--no-confirm]        break mirror
      move <id> <x> <y> [--no-confirm]    set arrangement origin
      rotate <id> <0|90|180|270>          physical rotation
      brightness <id> [0.0..1.0]          read or set brightness (built-in)
      save <name>                         snapshot to ~/.config/wdm/profiles/<name>.json
      restore <name> [--no-confirm]       apply named profile
      profiles [--json]                   list saved profiles
      version                             print version
      help                                show this text

    ENVIRONMENT
      WDM_TEST_FIXTURE   path to a JSON fixture; switches to hermetic test backend.

    """
}
