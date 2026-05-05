#if SWIFT_PACKAGE
  import Core
#endif

/// Bundle of data that defines one in-flight transmission. Constructed in
/// `InputView` once the message validates, then threaded through
/// `TransmissionContainerView` to `BeaconView` so the HUD can render
/// the source string and the rendered Morse alongside the live tick.
///
/// Pure value type with no platform dependencies. Lives in `UI/` because
/// it's a UI-layer concern (HUD rendering); the underlying `[ScheduleTick]`
/// is what `Transmitter.start` actually consumes.
struct TransmissionSession: Equatable {
  /// Normalized message text (post-`ValidatedMessage` upper-casing). Used
  /// by HUD line 1.
  let message: String

  /// Encoded element stream. Used by HUD line 2 (via `MorseRenderer`) and
  /// to provide `sourceCharIndex` lookups for the highlight.
  let elements: [TimedElement]

  /// Tick schedule passed to `Transmitter.start`. Driving authority for
  /// playback timing.
  let schedule: [ScheduleTick]
}
