/// How long each `ElementKind` lasts, in integer milliseconds.
///
/// Two models:
/// - **PARIS**: the standard 1-WPM = "PARIS " per minute definition. dit is
///   `1200 / wpm` ms; dah = 3×dit; intraGap = 1×dit; charGap = 3×dit;
///   wordGap = 7×dit. Total for "PARIS " = 50 dit-units.
/// - **Farnsworth**: dit/dah play at the *character* WPM while charGap and
///   wordGap are stretched so the overall message rate matches `effectiveWpm`
///   (Bloom 1990). When `effectiveWpm == charWpm`, Farnsworth reduces exactly
///   to PARIS at that WPM.
///
/// Validated construction goes through `makeParis(wpm:)` and
/// `makeFarnsworth(charWpm:effectiveWpm:)`. Direct enum-case construction
/// bypasses validation and is intended only for trusted internal use and
/// tests.
public enum TimingProfile: Equatable, Hashable, Sendable {
  case paris(wpm: Int)
  case farnsworth(charWpm: Int, effectiveWpm: Int)

  /// Allowed WPM range for both variants (PRD FR-8).
  public static let wpmRange: ClosedRange<Int> = 5...20

  /// Validated PARIS factory. Returns nil for out-of-range `wpm`.
  public static func makeParis(wpm: Int) -> TimingProfile? {
    guard wpmRange.contains(wpm) else { return nil }
    return .paris(wpm: wpm)
  }

  /// Validated Farnsworth factory. Returns nil if either WPM is out of
  /// range or if `effectiveWpm > charWpm`.
  public static func makeFarnsworth(charWpm: Int, effectiveWpm: Int) -> TimingProfile? {
    guard wpmRange.contains(charWpm),
      wpmRange.contains(effectiveWpm),
      effectiveWpm <= charWpm
    else { return nil }
    return .farnsworth(charWpm: charWpm, effectiveWpm: effectiveWpm)
  }

  /// Duration of a single element in milliseconds.
  public func duration(of element: ElementKind) -> Int {
    switch self {
    case .paris(let wpm):
      let dit = 1200 / wpm
      switch element {
      case .dit, .intraGap: return dit
      case .dah, .charGap: return 3 * dit
      case .wordGap: return 7 * dit
      }

    case .farnsworth(let charWpm, let effectiveWpm):
      let charDit = 1200 / charWpm
      switch element {
      case .dit, .intraGap: return charDit
      case .dah: return 3 * charDit
      case .charGap, .wordGap:
        let multiplier = (element == .charGap) ? 3 : 7

        // At equal WPMs, Farnsworth reduces to PARIS by definition.
        // Short-circuit so we match PARIS's `n * (1200/w)` rounding
        // exactly — otherwise the separate integer divisions in the
        // Bloom formula below diverge by 1–4 ms at WPMs where 1200/w
        // doesn't divide cleanly (7, 9, 13, 14, 17, 18, 19).
        if effectiveWpm == charWpm {
          return multiplier * charDit
        }

        // Bloom's Farnsworth formula, integer-ized.
        //
        // A "PARIS " word has 31 char-units + 19 gap-units = 50 units
        // at PARIS. In Farnsworth, the 31 char-units play at charWpm
        // and the 19 gap-units are stretched so the whole word takes
        // `60000 / effectiveWpm` ms.
        //
        //     gapTotal     = 60000/effWpm - 31*(1200/charWpm)
        //     gapUnitMs    = gapTotal / 19
        //     charGap (ms) = 3 * gapUnitMs
        //     wordGap (ms) = 7 * gapUnitMs
        //
        // Compute `total * multiplier / 19` in that order to keep
        // integer-division error below one unit per gap.
        let totalMsPerWord = 60_000 / effectiveWpm
        let charPortion = 31 * 1200 / charWpm
        let gapTotal = totalMsPerWord - charPortion
        return gapTotal * multiplier / 19
      }
    }
  }
}
