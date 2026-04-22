import XCTest
@testable import Core

final class ValidatedMessageTests: XCTestCase {

    // MARK: - Happy path

    func test_emptyString_isValid() throws {
        let m = try ValidatedMessage("")
        XCTAssertTrue(m.isEmpty)
        XCTAssertEqual(m.characters, [])
    }

    func test_validMessage_roundTripsAsString() throws {
        let m = try ValidatedMessage("HELLO")
        XCTAssertEqual(m.asString, "HELLO")
    }

    func test_lowercase_normalizedToUppercase() throws {
        let m = try ValidatedMessage("hello")
        XCTAssertEqual(m.asString, "HELLO")
    }

    func test_mixedCase_normalizedToUppercase() throws {
        let m = try ValidatedMessage("Hello World")
        XCTAssertEqual(m.asString, "HELLO WORLD")
    }

    func test_spaceAndPunctuationPreserved() throws {
        let m = try ValidatedMessage("SOS, 911!")
        XCTAssertEqual(m.asString, "SOS, 911!")
    }

    // MARK: - Rejection

    func test_unsupportedCharacter_throwsWithCorrectIndex() {
        XCTAssertThrowsError(try ValidatedMessage("HELL#O")) { error in
            guard case let ValidatedMessage.ValidationError.unsupportedCharacter(c, at: i) = error else {
                return XCTFail("expected .unsupportedCharacter, got \(error)")
            }
            XCTAssertEqual(c, "#")
            XCTAssertEqual(i, 4)
        }
    }

    func test_firstUnsupportedCharacterReported_whenMultiplePresent() {
        XCTAssertThrowsError(try ValidatedMessage("A#B%")) { error in
            guard case let ValidatedMessage.ValidationError.unsupportedCharacter(c, at: i) = error else {
                return XCTFail("expected .unsupportedCharacter, got \(error)")
            }
            XCTAssertEqual(c, "#")
            XCTAssertEqual(i, 1)
        }
    }

    func test_nonAsciiRejected() {
        XCTAssertThrowsError(try ValidatedMessage("HELLO é")) { error in
            guard case let ValidatedMessage.ValidationError.unsupportedCharacter(c, _) = error else {
                return XCTFail("expected .unsupportedCharacter, got \(error)")
            }
            XCTAssertEqual(c, "é")
        }
    }

    // MARK: - Length cap (FR-3)

    func test_exactly160Chars_accepted() throws {
        let exact = String(repeating: "A", count: 160)
        let m = try ValidatedMessage(exact)
        XCTAssertEqual(m.characters.count, 160)
    }

    func test_overMaxLength_throws() {
        let long = String(repeating: "A", count: 161)
        XCTAssertThrowsError(try ValidatedMessage(long)) { error in
            guard case let ValidatedMessage.ValidationError.tooLong(count, max) = error else {
                return XCTFail("expected .tooLong, got \(error)")
            }
            XCTAssertEqual(count, 161)
            XCTAssertEqual(max, 160)
        }
    }

    func test_lengthCheckedBeforeCharacterValidation() {
        // If both the length cap AND an unsupported character are violated,
        // the length error wins. This is implementation-defined behavior but
        // worth pinning down so the UI layer can rely on it.
        let long = String(repeating: "#", count: 161)
        XCTAssertThrowsError(try ValidatedMessage(long)) { error in
            guard case .tooLong = error as? ValidatedMessage.ValidationError else {
                return XCTFail("expected .tooLong to win over .unsupportedCharacter, got \(error)")
            }
        }
    }
}
