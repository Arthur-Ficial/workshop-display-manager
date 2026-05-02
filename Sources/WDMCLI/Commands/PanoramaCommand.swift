import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import WDMCore
import WDMSystem

/// Capture every active display + compose a single panoramic PNG arranged
/// horizontally in `provider.snapshot()` order. Useful for "what is every
/// screen showing right now?" status reports + workshop session archives.
public enum PanoramaCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        guard let outPath = Args.flagString(args, name: "--out"), !outPath.isEmpty else {
            throw CLIError.usage("usage: wdm panorama --out <path>")
        }
        let snap = try deps.provider.snapshot()
        guard !snap.displays.isEmpty else {
            throw CLIError.usage("panorama: no displays found")
        }

        // Capture each display via the screenshotter into a temp dir.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-panorama-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var perDisplay: [(id: UInt32, image: CGImage)] = []
        for d in snap.displays {
            let url = tmpDir.appendingPathComponent("d-\(d.id).png")
            try deps.screenshotter.capture(displayID: d.id, to: url)
            // Decode the PNG back into a CGImage. The recording impl writes a
            // tiny 1x1 placeholder PNG; the real impl writes a full-size PNG.
            // Either way, decode whatever's there.
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
                throw ProviderError.ioError("panorama: cannot decode \(url.lastPathComponent)")
            }
            perDisplay.append((id: d.id, image: img))
        }

        // Compose horizontally. Total width = sum of widths; height = max height.
        let totalW = perDisplay.reduce(0) { $0 + $1.image.width }
        let maxH = perDisplay.map { $0.image.height }.max() ?? 1
        let bytesPerRow = totalW * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: totalW, height: maxH,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ProviderError.ioError("panorama: cannot create CGContext")
        }
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: totalW, height: maxH))
        var x = 0
        for entry in perDisplay {
            let w = entry.image.width
            let h = entry.image.height
            // Bottom-aligned (CGContext is flipped, so y=0 is bottom of the image).
            let rect = CGRect(x: x, y: 0, width: w, height: h)
            ctx.draw(entry.image, in: rect)
            x += w
        }
        guard let out = ctx.makeImage() else {
            throw ProviderError.ioError("panorama: cannot finalize image")
        }
        let outURL = URL(fileURLWithPath: outPath)
        guard let dest = CGImageDestinationCreateWithURL(
            outURL as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw ProviderError.ioError("panorama: cannot open \(outURL.path)")
        }
        CGImageDestinationAddImage(dest, out, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw ProviderError.ioError("panorama: PNG encoding failed")
        }
        deps.stderr.writeLine("wdm: panorama \(perDisplay.count) display(s) → \(outURL.path) (\(totalW)x\(maxH))")
        return ExitCodes.success
    }
}
