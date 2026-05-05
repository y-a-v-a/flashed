import XCTest

@testable import Core

final class MorseTableTests: XCTestCase {

  // MARK: - TASKS 1.1.1: FR-1 accepted set supported; everything else rejected.

  func test_supports_allUppercaseLetters() {
    for scalar in UnicodeScalar("A").value...UnicodeScalar("Z").value {
      let c = Character(UnicodeScalar(scalar)!)
      XCTAssertTrue(MorseTable.supports(c), "expected \(c) to be supported")
    }
  }

  func test_supports_allLowercaseLetters_viaCaseInsensitivity() {
    for scalar in UnicodeScalar("a").value...UnicodeScalar("z").value {
      let c = Character(UnicodeScalar(scalar)!)
      XCTAssertTrue(MorseTable.supports(c), "expected \(c) to be supported")
    }
  }

  func test_supports_allDigits() {
    for scalar in UnicodeScalar("0").value...UnicodeScalar("9").value {
      let c = Character(UnicodeScalar(scalar)!)
      XCTAssertTrue(MorseTable.supports(c), "expected \(c) to be supported")
    }
  }

  func test_supports_space() {
    XCTAssertTrue(MorseTable.supports(" "))
  }

  func test_supports_allPunctuationInFR1() {
    // PRD FR-1 exact set. Order preserved for diff readability.
    let punctuation: [Character] = [
      ".", ",", "?", "'", "!", "/", "(", ")", "&", ":",
      ";", "=", "+", "-", "_", "\"", "$", "@",
    ]
    for c in punctuation {
      XCTAssertTrue(MorseTable.supports(c), "FR-1 requires \(c) to be supported")
    }
  }

  func test_supports_rejectsDisallowedAscii() {
    // Characters explicitly not in FR-1. A few representative picks.
    let rejected: [Character] = [
      "#", "%", "*", "<", ">", "[", "]", "{", "}", "\\", "`", "|", "^", "~",
    ]
    for c in rejected {
      XCTAssertFalse(MorseTable.supports(c), "\(c) must not be supported")
    }
  }

  func test_supports_rejectsNonAscii() {
    let rejected: [Character] = ["é", "ñ", "世", "界", "🚀", "ß"]
    for c in rejected {
      XCTAssertFalse(MorseTable.supports(c), "non-ASCII \(c) must not be supported")
    }
  }

  // MARK: - TASKS 1.1.2: spot-check canonical encodings.

  func test_symbols_A() {
    XCTAssertEqual(MorseTable.symbols(for: "A"), [.dit, .dah])
  }

  func test_symbols_N() {
    XCTAssertEqual(MorseTable.symbols(for: "N"), [.dah, .dit])
  }

  func test_symbols_S_O_S() {
    XCTAssertEqual(MorseTable.symbols(for: "S"), [.dit, .dit, .dit])
    XCTAssertEqual(MorseTable.symbols(for: "O"), [.dah, .dah, .dah])
  }

  func test_symbols_questionMark() {
    // Per ITU: ··−−··
    XCTAssertEqual(MorseTable.symbols(for: "?"), [.dit, .dit, .dah, .dah, .dit, .dit])
  }

  func test_symbols_isCaseInsensitive() {
    XCTAssertEqual(MorseTable.symbols(for: "a"), MorseTable.symbols(for: "A"))
    XCTAssertEqual(MorseTable.symbols(for: "z"), MorseTable.symbols(for: "Z"))
  }

  // MARK: - TASKS 1.1.3: structural invariants.

  func test_symbols_returnsNilForSpace() {
    // Space is a valid message character but has no dit/dah sequence —
    // the encoder treats it as a wordGap. This distinction is load-bearing
    // for the encoder's logic, so it's asserted explicitly.
    XCTAssertNil(MorseTable.symbols(for: " "))
    XCTAssertTrue(MorseTable.supports(" "))
  }

  func test_symbols_returnsNilForUnsupported() {
    XCTAssertNil(MorseTable.symbols(for: "#"))
    XCTAssertNil(MorseTable.symbols(for: "é"))
  }

  func test_everySupportedNonSpaceCharacterHasSymbols() {
    // Consistency: if supports() says yes (and it's not space), symbols()
    // must return non-nil and non-empty. This catches accidental
    // desynchronization between the two APIs in future edits.
    let candidates: [Character] = {
      var out: [Character] = [" "]
      for s in UnicodeScalar("A").value...UnicodeScalar("Z").value {
        out.append(Character(UnicodeScalar(s)!))
      }
      for s in UnicodeScalar("0").value...UnicodeScalar("9").value {
        out.append(Character(UnicodeScalar(s)!))
      }
      out += [
        ".", ",", "?", "'", "!", "/", "(", ")", "&", ":", ";", "=", "+", "-", "_", "\"", "$", "@",
      ]
      return out
    }()
    for c in candidates where c != " " {
      XCTAssertTrue(MorseTable.supports(c))
      let symbols = MorseTable.symbols(for: c)
      XCTAssertNotNil(symbols, "\(c) supports() returned true but symbols() returned nil")
      XCTAssertFalse(symbols!.isEmpty, "\(c) has empty symbol sequence")
    }
  }
}
