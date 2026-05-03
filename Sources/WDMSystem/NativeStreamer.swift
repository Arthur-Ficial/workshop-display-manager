import Foundation
import AppKit
import CoreGraphics
import CoreMedia
import AVFoundation
import ScreenCaptureKit
import WDMCore

/// Native HLS streamer. SCStream → AVAssetWriter (mpeg4AppleHLS profile) →
/// segment delegate writes init.mp4 + segN.m4s + index.m3u8 to the target dir.
/// No external ffmpeg.
public final class NativeStreamer: Streamer, @unchecked Sendable {
    public init() {}

    public func stream(
        displayID: UInt32, target: String, mode: StreamMode,
        durationSec: Int, options: StreamOptions
    ) throws {
        guard mode == .hls else {
            throw ProviderError.configurationFailed(
                "stream: native streamer supports --hls only; RTMP unimplemented (issue #6)"
            )
        }
        try PermissionProbe.requireScreenRecording(context: "stream")

        let dirURL = URL(fileURLWithPath: target)
        try FileManager.default.createDirectory(
            at: dirURL, withIntermediateDirectories: true
        )

        let errBox = ErrorBoxNS()
        let done = DispatchSemaphore(value: 0)

        // Single Task that owns SCStream + writer for the whole duration.
        // EVERY object must remain a local of this function — storing SCStream
        // in `self` causes frame delivery to stall after the first sample on
        // macOS 26.
        Task { @MainActor in
            do {
                try await Self.runStream(
                    displayID: displayID, dir: dirURL,
                    durationSec: durationSec, options: options
                )
            } catch {
                errBox.set(error)
            }
            done.signal()
        }

        while done.wait(timeout: .now() + .milliseconds(50)) == .timedOut {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        if let err = errBox.get() { throw err }
    }

    @MainActor
    private static func runStream(
        displayID: UInt32, dir: URL, durationSec: Int, options: StreamOptions
    ) async throws {
        _ = NSApplication.shared.setActivationPolicy(.accessory)

        let content = try await SCShareableContent.current
        guard let scDisplay = content.displays.first(where: {
            $0.displayID == CGDirectDisplayID(displayID)
        }) else {
            throw ProviderError.displayNotFound(displayID)
        }

        let cfg = SCStreamConfiguration()
        cfg.width = Int(scDisplay.width)
        cfg.height = Int(scDisplay.height)
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: Int32(options.framerate))
        cfg.queueDepth = 5
        cfg.showsCursor = options.showCursor
        cfg.pixelFormat = kCVPixelFormatType_32BGRA
        cfg.colorSpaceName = CGColorSpace.sRGB
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

        let segmentor = HLSSegmentor(
            directoryURL: dir, targetDurationSec: options.segmentDurationSec
        )
        let writer = AVAssetWriter(contentType: .mpeg4Movie)
        writer.shouldOptimizeForNetworkUse = true
        writer.outputFileTypeProfile = .mpeg4AppleHLS
        writer.preferredOutputSegmentInterval = CMTime(
            seconds: Double(options.segmentDurationSec), preferredTimescale: 1
        )
        writer.initialSegmentStartTime = .zero
        writer.delegate = segmentor

        // Keep encoder settings minimal — heavy compressionProperties combined
        // with mpeg4AppleHLS profile triggered VTVideoEncoderMalfunction (-16122).
        // We DO honor an explicit --bitrate; default is the encoder's choice.
        var videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: scDisplay.width,
            AVVideoHeightKey: scDisplay.height,
        ]
        if let kbps = options.bitrateKbps {
            videoSettings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: kbps * 1000
            ]
        }
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(videoInput) else {
            throw ProviderError.ioError("stream: AVAssetWriter cannot accept video input")
        }
        writer.add(videoInput)

        let adapter = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: scDisplay.width,
                kCVPixelBufferHeightKey as String: scDisplay.height,
            ]
        )

        guard writer.startWriting() else {
            throw ProviderError.ioError(
                "stream: AVAssetWriter.startWriting failed: \(writer.error?.localizedDescription ?? "?")"
            )
        }
        writer.startSession(atSourceTime: .zero)

        let sink = NSStreamFrameSink(input: videoInput, adapter: adapter)
        let captureQ = DispatchQueue(label: "wdm.stream.capture", qos: .userInteractive)
        let s = SCStream(filter: filter, configuration: cfg, delegate: nil)
        try s.addStreamOutput(sink, type: .screen, sampleHandlerQueue: captureQ)
        try await s.startCapture()

        // Hold everything alive for the whole duration.
        let durationNs = UInt64(durationSec) * 1_000_000_000
        try await Task.sleep(nanoseconds: durationNs)

        try? await s.stopCapture()
        videoInput.markAsFinished()
        await writer.finishWriting()
        segmentor.finalizePlaylist()
        if ProcessInfo.processInfo.environment["WDM_STREAM_DEBUG"] == "1" {
            FileHandle.standardError.write(Data(
                "stream: seen=\(NSStreamFrameSink.seen) appended=\(NSStreamFrameSink.appended)\n".utf8
            ))
        }
        // Keep references alive past the suspends above.
        _ = sink
        _ = filter
        _ = cfg
    }
}

