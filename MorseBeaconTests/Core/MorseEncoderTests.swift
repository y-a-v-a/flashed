import XCTest

@testable import Core

final class MorseEncoderTests: XCTestCase {

  private func encode(_ raw: String) throws -> [TimedElement] {
    MorseEncoder.encode(try ValidatedMessage(raw))
  }

  // MARK: - TASKS 1.3.1: empty message → empty elements

  func test_emptyMessage_producesEmptyStream() throws {
    XCTAssertEqual(try encode(""), [])
  }

  // MARK: - TASKS 1.3.2: single letter, no trailing gap

  func test_singleE_producesOneDit_noTrailingGap() throws {
    let elements = try encode("E")
    XCTAssertEqual(elements.count, 1)
    XCTAssertEqual(elements[0].kind, .dit)
    XCTAssertEqual(elements[0].sourceCharIndex, 0)
    XCTAssertEqual(elements[0].elementIndexInMessage, 0)
  }

  // MARK: - TASKS 1.3.3: two letters separated by charGap

  func test_EE_producesDit_charGap_Dit() throws {
    let elements = try encode("EE")
    XCTAssertEqual(elements.map(\.kind), [.dit, .charGap, .dit])
    XCTAssertEqual(elements.map(\.sourceCharIndex), [0, nil, 1])
  }

  // MARK: - TASKS 1.3.4: words separated by wordGap

  func test_E_space_E_producesDit_wordGap_Dit() throws {
    let elements = try encode("E E")
    XCTAssertEqual(elements.map(\.kind), [.dit, .wordGap, .dit])
    XCTAssertEqual(elements.map(\.sourceCharIndex), [0, nil, 2])
  }

  // MARK: - TASKS 1.3.5: AN — full structure with intraGap + charGap

  func test_AN_producesFullStructure() throws {
    let elements = try encode("AN")
    XCTAssertEqual(
      elements.map(\.kind),
      [.dit, .intraGap, .dah, .charGap, .dah, .intraGap, .dit]
    )
    XCTAssertEqual(
      elements.map(\.sourceCharIndex),
      [0, 0, 0, nil, 1, 1, 1]
    )
  }

  // MARK: - TASKS 1.3.6: case insensitivity

  func test_lowercaseProducesSameOutputAsUppercase() throws {
    XCTAssertEqual(try encode("an"), try encode("AN"))
    XCTAssertEqual(try encode("hello world"), try encode("HELLO WORLD"))
  }

  // MARK: - TASKS 1.3.9: sourceCharIndex nullability rules

  func test_sourceCharIndex_nilOnlyForCharGapAndWordGap() throws {
    let elements = try encode("AB CD")
    for e in elements {
      switch e.kind {
      case .dit, .dah, .intraGap:
        XCTAssertNotNil(e.sourceCharIndex, "\(e.kind) must carry sourceCharIndex")
      case .charGap, .wordGap:
        XCTAssertNil(e.sourceCharIndex, "\(e.kind) must not carry sourceCharIndex")
      }
    }
  }

  // MARK: - TASKS 1.3.10: elementIndexInMessage monotonic from 0

  func test_elementIndexInMessage_monotonicFromZero() throws {
    let elements = try encode("HELLO WORLD")
    XCTAssertEqual(elements.first?.elementIndexInMessage, 0)
    for i in 1..<elements.count {
      XCTAssertEqual(
        elements[i].elementIndexInMessage,
        elements[i - 1].elementIndexInMessage + 1,
        "element index must increase by exactly 1 at position \(i)"
      )
    }
  }

  // MARK: - Edge cases that bit us while writing the algorithm

  func test_noTrailingSeparatorAfterLastLetter() throws {
    let e = try encode("SOS")
    XCTAssertFalse(e.last?.kind == .charGap)
    XCTAssertFalse(e.last?.kind == .wordGap)
    XCTAssertFalse(e.last?.kind == .intraGap)
  }

  func test_trailingSpace_producesTrailingWordGap() throws {
    // Load-bearing for AC-4: "PARIS " requires its trailing wordGap.
    let e = try encode("E ")
    XCTAssertEqual(e.map(\.kind), [.dit, .wordGap])
  }

  func test_consecutiveSpaces_produceMultipleWordGaps() throws {
    let e = try encode("E  E")
    XCTAssertEqual(e.map(\.kind), [.dit, .wordGap, .wordGap, .dit])
  }

  func test_noCharGapBetweenLetterAndSpace() throws {
    // The letter before a space must NOT emit a charGap — the space's
    // own wordGap is the only separator.
    let e = try encode("AB C")
    let kinds = e.map(\.kind)
    // A B separator is charGap; B space separator is wordGap (no charGap).
    XCTAssertEqual(kinds.filter { $0 == .charGap }.count, 1)
    XCTAssertEqual(kinds.filter { $0 == .wordGap }.count, 1)
  }

  // MARK: - SOS integration (supports AC-1 at encoder layer)

  func test_SOS_encoding() throws {
    let e = try encode("SOS")
    // S = ... O = --- S = ...
    // ... charGap --- charGap ...
    // With intraGaps: ·_·_· | ___ | ·_·_·
    let expected: [ElementKind] = [
      .dit, .intraGap, .dit, .intraGap, .dit,  // S
      .charGap,
      .dah, .intraGap, .dah, .intraGap, .dah,  // O
      .charGap,
      .dit, .intraGap, .dit, .intraGap, .dit,  // S
    ]
    XCTAssertEqual(e.map(\.kind), expected)
  }
}
