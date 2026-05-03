import Testing
import Foundation
import AVFoundation
@testable import WDMSystem

@Suite("HLSSegmentor — playlist generation (pure)")
struct HLSSegmentorTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hls-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("init segment writes init.mp4")
    func initSegment() throws {
        let dir = try makeTempDir()
        let seg = HLSSegmentor(directoryURL: dir, targetDurationSec: 2)
        let writer = try makeDummyWriter()
        let payload = Data("init-bytes".utf8)
        seg.assetWriter(writer, didOutputSegmentData: payload,
                        segmentType: .initialization, segmentReport: nil)
        let init4 = try Data(contentsOf: dir.appendingPathComponent("init.mp4"))
        #expect(init4 == payload)
    }

    @Test("separable segments stack as seg0, seg1, ... and update playlist")
    func separableSegments() throws {
        let dir = try makeTempDir()
        let seg = HLSSegmentor(directoryURL: dir, targetDurationSec: 2)
        let writer = try makeDummyWriter()
        seg.assetWriter(writer, didOutputSegmentData: Data("a".utf8),
                        segmentType: .separable, segmentReport: nil)
        seg.assetWriter(writer, didOutputSegmentData: Data("bb".utf8),
                        segmentType: .separable, segmentReport: nil)

        let s0 = try Data(contentsOf: dir.appendingPathComponent("seg0.m4s"))
        let s1 = try Data(contentsOf: dir.appendingPathComponent("seg1.m4s"))
        #expect(s0 == Data("a".utf8))
        #expect(s1 == Data("bb".utf8))

        let pl = try String(contentsOf: dir.appendingPathComponent("index.m3u8"), encoding: .utf8)
        #expect(pl.contains("#EXTM3U"))
        #expect(pl.contains("#EXT-X-VERSION:7"))
        #expect(pl.contains("#EXT-X-TARGETDURATION:2"))
        #expect(pl.contains("#EXT-X-PLAYLIST-TYPE:EVENT"))
        #expect(pl.contains("#EXT-X-MAP:URI=\"init.mp4\""))
        #expect(pl.contains("seg0.m4s"))
        #expect(pl.contains("seg1.m4s"))
        // Live: not yet closed.
        #expect(!pl.contains("#EXT-X-ENDLIST"))
    }

    @Test("finalizePlaylist appends EXT-X-ENDLIST")
    func finalize() throws {
        let dir = try makeTempDir()
        let seg = HLSSegmentor(directoryURL: dir, targetDurationSec: 4)
        let writer = try makeDummyWriter()
        seg.assetWriter(writer, didOutputSegmentData: Data("x".utf8),
                        segmentType: .separable, segmentReport: nil)
        seg.finalizePlaylist()
        let pl = try String(contentsOf: dir.appendingPathComponent("index.m3u8"), encoding: .utf8)
        #expect(pl.contains("#EXT-X-ENDLIST"))
        #expect(pl.contains("#EXT-X-TARGETDURATION:4"))
    }

    @Test("playlist with no segments is still valid (init only)")
    func emptyPlaylist() throws {
        let dir = try makeTempDir()
        let seg = HLSSegmentor(directoryURL: dir, targetDurationSec: 2)
        seg.finalizePlaylist()
        let pl = try String(contentsOf: dir.appendingPathComponent("index.m3u8"), encoding: .utf8)
        #expect(pl.contains("#EXTM3U"))
        #expect(pl.contains("#EXT-X-ENDLIST"))
    }

    private func makeDummyWriter() throws -> AVAssetWriter {
        // The delegate API requires an AVAssetWriter parameter we never use.
        // Build a writer that's valid enough to instantiate.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dummy-\(UUID().uuidString).mp4")
        return try AVAssetWriter(outputURL: url, fileType: .mp4)
    }
}
