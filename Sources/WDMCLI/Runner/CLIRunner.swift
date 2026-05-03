import Foundation
import WDMCore
import WDMSystem

public enum CLIRunner {
    public static func run(
        args: [String],
        env: [String: String],
        stdout: OutputWriter,
        stderr: OutputWriter
    ) -> Int32 {
        guard let sub = args.first else {
            stderr.writeLine("usage: wdm <command> [args]   try 'wdm help'")
            return ExitCodes.usage
        }
        if sub == "help" || sub == "--help" || sub == "-h" {
            stdout.write(HelpText.body)
            return ExitCodes.success
        }
        if sub == "version" || sub == "--version" {
            stdout.writeLine("wdm \(WDMCore.version)")
            return ExitCodes.success
        }

        let rest = Array(args.dropFirst())

        let provider: DisplayProvider
        do {
            provider = try DisplayProviderFactory.make(env: env)
        } catch {
            stderr.writeLine("error: \(error)")
            return ExitCodes.generic
        }
        let profileStore = ProfileStore.resolve(env: env)
        let confirmer: Confirmer = env["WDM_AUTO_CONFIRM"] == "1"
            ? AutoYesConfirmer()
            : StdinConfirmer(prompt: "keep change?", stderr: stderr)
        let nativeConfirmer: Confirmer = {
            switch env["WDM_NATIVE_CONFIRMER_STUB"] {
            case "yes": return AutoYesConfirmer()
            case "no":  return AutoNoConfirmer()
            default:    return NativePopupConfirmer()
            }
        }()
        let eventStream = EventStreamFactory.make(env: env)
        let overlayFlipper = OverlayFlipperFactory.make(env: env)
        let pipFlipper = PipFlipperFactory.make(env: env)
        let sleeper = SleeperFactory.make(env: env)
        let displayCapturer = DisplayCapturerFactory.make(env: env)
        let virtualDisplayManager = VirtualDisplayManagerFactory.make(env: env)
        let screenshotter = ScreenshotterFactory.make(env: env)
        let recorder = RecorderFactory.make(env: env)
        let windowMover = WindowMoverFactory.make(env: env)
        let streamer = StreamerFactory.make(env: env)
        let windowLister = WindowListerFactory.make(env: env)
        let cursorTracker = CursorTrackerFactory.make(env: env)
        let deps = CLIDeps(
            provider: provider, profileStore: profileStore,
            confirmer: confirmer,
            nativeConfirmer: nativeConfirmer,
            eventStream: eventStream,
            overlayFlipper: overlayFlipper,
            pipFlipper: pipFlipper,
            sleeper: sleeper,
            displayCapturer: displayCapturer,
            virtualDisplayManager: virtualDisplayManager,
            screenshotter: screenshotter,
            recorder: recorder,
            windowMover: windowMover,
            streamer: streamer,
            windowLister: windowLister,
            cursorTracker: cursorTracker,
            processEnv: env,
            stdout: stdout, stderr: stderr
        )

        do {
            switch sub {
            case "list":     return try ListCommand.run(args: rest, deps: deps)
            case "get":      return try GetCommand.run(args: rest, deps: deps)
            case "modes":    return try ModesCommand.run(args: rest, deps: deps)
            case "save":     return try SaveCommand.run(args: rest, deps: deps)
            case "restore":  return try RestoreCommand.run(args: rest, deps: deps)
            case "profiles": return try ProfilesCommand.run(args: rest, deps: deps)
            case "mode":     return try ModeCommand.run(args: rest, deps: deps)
            case "main":     return try MainCommand.run(args: rest, deps: deps)
            case "mirror":   return try MirrorCommand.run(args: rest, deps: deps)
            case "unmirror": return try UnmirrorCommand.run(args: rest, deps: deps)
            case "move":     return try MoveCommand.run(args: rest, deps: deps)
            case "rotate":   return try RotateCommand.run(args: rest, deps: deps)
            case "flip":     return try FlipCommand.run(args: rest, deps: deps)
            case "flip-overlay": return try FlipOverlayCommand.run(args: rest, deps: deps)
            case "sleep":    return try SleepCommand.run(args: rest, deps: deps)
            case "pip":      return try PipCommand.run(args: rest, deps: deps)
            case "doctor":   return try DoctorCommand.run(args: rest, deps: deps)
            case "virtual":  return try VirtualCommand.run(args: rest, deps: deps)
            case "screenshot": return try ScreenshotCommand.run(args: rest, deps: deps)
            case "shot-all": return try ShotAllCommand.run(args: rest, deps: deps)
            case "record":   return try RecordCommand.run(args: rest, deps: deps)
            case "scene":    return try SceneCommand.run(args: rest, deps: deps)
            case "move-window": return try MoveWindowCommand.run(args: rest, deps: deps)
            case "focus":    return try FocusCommand.run(args: rest, deps: deps)
            case "stream":   return try StreamCommand.run(args: rest, deps: deps)
            case "pip-grid": return try PipGridCommand.run(args: rest, deps: deps)
            case "panorama": return try PanoramaCommand.run(args: rest, deps: deps)
            case "screen-windows": return try ScreenWindowsCommand.run(args: rest, deps: deps)
            case "tile-app": return try TileAppCommand.run(args: rest, deps: deps)
            case "follow":   return try FollowCommand.run(args: rest, deps: deps)
            case "bind":     return try BindCommand.run(args: rest, deps: deps)
            case "switch":   return try SwitchCommand.run(args: rest, deps: deps)
            case "edid":     return try EDIDCommand.run(args: rest, deps: deps)
            case "hotkeys":  return try HotkeysCommand.run(args: rest, deps: deps)
            case "ddc":      return try DDCCommand.run(args: rest, deps: deps)
            case "rename":   return try RenameCommand.run(args: rest, deps: deps)
            case "cycle":    return try CycleCommand.run(args: rest, deps: deps)
            case "brightness": return try BrightnessCommand.run(args: rest, deps: deps)
            case "completions": return try CompletionsCommand.run(args: rest, deps: deps)
            case "manpage":  return try ManpageCommand.run(args: rest, deps: deps)
            case "watch":    return try WatchCommand.run(args: rest, deps: deps)
            case "workshop": return try WorkshopCommand.run(args: rest, deps: deps)
            case "daemon":   return try DaemonCommand.run(args: rest, deps: deps)
            case "cursor-wrap": return try CursorWrapCommand.run(args: rest, deps: deps)
            default:
                stderr.writeLine("unknown command: \(sub)")
                return ExitCodes.usage
            }
        } catch let error as CLIError {
            stderr.writeLine("error: \(error.message)")
            return error.exitCode
        } catch let error as ProviderError {
            return Self.handleProviderError(error, stderr: stderr)
        } catch {
            stderr.writeLine("error: \(error)")
            return ExitCodes.generic
        }
    }

    private static func handleProviderError(_ error: ProviderError, stderr: OutputWriter) -> Int32 {
        switch error {
        case .displayNotFound(let id):
            stderr.writeLine("error: display not found: \(id)")
            return ExitCodes.displayNotFound
        case .modeNotSupported:
            stderr.writeLine("error: mode not supported")
            return ExitCodes.modeNotSupported
        case .invalidRotation(let d):
            stderr.writeLine("error: invalid rotation: \(d)")
            return ExitCodes.usage
        case .brightnessUnsupported(let id):
            stderr.writeLine("error: brightness not supported on display \(id)")
            return ExitCodes.modeNotSupported
        case .brightnessOutOfRange(let v):
            stderr.writeLine("error: brightness out of range (0…1): \(v)")
            return ExitCodes.usage
        case .configurationFailed(let s):
            stderr.writeLine("error: \(s)")
            return ExitCodes.coreGraphicsError
        case .ioError(let s):
            stderr.writeLine("error: \(s)")
            return ExitCodes.ioError
        case .edidUnavailable(let id):
            stderr.writeLine("error: no EDID for display \(id)")
            return ExitCodes.modeNotSupported
        }
    }
}
