import Foundation

/// Parsed Extended Display Identification Data — the 128-byte (or longer)
/// blob every monitor reports over EDID-DDC. Identity facts only — no
/// detailed-timing parsing here (we get current mode from CoreGraphics).
public struct EDID: Equatable, Hashable, Sendable, Codable {
    public let raw: [UInt8]
    public let manufacturerID: String
    public let productCode: UInt16
    public let serialNumber: UInt32
    public let manufactureWeek: UInt8
    public let manufactureYear: Int
    public let edidVersion: String
    public let displayName: String?
    public let serialString: String?

    public init(
        raw: [UInt8],
        manufacturerID: String,
        productCode: UInt16,
        serialNumber: UInt32,
        manufactureWeek: UInt8,
        manufactureYear: Int,
        edidVersion: String,
        displayName: String?,
        serialString: String?
    ) {
        self.raw = raw
        self.manufacturerID = manufacturerID
        self.productCode = productCode
        self.serialNumber = serialNumber
        self.manufactureWeek = manufactureWeek
        self.manufactureYear = manufactureYear
        self.edidVersion = edidVersion
        self.displayName = displayName
        self.serialString = serialString
    }

    /// Parse a 128-byte (or longer; only first block is used) EDID blob.
    /// Returns nil if header magic is wrong, length insufficient, or
    /// the block-zero checksum is invalid.
    public static func parse(_ bytes: [UInt8]) -> EDID? {
        guard bytes.count >= 128 else { return nil }
        let header: [UInt8] = [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]
        guard Array(bytes[0..<8]) == header else { return nil }
        let sum: Int = bytes[0..<128].reduce(0) { $0 + Int($1) }
        guard sum % 256 == 0 else { return nil }

        let manufacturerID = decodeManufacturer(high: bytes[8], low: bytes[9])
        let productCode = UInt16(bytes[10]) | (UInt16(bytes[11]) << 8)
        let serial =
            UInt32(bytes[12])
            | (UInt32(bytes[13]) << 8)
            | (UInt32(bytes[14]) << 16)
            | (UInt32(bytes[15]) << 24)
        let week = bytes[16]
        let year = Int(bytes[17]) + 1990
        let version = "\(bytes[18]).\(bytes[19])"

        var displayName: String?
        var serialString: String?
        // Four 18-byte descriptor blocks at offsets 54, 72, 90, 108.
        for offset in [54, 72, 90, 108] {
            let block = Array(bytes[offset..<(offset + 18)])
            // A descriptor is "non-detailed" (a metadata block) when its first
            // two bytes are 0 — distinguishes it from a detailed timing.
            guard block[0] == 0 && block[1] == 0 else { continue }
            let tag = block[3]
            let payload = Array(block[5..<18])
            let text = decodeText(payload)
            switch tag {
            case 0xFC: displayName = text
            case 0xFF: serialString = text
            default: break
            }
        }

        return EDID(
            raw: bytes,
            manufacturerID: manufacturerID,
            productCode: productCode,
            serialNumber: serial,
            manufactureWeek: week,
            manufactureYear: year,
            edidVersion: version,
            displayName: displayName,
            serialString: serialString
        )
    }

    /// Stable identity key for this physical display: 64 bits of SHA-256
    /// of `manufacturer|product|serial`. Survives reboot, replug, port
    /// changes — anything that doesn't physically swap the panel.
    public var stableID: String {
        let identity = "\(manufacturerID)|\(productCode)|\(serialNumber)"
        return EDIDStableHash.hash(identity)
    }

    private static func decodeManufacturer(high: UInt8, low: UInt8) -> String {
        let combined = (UInt16(high) << 8) | UInt16(low)
        let c1 = UInt8((combined >> 10) & 0x1F)
        let c2 = UInt8((combined >> 5) & 0x1F)
        let c3 = UInt8(combined & 0x1F)
        let chars = [c1, c2, c3].map { c -> Character in
            // Letters are 1-based: 1='A', 2='B', …, 26='Z'.
            guard (1...26).contains(c) else { return "?" }
            return Character(UnicodeScalar(0x40 + UInt32(c))!)
        }
        return String(chars)
    }

    private static func decodeText(_ bytes: [UInt8]) -> String? {
        var end = bytes.count
        for i in 0..<bytes.count where bytes[i] == 0x0A { end = i; break }
        let trimmed = bytes[0..<end]
        let scalars = trimmed.compactMap { byte -> Unicode.Scalar? in
            byte >= 0x20 && byte < 0x7F ? Unicode.Scalar(byte) : nil
        }
        let s = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }
}

/// SHA-256 → 16 hex chars, identical algorithm to EDIDHasher but
/// hashing an arbitrary identity string. Kept separate so we don't
/// expose EDIDHasher's display-set-specific surface.
enum EDIDStableHash {
    static func hash(_ s: String) -> String {
        let digest = sha256(s)
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ s: String) -> [UInt8] {
        var h: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        ]
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
            0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
            0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
            0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
            0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
            0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
            0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
            0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
            0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]
        var bytes = Array(s.utf8)
        let bitLength = UInt64(bytes.count) * 8
        bytes.append(0x80)
        while bytes.count % 64 != 56 { bytes.append(0) }
        for i in 0..<8 { bytes.append(UInt8((bitLength >> ((7 - i) * 8)) & 0xff)) }
        for chunkStart in stride(from: 0, to: bytes.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let base = chunkStart + i * 4
                w[i] = (UInt32(bytes[base]) << 24)
                     | (UInt32(bytes[base + 1]) << 16)
                     | (UInt32(bytes[base + 2]) << 8)
                     |  UInt32(bytes[base + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let t1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let mj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = s0 &+ mj
                hh = g; g = f; f = e; e = d &+ t1
                d = c; c = b; b = a; a = t1 &+ t2
            }
            h[0] &+= a; h[1] &+= b; h[2] &+= c; h[3] &+= d
            h[4] &+= e; h[5] &+= f; h[6] &+= g; h[7] &+= hh
        }
        var out: [UInt8] = []
        for word in h {
            for shift in stride(from: 24, through: 0, by: -8) {
                out.append(UInt8((word >> UInt32(shift)) & 0xff))
            }
        }
        return out
    }

    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x >> n) | (x << (32 - n))
    }
}
