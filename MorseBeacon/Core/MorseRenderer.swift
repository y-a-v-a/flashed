/// Renders the encoded element stream as the HUD Line-2 string and the
/// element-index → column mapping used by the auto-scroller (FR-14, FR-15).
///
/// Rendering rules:
/// - `dit` → `·` (U+00B7)
/// - `dah` → `−` (U+2212)
/// - `intraGap` → zero-width (the adjacent dit/dah glyphs are already visually
///   distinct; inserting a literal space here would make "A" look like two
///   separate characters)
/// - `charGap` → 3 spaces
/// - `wordGap` → 7 spaces
///
/// The zero-width treatment of `intraGap` is intentional: in the conventional
/// Morse-in-text rendering, `"AN"` becomes `"·−   −·"`, not `"· −   − ·"`.
/// Since R4 says the HUD highlight is never active during a gap tick anyway,
/// giving `intraGap` no visual footprint has no downstream cost.
public enum MorseRenderer {

  public struct Line2: Equatable, Sendable {
    /// Rendered Morse string.
    public let string: String

    /// Maps `elementIndexInMessage` → starting column in `string`.
    ///
    /// For `intraGap` elements (zero-width), the column value equals the
    /// next element's starting column. Consumers that highlight by
    /// element index should consult `ScheduleTick.isOn` (or R4's rule:
    /// no highlight during gap ticks) before using these values.
    public let elementIndexToColumn: [Int: Int]
  }

  public static func renderLine2(_ elements: [TimedElement]) -> Line2 {
    var out = ""
    // Running column count; `out.count` would re-walk the whole string
    // on every element (String.count is O(length)).
    var column = 0
    var map: [Int: Int] = [:]
    map.reserveCapacity(elements.count)

    for element in elements {
      // Column BEFORE appending this element is where the element starts.
      map[element.elementIndexInMessage] = column

      let glyphs: String
      switch element.kind {
      case .dit: glyphs = "·"
      case .dah: glyphs = "−"
      case .intraGap: glyphs = ""  // zero-width, see doc comment
      case .charGap: glyphs = "   "  // 3 spaces
      case .wordGap: glyphs = "       "  // 7 spaces
      }
      out += glyphs
      column += glyphs.count
    }

    return Line2(string: out, elementIndexToColumn: map)
  }
}
