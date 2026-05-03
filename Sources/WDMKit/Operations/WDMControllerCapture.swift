import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import WDMSystem

extension WDMController {
    public struct PanoramaResult: Equatable, Sendable {
        public let outputURL: URL
        public let displayCount: Int
        public let totalWidth: Int
        public let height: Int
    }

    /// Capture every active display to `<dir>/display-<id>.png` and return the paths.
    public func shotAll(to directory: URL, using screenshotter: Screenshotter) throws -> [URL] {
        try mapErrors {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let snap = try provider.snapshot()
            return try snap.displays.map { display in
                let url = directory.appendingPathComponent("display-\(display.id).png")
                try screenshotter.capture(displayID: display.id, to: url)
                return url
            }
        }
    }

    /// Compose every active display into a single horizontal PNG.
    public func panorama(to outputURL: URL, using screenshotter: Screenshotter) throws -> PanoramaResult {
        try mapErrors {
            let snap = try provider.snapshot()
            guard !snap.displays.isEmpty else {
                throw WDMError.usage("panorama: no displays found")
            }
            let images = try captureAll(displays: snap.displays, using: screenshotter)
            try writePanorama(images: images, to: outputURL)
            let totalW = images.reduce(0) { $0 + $1.width }
            let maxH = images.map { $0.height }.max() ?? 1
            return PanoramaResult(outputURL: outputURL, displayCount: images.count,
                                  totalWidth: totalW, height: maxH)
        }
    }

    private func captureAll(displays: [DisplayInfo], using screenshotter: Screenshotter) throws -> [CGImage] {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-panorama-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        return try displays.map { display in
            let url = tmpDir.appendingPathComponent("d-\(display.id).png")
            try screenshotter.capture(displayID: display.id, to: url)
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
                throw WDMError.ioError("panorama: cannot decode \(url.lastPathComponent)")
            }
            return img
        }
    }

    private func writePanorama(images: [CGImage], to outputURL: URL) throws {
        let totalW = images.reduce(0) { $0 + $1.width }
        let maxH = images.map { $0.height }.max() ?? 1
        let bytesPerRow = totalW * 4
        guard let ctx = CGContext(
            data: nil, width: totalW, height: maxH,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw WDMError.ioError("panorama: cannot create CGContext") }
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: totalW, height: maxH))
        var x = 0
        for img in images {
            ctx.draw(img, in: CGRect(x: x, y: 0, width: img.width, height: img.height))
            x += img.width
        }
        guard let out = ctx.makeImage() else {
            throw WDMError.ioError("panorama: cannot finalize image")
        }
        guard let dest = CGImageDestinationCreateWithURL(
            outputURL as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { throw WDMError.ioError("panorama: cannot open \(outputURL.path)") }
        CGImageDestinationAddImage(dest, out, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw WDMError.ioError("panorama: PNG encoding failed")
        }
    }
}
