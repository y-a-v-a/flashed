import Core

/// The five lifecycle states of a transmission. Published by `Transmitter`.
///
/// Allowed transitions:
///   idle      → countdown    (start with countdown > 0)
///   idle      → transmitting (start with countdown == 0 and a non-empty schedule)
///   idle      → finished     (start with countdown == 0 and an empty schedule)
///   countdown → countdown    (tick down)
///   countdown → transmitting (countdown elapsed, schedule begins)
///   countdown → finished     (countdown elapsed, empty schedule)
///   countdown → aborted      (user tapped cancel)
///   transmitting → transmitting (next tick fires)
///   transmitting → finished  (last tick elapsed)
///   transmitting → aborted   (user tapped cancel; backgrounding)
///   finished  → countdown    (start again — "Transmit again" flow)
///   aborted   → countdown    (start again after a cancel)
///
/// Terminal in the sense "no further callbacks fire": `finished` and
/// `aborted` both cause the Transmitter to drop its scheduled subscriptions.
public enum TransmitterState: Equatable, Sendable {
    case idle
    case countdown(secondsLeft: Int)
    case transmitting(currentTick: ScheduleTick)
    case finished
    case aborted
}
