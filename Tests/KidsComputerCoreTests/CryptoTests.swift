import XCTest
@testable import KidsComputerCore

final class CryptoTests: XCTestCase {
    func testSHA256KnownAnswers() {
        XCTAssertEqual(hex(SHA256.digest([])), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(hex(SHA256.digest(Array("abc".utf8))), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let longer = Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)
        XCTAssertEqual(hex(SHA256.digest(longer)), "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    func testHMACKnownAnswer() {
        let key = [UInt8](repeating: 0x0b, count: 20)
        let message = Array("Hi There".utf8)
        XCTAssertEqual(
            hex(HMACSHA256.digest(key: key, message: message)),
            "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
        )
    }

    func testPBKDF2HMACSHA256() {
        // RFC 6070 publishes PBKDF2-HMAC-SHA1 vectors. These are the SHA-256
        // results for the same password, salt, and iteration counts.
        let password = Array("password".utf8)
        let salt = Array("salt".utf8)
        XCTAssertEqual(
            hex(PBKDF2.hmacSHA256(password: password, salt: salt, iterations: 1, derivedLength: 32)),
            "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"
        )
        XCTAssertEqual(
            hex(PBKDF2.hmacSHA256(password: password, salt: salt, iterations: 2, derivedLength: 20)),
            "ae4d0c95af6b46d32d0adff928f06dd02a303f8e"
        )
        XCTAssertEqual(
            hex(PBKDF2.hmacSHA256(password: password, salt: salt, iterations: 4096, derivedLength: 20)),
            "c5e478d59288c841aa530db6845c4c8d962893a0"
        )
    }

    func testPasswordRecordRoundTripDoesNotStoreThePassword() throws {
        let password = "river-lamp"
        let record = try PasswordHasher.makeRecord(password: password, salt: Array("salt-salt-salt!".utf8), iterations: 2)
        XCTAssertFalse(record.contains(password))
        XCTAssertTrue(record.hasPrefix("pbkdf2-sha256$2$"))
        XCTAssertTrue(PasswordHasher.verify(password: password, record: record))
        XCTAssertFalse(PasswordHasher.verify(password: "river-lamq", record: record))
        XCTAssertFalse(PasswordHasher.verify(password: password, record: "pbkdf2-sha256$9999999$aa$bb"))
        XCTAssertFalse(PasswordHasher.verify(password: password, record: "plaintext"))
    }

    func testPasswordRecordsUseAFreshSalt() throws {
        let first = try PasswordHasher.makeRecord(password: "same-password", iterations: 1)
        let second = try PasswordHasher.makeRecord(password: "same-password", iterations: 1)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(PasswordHasher.verify(password: "same-password", record: first))
        XCTAssertTrue(PasswordHasher.verify(password: "same-password", record: second))
    }

    func testShortPasswordIsRejected() {
        XCTAssertFalse(PasswordHasher.validateLength("no"))
        XCTAssertThrowsError(try PasswordHasher.makeRecord(password: "no", iterations: 1)) { error in
            XCTAssertEqual(error as? PasswordHasherError, .tooShort)
        }
    }

    func testDefaultIterationsStayResponsive() throws {
        let started = Date()
        let record = try PasswordHasher.makeRecord(password: "parent-pin", iterations: PasswordHasher.defaultIterations)
        XCTAssertTrue(PasswordHasher.verify(password: "parent-pin", record: record))
        XCTAssertLessThan(Date().timeIntervalSince(started), 8)
    }

    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
