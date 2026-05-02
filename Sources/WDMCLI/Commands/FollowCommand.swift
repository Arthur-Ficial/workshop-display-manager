import Foundation
import WDMCore
import WDMSystem

/// PIP that re-targets its source whenever the cursor enters a different
/// display. Polls `cursorTracker` once per `--poll-ms` (default 500ms) and,
/// when the source changes, calls `pipFlipper.run(...)` again. Each call
/// is short (`--poll-ms`); the user perceives a continuously-following PIP.
///
///   wdm follow 1 --poll-ms 500 --duration-ms 30000
///   wdm follow main                                 # blocks until SIGTERM
public enum FollowCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let dstAlias = pos.first, !dstAlias.isEmpty else {
            throw CLIError.usage("usage: wdm follow <dst|main> [--poll-ms N] [--duration-ms N]")
        }
        let snap = try deps.provider.snapshot()
        let dstID = try DisplayResolver.resolve(dstAlias, in: snap)
        let pollMs = Args.flagInt(args, name: "--poll-ms") ?? 500
        let durationMs = Args.flagInt(args, name: "--duration-ms")

        let deadline: Date? = durationMs.map { Date(timeIntervalSinceNow: TimeInterval($0) / 1000.0) }
        var lastSrc: UInt32 = 0
        repeat {
            guard let src = deps.cursorTracker.currentDisplayID() else { break }
            if src != lastSrc, src != dstID {
                deps.stderr.writeLine("wdm follow: cursor on display \(src) → spawn PIP on \(dstID)")
                do {
                    try deps.pipFlipper.run(
                        sourceID: src, destinationID: dstID,
                        size: PipSize.defaultSize, position: nil,
                        flip: .none, durationMs: pollMs,
                        remoteControl: false
                    )
                } catch let error as CLIError {
                    throw error
                } catch let error as ProviderError {
                    throw error
                } catch {
                    throw CLIError.ioError("follow: PIP failed: \(error)")
                }
                lastSrc = src
            } else {
                Thread.sleep(forTimeInterval: TimeInterval(pollMs) / 1000.0)
            }
            if let d = deadline, Date() >= d { break }
        } while !shouldStop()
        return ExitCodes.success
    }

    private static func shouldStop() -> Bool { false }   // signal handlers TBD
}
