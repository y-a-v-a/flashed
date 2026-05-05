/// Turns a `ValidatedMessage` into a flat stream of `TimedElement`s.
///
/// The function is total by construction (PRD §7a R2): every input is a
/// `ValidatedMessage`, and `ValidatedMessage` guarantees each character is
/// either a space or present in `MorseTable`.
///
/// Separator rules:
/// - Between symbols within a character: `intraGap`.
/// - Between two non-space characters: `charGap`.
/// - A space character emits a single `wordGap`; multiple consecutive spaces
///   emit multiple `wordGap`s.
/// - No trailing separator after the last element. A trailing space in the
///   source message *does* contribute a final `wordGap` — this is the AC-4
///   "PARIS " invariant.
public enum MorseEncoder {

  public static func encode(_ message: ValidatedMessage) -> [TimedElement] {
    let chars = message.characters
    var out: [TimedElement] = []
    var idx = 0

    for i in 0..<chars.count {
      let c = chars[i]

      if c == " " {
        out.append(TimedElement(kind: .wordGap, sourceCharIndex: nil, elementIndexInMessage: idx))
        idx += 1
        continue
      }

      guard let symbols = MorseTable.symbols(for: c) else {
        // Unreachable: ValidatedMessage guarantees supports(c) == true,
        // and the only supported character without symbols is space
        // (handled above). Guard anyway to avoid force-unwrapping.
        preconditionFailure(
          "ValidatedMessage invariant violated: '\(c)' supported but has no symbols")
      }

      for (j, symbol) in symbols.enumerated() {
        let kind: ElementKind = (symbol == .dit) ? .dit : .dah
        out.append(TimedElement(kind: kind, sourceCharIndex: i, elementIndexInMessage: idx))
        idx += 1

        if j < symbols.count - 1 {
          out.append(TimedElement(kind: .intraGap, sourceCharIndex: i, elementIndexInMessage: idx))
          idx += 1
        }
      }

      // Separator to the next character: charGap if it's another letter,
      // nothing if it's a space (the space emits its own wordGap next
      // iteration), nothing if we're at the end of the message.
      if i + 1 < chars.count, chars[i + 1] != " " {
        out.append(TimedElement(kind: .charGap, sourceCharIndex: nil, elementIndexInMessage: idx))
        idx += 1
      }
    }

    return out
  }
}
