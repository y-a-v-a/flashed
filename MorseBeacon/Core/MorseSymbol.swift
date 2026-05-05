/// A single Morse code symbol: the dit (short) or the dah (long).
///
/// Durations are intentionally not attached here. Symbol sequences are the
/// pure combinatorial form of a character's Morse representation; timing is
/// applied later by `TimingProfile` and `TransmissionSchedule`.
public enum MorseSymbol: Equatable, Hashable, Sendable {
  case dit
  case dah
}
