import XCTest

@testable import Runtime

final class AccessibilityFlagsTests: XCTestCase {

  // MARK: - TASKS 2.3.1: Reduce-Motion clamps WPM to 10.

  func test_reduceMotionOff_allowsTwentyWPM() {
    let flags = AccessibilityFlags(isReduceMotionEnabled: false)
    XCTAssertEqual(flags.maxCharacterWPM, 20)
  }

  func test_reduceMotionOn_capsAtTenWPM() {
    let flags = AccessibilityFlags(isReduceMotionEnabled: true)
    XCTAssertEqual(flags.maxCharacterWPM, 10)
  }

  // MARK: - Value-type properties.

  func test_equality() {
    XCTAssertEqual(
      AccessibilityFlags(isReduceMotionEnabled: true),
      AccessibilityFlags(isReduceMotionEnabled: true)
    )
    XCTAssertNotEqual(
      AccessibilityFlags(isReduceMotionEnabled: true),
      AccessibilityFlags(isReduceMotionEnabled: false)
    )
  }
}
