import XCTest

@testable import Core

final class MorseRendererTests: XCTestCase {

  private func render(_ raw: String) throws -> MorseRenderer.Line2 {
    let elements = MorseEncoder.encode(try ValidatedMessage(raw))
    return MorseRenderer.renderLine2(elements)
  }

  // MARK: - TASKS 1.6.1: rendered string for AN.

  func test_AN_rendersAsExpected() throws {
    // `·−   −·` — A's dit/dah run together, 3-space charGap, N's dah/dit
    // run together. intraGap is zero-width by convention.
    let line = try render("AN")
    XCTAssertEqual(line.string, "·−   −·")
  }

  func test_singleE_rendersAsOneDit() throws {
    XCTAssertEqual(try render("E").string, "·")
  }

  func test_SOS_rendersWithCharGaps() throws {
    // S=···, O=−−−, S=···, joined by 3-space charGaps.
    XCTAssertEqual(try render("SOS").string, "···   −−−   ···")
  }

  func test_wordGap_rendersAsSevenSpaces() throws {
    // "E E" — dit, wordGap (7 spaces), dit.
    let line = try render("E E")
    XCTAssertEqual(line.string, "·       ·")
  }

  func test_emptyMessage_rendersAsEmpty() throws {
    let line = try render("")
    XCTAssertEqual(line.string, "")
    XCTAssertTrue(line.elementIndexToColumn.isEmpty)
  }

  // MARK: - TASKS 1.6.2: element-index → column mapping.

  func test_columnMap_forAN() throws {
    let line = try render("AN")
    // Elements: dit(0), intraGap(1), dah(2), charGap(3), dah(4), intraGap(5), dit(6)
    // String:   ·       −           (3 spaces)  −       ·
    // Columns:  0        1 (next) 1                2 (first space of gap)   5       6 (next) 6
    XCTAssertEqual(line.elementIndexToColumn[0], 0)  // dit at col 0
    XCTAssertEqual(line.elementIndexToColumn[1], 1)  // intraGap (zero-width) at col 1
    XCTAssertEqual(line.elementIndexToColumn[2], 1)  // dah at col 1
    XCTAssertEqual(line.elementIndexToColumn[3], 2)  // charGap at col 2
    XCTAssertEqual(line.elementIndexToColumn[4], 5)  // dah at col 5
    XCTAssertEqual(line.elementIndexToColumn[5], 6)  // intraGap at col 6
    XCTAssertEqual(line.elementIndexToColumn[6], 6)  // dit at col 6
  }

  func test_columnMap_coversEveryElement() throws {
    let raw = "HELLO WORLD"
    let elements = MorseEncoder.encode(try ValidatedMessage(raw))
    let line = MorseRenderer.renderLine2(elements)
    for e in elements {
      XCTAssertNotNil(
        line.elementIndexToColumn[e.elementIndexInMessage],
        "missing column for element \(e.elementIndexInMessage)"
      )
    }
  }

  func test_columnMap_valuesAreWithinStringBounds() throws {
    let line = try render("SOS PARIS")
    let length = line.string.count
    for (_, col) in line.elementIndexToColumn {
      XCTAssertGreaterThanOrEqual(col, 0)
      XCTAssertLessThanOrEqual(col, length, "column out of bounds")
    }
  }

  // MARK: - Structural invariants.

  func test_stringLength_equalsExpectedWidth() throws {
    // Width formula: sum over elements of (1 if dit/dah else 0 if intraGap else 3 if charGap else 7).
    let raw = "HI 73"
    let elements = MorseEncoder.encode(try ValidatedMessage(raw))
    let expectedWidth = elements.reduce(0) { acc, e in
      switch e.kind {
      case .dit, .dah: return acc + 1
      case .intraGap: return acc
      case .charGap: return acc + 3
      case .wordGap: return acc + 7
      }
    }
    let line = MorseRenderer.renderLine2(elements)
    XCTAssertEqual(line.string.count, expectedWidth)
  }

  func test_usesCorrectDitAndDahGlyphs() throws {
    // dit = U+00B7 MIDDLE DOT, dah = U+2212 MINUS SIGN. Not period, not hyphen.
    let line = try render("A")
    XCTAssertEqual(line.string, "\u{00B7}\u{2212}")
  }
}
