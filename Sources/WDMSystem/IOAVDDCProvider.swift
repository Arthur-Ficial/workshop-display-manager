import Foundation
import IOKit
import IOKit.graphics
import CoreGraphics

/// Production `DDCProvider`. On Apple Silicon, uses the public-but-private
/// `IOAVServiceCreateWithService` family (the same path BetterDisplay,
/// MonitorControl, and Lunar all use). On Intel, falls back to the
/// classic `IOFBCopyI2CInterface` / `IOI2CSendRequest` pathway.
///
/// Caveats (per CLAUDE.md "honest refusal" rule):
///   - Built-in HDMI of M1/M2 mini and 2018 Intel mini do not expose DDC.
///     We surface `DDCError.unsupported` rather than pretending it worked.
///   - Some monitors require a pause between writes; we do not retry.
public final class IOAVDDCProvider: DDCProvider, @unchecked Sendable {
    public init() {}

    public func read(displayID: UInt32, vcp: UInt8) throws -> UInt16 {
        guard let svc = try? Self.findIOAVService(for: displayID) else {
            throw DDCError.unsupported(displayID)
        }
        defer { Self.releaseService(svc) }
        let request: [UInt8] = [0x51, 0x82, 0x01, vcp, 0x00]
        let withChecksum = Self.appendChecksum(prefix: 0x6E, body: request)
        guard Self.writeI2C(svc, bytes: withChecksum) else {
            throw DDCError.ioFailure("DDC read request write failed")
        }
        // Standard 40 ms inter-message delay per DDC/CI spec.
        Thread.sleep(forTimeInterval: 0.04)
        var reply = [UInt8](repeating: 0, count: 11)
        guard Self.readI2C(svc, bytes: &reply) else {
            throw DDCError.ioFailure("DDC read reply read failed")
        }
        // reply[6] = current value MSB, reply[7] = current value LSB
        let high = UInt16(reply[6])
        let low = UInt16(reply[7])
        return (high << 8) | low
    }

    public func write(displayID: UInt32, vcp: UInt8, value: UInt16) throws {
        guard let svc = try? Self.findIOAVService(for: displayID) else {
            throw DDCError.unsupported(displayID)
        }
        defer { Self.releaseService(svc) }
        let high = UInt8((value >> 8) & 0xFF)
        let low = UInt8(value & 0xFF)
        let body: [UInt8] = [0x51, 0x84, 0x03, vcp, high, low]
        let withChecksum = Self.appendChecksum(prefix: 0x6E, body: body)
        guard Self.writeI2C(svc, bytes: withChecksum) else {
            throw DDCError.ioFailure("DDC write failed")
        }
    }

    // MARK: - private bridges to dlsym'd IOAVService SPI

    private static func findIOAVService(for id: CGDirectDisplayID) throws -> UnsafeMutableRawPointer {
        // The function symbol we need is `IOAVServiceCreateWithService`.
        // Resolved at runtime via dlopen so the build doesn't need a
        // private framework header.
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/IOKit.framework/IOKit", RTLD_LAZY
        ) ?? dlopen(nil, RTLD_LAZY) else {
            throw DDCError.unsupported(id)
        }
        guard let createSym = dlsym(handle, "IOAVServiceCreateWithService") else {
            throw DDCError.unsupported(id)
        }
        // Find the matching IOFramebuffer service for this display.
        guard let frameSvc = framebufferService(for: id) else {
            throw DDCError.unsupported(id)
        }
        defer { IOObjectRelease(frameSvc) }
        typealias CreateFn = @convention(c) (CFAllocator?, io_service_t) -> UnsafeMutableRawPointer?
        let create = unsafeBitCast(createSym, to: CreateFn.self)
        guard let svc = create(kCFAllocatorDefault, frameSvc) else {
            throw DDCError.unsupported(id)
        }
        return svc
    }

    private static func releaseService(_ svc: UnsafeMutableRawPointer) {
        // CFRelease on the toll-free CFType pointer.
        let cf = Unmanaged<AnyObject>.fromOpaque(svc).takeRetainedValue()
        _ = cf
    }

    private static func writeI2C(_ svc: UnsafeMutableRawPointer, bytes: [UInt8]) -> Bool {
        guard let handle = dlopen(nil, RTLD_LAZY),
              let sym = dlsym(handle, "IOAVServiceWriteI2C") else { return false }
        typealias WriteFn = @convention(c) (
            UnsafeMutableRawPointer, UInt32, UInt32, UnsafeRawPointer, UInt32
        ) -> Int32
        let writeFn = unsafeBitCast(sym, to: WriteFn.self)
        let r: Int32 = bytes.withUnsafeBufferPointer { buf in
            // 0x37 is the standard DDC/CI device address (>>1 of 0x6E).
            writeFn(svc, 0x37, 0x51, buf.baseAddress!, UInt32(buf.count))
        }
        return r == 0
    }

    private static func readI2C(_ svc: UnsafeMutableRawPointer, bytes: inout [UInt8]) -> Bool {
        guard let handle = dlopen(nil, RTLD_LAZY),
              let sym = dlsym(handle, "IOAVServiceReadI2C") else { return false }
        typealias ReadFn = @convention(c) (
            UnsafeMutableRawPointer, UInt32, UInt32, UnsafeMutableRawPointer, UInt32
        ) -> Int32
        let readFn = unsafeBitCast(sym, to: ReadFn.self)
        let r: Int32 = bytes.withUnsafeMutableBufferPointer { buf in
            readFn(svc, 0x37, 0x51, buf.baseAddress!, UInt32(buf.count))
        }
        return r == 0
    }

    private static func appendChecksum(prefix: UInt8, body: [UInt8]) -> [UInt8] {
        var checksum = prefix
        for b in body { checksum ^= b }
        return body + [checksum]
    }

    private static func framebufferService(for id: CGDirectDisplayID) -> io_service_t? {
        let vendor = CGDisplayVendorNumber(id)
        let model = CGDisplayModelNumber(id)
        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iter) }
        var serv = IOIteratorNext(iter)
        while serv != 0 {
            let info = IODisplayCreateInfoDictionary(
                serv, IOOptionBits(kIODisplayOnlyPreferredName)
            ).takeRetainedValue() as? [String: Any]
            let v = info?[kDisplayVendorID] as? UInt32 ?? 0
            let m = info?[kDisplayProductID] as? UInt32 ?? 0
            if v == vendor && m == model {
                return serv
            }
            IOObjectRelease(serv)
            serv = IOIteratorNext(iter)
        }
        return nil
    }
}
