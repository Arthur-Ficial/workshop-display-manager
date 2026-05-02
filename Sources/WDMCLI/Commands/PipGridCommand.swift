import Foundation
import WDMCore
import WDMSystem

/// Tile multiple PIPs of multiple source displays onto one destination display
/// in a grid. Replaces the manual "spawn N `wdm pip` processes at distinct
/// `--x`/`--y`" pattern users were running by hand.
///
///   wdm pip-grid 33,34,35 --on 1 --cols 3 --duration-ms 0
///
/// Each source is spawned as a sibling Task on the recording PIP flipper
/// (or as a real PIP via `deps.pipFlipper.run`). All windows tear down
/// together when the command exits.
public enum PipGridCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let csvList = pos.first, !csvList.isEmpty else {
            throw CLIError.usage(
                "usage: wdm pip-grid <id1,id2,...> [--on <dst>] [--cols N] [--duration-ms N]"
            )
        }
        let snap = try deps.provider.snapshot()
        let srcIDs = try csvList
            .split(separator: ",")
            .map { try DisplayResolver.resolve(String($0), in: snap) }
        let dstID: UInt32
        if let dstToken = Args.flagString(args, name: "--on"), !dstToken.isEmpty {
            dstID = try DisplayResolver.resolve(dstToken, in: snap)
        } else {
            guard let m = snap.main?.id else {
                throw CLIError.usage("pip-grid: no main display and no --on")
            }
            dstID = m
        }
        let cols: Int
        if let c = Args.flagString(args, name: "--cols"), let n = Int(c), n > 0 {
            cols = n
        } else {
            cols = max(1, Int(Double(srcIDs.count).squareRoot().rounded(.up)))
        }
        let durationMs = Args.flagInt(args, name: "--duration-ms")

        // Resolve dst display bounds for grid layout.
        guard let dstInfo = snap.display(id: dstID) else {
            throw ProviderError.displayNotFound(dstID)
        }
        let dstW = dstInfo.currentMode.width
        let dstH = dstInfo.currentMode.height
        let rows = Int((Double(srcIDs.count) / Double(cols)).rounded(.up))
        let margin = 8
        let cellW = max(120, (dstW - margin * (cols + 1)) / cols)
        let cellH = max(80,  (dstH - margin * (rows + 1)) / rows)

        let pipFlipper = deps.pipFlipper
        let errorBox = PipGridErrorBox()
        let testMode = deps.virtualDisplayManager is RecordingVirtualDisplayManager
            || ProcessInfo.processInfo.environment["WDM_TEST_PIP_LOG"]
                .map({ !$0.isEmpty }) ?? false

        // Spawn one Task.detached per source. Each calls pipFlipper.run on
        // its own thread; they all block until durationMs (or until the
        // parent process exits).
        for (i, src) in srcIDs.enumerated() {
            let col = i % cols
            let row = i / cols
            let x = margin + col * (cellW + margin)
            let y = margin + row * (cellH + margin)
            let pos = PipPosition(x: x, y: y)
            let size = PipSize(width: cellW, height: cellH)
            let pipDur = testMode ? 10 : durationMs
            Task.detached(priority: .userInitiated) {
                do {
                    try pipFlipper.run(
                        sourceID: src, destinationID: dstID,
                        size: size, position: pos,
                        flip: .none, durationMs: pipDur,
                        remoteControl: false
                    )
                } catch {
                    errorBox.set(error)
                }
            }
        }

        // For test mode, yield long enough for every recording-PIP task to
        // flush its log line. For real mode, block on the main runloop until
        // the first pip's natural duration expires.
        if testMode {
            Thread.sleep(forTimeInterval: 0.30)
        } else if let ms = durationMs {
            Thread.sleep(forTimeInterval: TimeInterval(ms) / 1000.0)
        } else {
            // Indefinite — block on the main runloop with signal handlers.
            let stop = AtomicGridFlag()
            let sources = installSignalHandlers { stop.set() }
            defer { _ = sources }
            while !stop.get() {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
            }
        }
        if let error = errorBox.get() {
            try throwPipError(error)
        }
        return ExitCodes.success
    }

    private static func throwPipError(_ error: Error) throws {
        if let error = error as? CLIError { throw error }
        if let error = error as? ProviderError { throw error }
        throw CLIError.ioError("pip-grid: PIP failed: \(error)")
    }

    private static func installSignalHandlers(_ onSignal: @escaping () -> Void) -> [DispatchSourceSignal] {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        signal(SIGHUP, SIG_IGN)
        return [SIGINT, SIGTERM, SIGHUP].map { sig in
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { onSignal() }
            src.resume()
            return src
        }
    }
}

private final class AtomicGridFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var f = false
    func set() { lock.withLock { f = true } }
    func get() -> Bool { lock.withLock { f } }
}

private final class PipGridErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var error: Error?
    func set(_ e: Error) { lock.withLock { if error == nil { error = e } } }
    func get() -> Error? { lock.withLock { error } }
}
