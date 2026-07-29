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

  /// Encoded element stream — the source `line2` is rendered from.
  let elements: [TimedElement]

  /// Tick schedule passed to `Transmitter.start`. Driving authority for
  /// playback timing.
  let schedule: [ScheduleTick]

  /// HUD line 2 (rendered Morse + element→column map), computed once per
  /// session. `BeaconView` and its HUD are re-created on every tick, so
  /// rendering here keeps O(message-length) string building out of the
  /// per-flip path on the main queue — the queue the flash timing runs on.
  let line2: MorseRenderer.Line2

  init(message: String, elements: [TimedElement], schedule: [ScheduleTick]) {
    self.message = message
    self.elements = elements
    self.schedule = schedule
    self.line2 = MorseRenderer.renderLine2(elements)
  }
}
