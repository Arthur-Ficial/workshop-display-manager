import Foundation
import WDMCore
import WDMSystem

extension WDMController {
    public func screenshot(_ alias: String, to url: URL, using screenshotter: Screenshotter) throws {
        try mapErrors {
            try screenshotter.capture(displayID: get(alias).id, to: url)
        }
    }

    public func record(_ alias: String, to url: URL, durationSec: Int, using recorder: Recorder) throws {
        try mapErrors {
            try recorder.record(displayID: get(alias).id, to: url, durationSec: durationSec)
        }
    }

    public func flipOverlay(
        _ alias: String,
        flip: Flip,
        durationMs: Int?,
        using flipper: OverlayFlipper
    ) throws {
        try mapErrors {
            try flipper.run(displayID: get(alias).id, flip: flip, durationMs: durationMs)
        }
    }

    public func pip(
        source: String,
        on destination: String,
        size: PipSize,
        position: PipPosition?,
        flip: Flip,
        durationMs: Int?,
        remoteControl: Bool,
        using flipper: PipFlipper
    ) throws {
        try mapErrors {
            try flipper.run(
                sourceID: get(source).id,
                destinationID: get(destination).id,
                size: size,
                position: position,
                flip: flip,
                durationMs: durationMs,
                remoteControl: remoteControl
            )
        }
    }

    public func stream(
        _ alias: String,
        target: String,
        mode: StreamMode,
        durationSec: Int,
        options: StreamOptions,
        using streamer: Streamer
    ) throws {
        try mapErrors {
            try streamer.stream(
                displayID: get(alias).id,
                target: target,
                mode: mode,
                durationSec: durationSec,
                options: options
            )
        }
    }
}
