/// One element in an encoded message: a dit, dah, or gap.
///
/// "Timed" is a slight misnomer — this type does not carry a duration. It
/// carries the information needed to *compute* a duration (via `TimingProfile`)
/// plus the provenance data (`sourceCharIndex`, `elementIndexInMessage`) needed
/// to drive the HUD highlight.
public struct TimedElement: Equatable, Hashable, Sendable {

    public let kind: ElementKind

    /// Zero-based index into the source `ValidatedMessage.characters` of the
    /// character this element belongs to.
    ///
    /// Non-nil for `dit`, `dah`, and `intraGap` (which lives inside a character).
    /// Nil for `charGap` and `wordGap` (which live between characters).
    public let sourceCharIndex: Int?

    /// Monotonic 0-based index in the encoded element stream. Used to drive
    /// HUD line-2 highlighting and to key `ScheduleTick` back to its source.
    public let elementIndexInMessage: Int

    public init(kind: ElementKind, sourceCharIndex: Int?, elementIndexInMessage: Int) {
        self.kind = kind
        self.sourceCharIndex = sourceCharIndex
        self.elementIndexInMessage = elementIndexInMessage
    }
}
