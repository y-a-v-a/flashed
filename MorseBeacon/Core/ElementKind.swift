/// The five kinds of element in a transmitted Morse message.
///
/// `dit` and `dah` are channel-on; the three gap kinds are channel-off.
/// Durations are assigned separately by `TimingProfile`.
public enum ElementKind: Equatable, Hashable, Sendable {
    case dit
    case dah
    case intraGap   // between symbols within a character (1 dit-unit in PARIS)
    case charGap    // between characters within a word (3 dit-units in PARIS)
    case wordGap    // between words (7 dit-units in PARIS)

    /// Whether the emitter channel is active during this element.
    ///
    /// This is the load-bearing piece of channel-agnostic semantics (PRD §7a R1,
    /// CLAUDE.md Architecture rules): optical/haptic/audio emitters all read
    /// the same bit and interpret it in their own modality.
    public var isOn: Bool {
        switch self {
        case .dit, .dah: return true
        case .intraGap, .charGap, .wordGap: return false
        }
    }
}
