import Foundation

enum SHA256 {
    static func digest(_ message: [UInt8]) -> [UInt8] {
        var bytes = message
        let bitLength = UInt64(bytes.count) &* 8
        bytes.append(0x80)
        while bytes.count % 64 != 56 {
            bytes.append(0)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8((bitLength >> UInt64(shift)) & 0xff))
        }

        var h: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        ]

        var offset = 0
        while offset < bytes.count {
            var w = [UInt32](repeating: 0, count: 64)
            for index in 0..<16 {
                let start = offset + index * 4
                w[index] = (UInt32(bytes[start]) << 24)
                    | (UInt32(bytes[start + 1]) << 16)
                    | (UInt32(bytes[start + 2]) << 8)
                    | UInt32(bytes[start + 3])
            }
            for index in 16..<64 {
                let s0 = rotr(w[index - 15], 7) ^ rotr(w[index - 15], 18) ^ (w[index - 15] >> 3)
                let s1 = rotr(w[index - 2], 17) ^ rotr(w[index - 2], 19) ^ (w[index - 2] >> 10)
                w[index] = w[index - 16] &+ s0 &+ w[index - 7] &+ s1
            }

            var a = h[0]
            var b = h[1]
            var c = h[2]
            var d = h[3]
            var e = h[4]
            var f = h[5]
            var g = h[6]
            var hh = h[7]

            for index in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ ((~e) & g)
                let temp1 = hh &+ s1 &+ ch &+ roundConstants[index] &+ w[index]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                hh = g
                g = f
                f = e
                e = d &+ temp1
                d = c
                c = b
                b = a
                a = temp1 &+ temp2
            }

            h[0] = h[0] &+ a
            h[1] = h[1] &+ b
            h[2] = h[2] &+ c
            h[3] = h[3] &+ d
            h[4] = h[4] &+ e
            h[5] = h[5] &+ f
            h[6] = h[6] &+ g
            h[7] = h[7] &+ hh
            offset += 64
        }

        var out: [UInt8] = []
        out.reserveCapacity(32)
        for value in h {
            out.append(UInt8((value >> 24) & 0xff))
            out.append(UInt8((value >> 16) & 0xff))
            out.append(UInt8((value >> 8) & 0xff))
            out.append(UInt8(value & 0xff))
        }
        return out
    }

    private static func rotr(_ value: UInt32, _ count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }

    private static let roundConstants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]
}

enum HMACSHA256 {
    static func digest(key: [UInt8], message: [UInt8]) -> [UInt8] {
        var paddedKey = key
        if paddedKey.count > 64 {
            paddedKey = SHA256.digest(paddedKey)
        }
        if paddedKey.count < 64 {
            paddedKey.append(contentsOf: [UInt8](repeating: 0, count: 64 - paddedKey.count))
        }
        let innerPad = paddedKey.map { $0 ^ 0x36 }
        let outerPad = paddedKey.map { $0 ^ 0x5c }
        return SHA256.digest(outerPad + SHA256.digest(innerPad + message))
    }
}

enum PBKDF2 {
    static func hmacSHA256(password: [UInt8], salt: [UInt8], iterations: Int, derivedLength: Int) -> [UInt8] {
        precondition(iterations > 0)
        precondition(derivedLength > 0)
        let blockCount = (derivedLength + 31) / 32
        var derived: [UInt8] = []
        derived.reserveCapacity(blockCount * 32)
        for block in 1...blockCount {
            var blockSalt = salt
            blockSalt.append(UInt8((block >> 24) & 0xff))
            blockSalt.append(UInt8((block >> 16) & 0xff))
            blockSalt.append(UInt8((block >> 8) & 0xff))
            blockSalt.append(UInt8(block & 0xff))
            var u = HMACSHA256.digest(key: password, message: blockSalt)
            var t = u
            if iterations > 1 {
                for _ in 2...iterations {
                    u = HMACSHA256.digest(key: password, message: u)
                    for index in 0..<t.count {
                        t[index] ^= u[index]
                    }
                }
            }
            derived.append(contentsOf: t)
        }
        return Array(derived.prefix(derivedLength))
    }
}

public enum PasswordHasherError: Error, Equatable {
    case tooShort
    case invalidIterations
}

/// Salted PBKDF2-HMAC-SHA256 records. The password itself is never stored.
public enum PasswordHasher {
    public static let defaultIterations = 20_000
    public static let minimumLength = 4
    public static let maximumIterations = 500_000
    public static let derivedLength = 32

    public static func validateLength(_ password: String) -> Bool {
        password.count >= minimumLength
    }

    public static func makeRecord(password: String, iterations: Int = defaultIterations) throws -> String {
        var salt = [UInt8](repeating: 0, count: 16)
        for index in salt.indices {
            salt[index] = UInt8.random(in: .min ... .max)
        }
        return try makeRecord(password: password, salt: salt, iterations: iterations)
    }

    public static func makeRecord(password: String, salt: [UInt8], iterations: Int) throws -> String {
        guard validateLength(password) else { throw PasswordHasherError.tooShort }
        guard iterations >= 1, iterations <= maximumIterations else { throw PasswordHasherError.invalidIterations }
        let derived = PBKDF2.hmacSHA256(
            password: Array(password.utf8),
            salt: salt,
            iterations: iterations,
            derivedLength: derivedLength
        )
        let saltText = Data(salt).base64EncodedString()
        let hashText = Data(derived).base64EncodedString()
        return "pbkdf2-sha256$\(iterations)$\(saltText)$\(hashText)"
    }

    public static func verify(password: String, record: String) -> Bool {
        let parts = record.split(separator: "$", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == "pbkdf2-sha256" else { return false }
        guard let iterations = Int(parts[1]), iterations >= 1, iterations <= maximumIterations else { return false }
        guard let salt = Data(base64Encoded: parts[2]), !salt.isEmpty else { return false }
        guard let expected = Data(base64Encoded: parts[3]), expected.count == derivedLength else { return false }
        let actual = PBKDF2.hmacSHA256(
            password: Array(password.utf8),
            salt: [UInt8](salt),
            iterations: iterations,
            derivedLength: derivedLength
        )
        return constantTimeEqual(actual, [UInt8](expected))
    }

    static func constantTimeEqual(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for index in lhs.indices {
            difference |= lhs[index] ^ rhs[index]
        }
        return difference == 0
    }
}
