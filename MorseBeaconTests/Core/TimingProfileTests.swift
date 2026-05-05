import XCTest

@testable import Core

final class TimingProfileTests: XCTestCase {

  // MARK: - TASKS 1.4.1: PARIS dit = 1200 / WPM ms

  func test_parisDitDuration_atTwentyWPM_is60ms() {
    let p = TimingProfile.paris(wpm: 20)
    XCTAssertEqual(p.duration(of: .dit), 60)
  }

  func test_parisDitDuration_atTenWPM_is120ms() {
    let p = TimingProfile.paris(wpm: 10)
    XCTAssertEqual(p.duration(of: .dit), 120)
  }

  func test_parisDitDuration_atFiveWPM_is240ms() {
    let p = TimingProfile.paris(wpm: 5)
    XCTAssertEqual(p.duration(of: .dit), 240)
  }

  // MARK: - TASKS 1.4.2: PARIS unit ratios

  func test_parisRatios_holdAtAllWPMs() {
    for wpm in TimingProfile.wpmRange {
      let p = TimingProfile.paris(wpm: wpm)
      let dit = p.duration(of: .dit)
      XCTAssertEqual(p.duration(of: .dah), 3 * dit, "wpm=\(wpm)")
      XCTAssertEqual(p.duration(of: .intraGap), dit, "wpm=\(wpm)")
      XCTAssertEqual(p.duration(of: .charGap), 3 * dit, "wpm=\(wpm)")
      XCTAssertEqual(p.duration(of: .wordGap), 7 * dit, "wpm=\(wpm)")
    }
  }

  // MARK: - TASKS 1.4.3: Farnsworth overall message rate

  func test_farnsworth_whenEffectiveEqualsChar_reducesToParis() {
    for wpm in TimingProfile.wpmRange {
      let paris = TimingProfile.paris(wpm: wpm)
      let farns = TimingProfile.farnsworth(charWpm: wpm, effectiveWpm: wpm)
      for kind in [ElementKind.dit, .dah, .intraGap, .charGap, .wordGap] {
        XCTAssertEqual(
          farns.duration(of: kind),
          paris.duration(of: kind),
          "Farnsworth at equal WPMs must equal PARIS (wpm=\(wpm), kind=\(kind))"
        )
      }
    }
  }

  func test_farnsworth_charElementsUseCharWPM() {
    // dit/dah/intraGap are unaffected by effectiveWpm: they always play
    // at character speed. This is the defining property of Farnsworth.
    let a = TimingProfile.farnsworth(charWpm: 20, effectiveWpm: 10)
    let b = TimingProfile.farnsworth(charWpm: 20, effectiveWpm: 5)
    XCTAssertEqual(a.duration(of: .dit), b.duration(of: .dit))
    XCTAssertEqual(a.duration(of: .dah), b.duration(of: .dah))
    XCTAssertEqual(a.duration(of: .intraGap), b.duration(of: .intraGap))
    XCTAssertEqual(a.duration(of: .dit), 60)  // from charWpm=20
  }

  func test_farnsworth_gapsStretch_soParisWordHitsEffectiveRate() {
    // "PARIS " is the canonical 50-unit word. Its total time under
    // Farnsworth must equal 60_000 / effectiveWpm, within integer
    // rounding tolerance (~few ms across 5 gaps).
    let cases: [(charWpm: Int, effWpm: Int)] = [
      (20, 20), (20, 15), (20, 10), (20, 5),
      (15, 10), (15, 5),
      (10, 10), (10, 5),
    ]
    for c in cases {
      let p = TimingProfile.farnsworth(charWpm: c.charWpm, effectiveWpm: c.effWpm)
      let parisWordTotal =
        31 * p.duration(of: .dit)  // 31 char-units
        + 4 * p.duration(of: .charGap)  // 4 charGaps between PARIS's 5 letters
        + p.duration(of: .wordGap)  // trailing space
      let expected = 60_000 / c.effWpm
      // Allow up to 20 ms slack for integer division across 5 gaps.
      XCTAssertLessThanOrEqual(
        abs(parisWordTotal - expected), 20,
        "Farnsworth PARIS total mismatch at char=\(c.charWpm) eff=\(c.effWpm): got \(parisWordTotal), expected ~\(expected)"
      )
    }
  }

  // MARK: - TASKS 1.4.4: effectiveWpm <= charWpm

  func test_makeFarnsworth_rejectsEffectiveGreaterThanChar() {
    XCTAssertNil(TimingProfile.makeFarnsworth(charWpm: 10, effectiveWpm: 15))
    XCTAssertNil(TimingProfile.makeFarnsworth(charWpm: 10, effectiveWpm: 11))
  }

  func test_makeFarnsworth_acceptsEqualAndLower() {
    XCTAssertNotNil(TimingProfile.makeFarnsworth(charWpm: 10, effectiveWpm: 10))
    XCTAssertNotNil(TimingProfile.makeFarnsworth(charWpm: 20, effectiveWpm: 5))
  }

  // MARK: - TASKS 1.4.5: WPM range 5–20 enforced

  func test_makeParis_rejectsOutOfRange() {
    XCTAssertNil(TimingProfile.makeParis(wpm: 4))
    XCTAssertNil(TimingProfile.makeParis(wpm: 21))
    XCTAssertNil(TimingProfile.makeParis(wpm: 0))
    XCTAssertNil(TimingProfile.makeParis(wpm: -5))
  }

  func test_makeParis_acceptsBoundaries() {
    XCTAssertNotNil(TimingProfile.makeParis(wpm: 5))
    XCTAssertNotNil(TimingProfile.makeParis(wpm: 20))
  }

  func test_makeFarnsworth_rejectsOutOfRangeOnEitherSide() {
    XCTAssertNil(TimingProfile.makeFarnsworth(charWpm: 4, effectiveWpm: 4))
    XCTAssertNil(TimingProfile.makeFarnsworth(charWpm: 21, effectiveWpm: 10))
    XCTAssertNil(TimingProfile.makeFarnsworth(charWpm: 10, effectiveWpm: 4))
  }
}
