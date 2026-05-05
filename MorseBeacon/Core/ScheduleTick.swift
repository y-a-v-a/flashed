/// One span of channel state in a scheduled transmission.
///
/// Per PRD §7a R1, ticks are spans, not edges. Each tick is fully
/// self-describing: the channel is `isOn` for the half-open interval
/// `[absoluteOffsetMs, absoluteOffsetMs + durationMs)`. Consumers never need
/// to look at tick N+1 to know when tick N ends, which is the property that
/// keeps optical/haptic/audio emitters independent.
///
/// Ticks are produced 1:1 with `TimedElement`s by `TransmissionSchedule.build`.
/// There is no terminal sentinel tick; the schedule simply ends after its
/// last span.
public struct ScheduleTick: Equatable, Hashable, Sendable {

  /// Start of this tick's span, in milliseconds since `t0`.
  public let absoluteOffsetMs: Int

  /// Length of this tick's span, in milliseconds. Always > 0 for valid
  /// schedules.
  public let durationMs: Int

  /// Whether the emitter channel is active during this span (dits and dahs
  /// are on; gaps are off).
  public let isOn: Bool

  /// Source character index from the originating `TimedElement`. Nil for
  /// `charGap` and `wordGap` spans.
  public let sourceCharIndex: Int?

  /// Monotonic element index from the originating `TimedElement`.
  public let elementIndexInMessage: Int

  public init(
    absoluteOffsetMs: Int,
    durationMs: Int,
    isOn: Bool,
    sourceCharIndex: Int?,
    elementIndexInMessage: Int
  ) {
    self.absoluteOffsetMs = absoluteOffsetMs
    self.durationMs = durationMs
    self.isOn = isOn
    self.sourceCharIndex = sourceCharIndex
    self.elementIndexInMessage = elementIndexInMessage
  }

  /// Exclusive end of this tick's span.
  public var endOffsetMs: Int { absoluteOffsetMs + durationMs }
}