private final class ErrorBoxNS: @unchecked Sendable {
    private let lock = NSLock()
    private var err: Error?
    func set(_ e: Error) { lock.withLock { err = e } }
    func get() -> Error? { lock.withLock { err } }
}

@objc final class NSStreamFrameSink: NSObject, SCStreamOutput, @unchecked Sendable {
    private let input: AVAssetWriterInput
    private let adapter: AVAssetWriterInputPixelBufferAdaptor
    private let lock = NSLock()
    private var firstPTS: CMTime?
    nonisolated(unsafe) static var seen = 0
    nonisolated(unsafe) static var appended = 0
    nonisolated(unsafe) static var notReady = 0
    nonisolated(unsafe) static var rejected = 0

    init(input: AVAssetWriterInput, adapter: AVAssetWriterInputPixelBufferAdaptor) {
        self.input = input
        self.adapter = adapter
    }

    @objc func stream(
        _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        Self.seen += 1
        guard type == .screen, sampleBuffer.isValid else { return }
        guard let pb = sampleBuffer.imageBuffer else { return }
        guard input.isReadyForMoreMediaData else { Self.notReady += 1; return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let translated: CMTime
        lock.lock()
        if firstPTS == nil { firstPTS = pts }
        translated = CMTimeSubtract(pts, firstPTS!)
        lock.unlock()
        if adapter.append(pb, withPresentationTime: translated) {
            Self.appended += 1
        } else {
            Self.rejected += 1
        }
    }
}

final class HLSSegmentor: NSObject, AVAssetWriterDelegate, @unchecked Sendable {
    let dir: URL
    let targetDurationSec: Int
    private let lock = NSLock()
    private var index = 0
    private var segments: [(name: String, duration: Double)] = []

    init(directoryURL: URL, targetDurationSec: Int) {
        self.dir = directoryURL
        self.targetDurationSec = targetDurationSec
    }

    func assetWriter(
        _ writer: AVAssetWriter,
        didOutputSegmentData segmentData: Data,
        segmentType: AVAssetSegmentType,
        segmentReport: AVAssetSegmentReport?
    ) {
        lock.lock()
        defer { lock.unlock() }
        switch segmentType {
        case .initialization:
            try? segmentData.write(to: dir.appendingPathComponent("init.mp4"))
        case .separable:
            let name = "seg\(index).m4s"
            try? segmentData.write(to: dir.appendingPathComponent(name))
            let dur = segmentReport?.trackReports.first?.duration.seconds
                ?? Double(targetDurationSec)
            segments.append((name, dur))
            index += 1
            writePlaylistLocked(closed: false)
        @unknown default:
            break
        }
    }

    func finalizePlaylist() {
        lock.lock()
        defer { lock.unlock() }
        writePlaylistLocked(closed: true)
    }

    private func writePlaylistLocked(closed: Bool) {
        var s = "#EXTM3U\n"
        s += "#EXT-X-VERSION:7\n"
        s += "#EXT-X-TARGETDURATION:\(targetDurationSec)\n"
        s += "#EXT-X-MEDIA-SEQUENCE:0\n"
        s += "#EXT-X-PLAYLIST-TYPE:EVENT\n"
        s += "#EXT-X-MAP:URI=\"init.mp4\"\n"
        for seg in segments {
            s += "#EXTINF:\(String(format: "%.3f", seg.duration)),\n"
            s += "\(seg.name)\n"
        }
        if closed { s += "#EXT-X-ENDLIST\n" }
        try? s.write(
            to: dir.appendingPathComponent("index.m3u8"),
            atomically: true, encoding: .utf8
        )
    }
}
