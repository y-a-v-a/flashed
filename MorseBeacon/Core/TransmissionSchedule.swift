/// Turns an element stream + timing profile into a list of `ScheduleTick`
/// spans.
///
/// The output is 1:1 with the input: one tick per element, in order. Each
/// tick's `absoluteOffsetMs` is the cumulative sum of prior durations, and
/// its `durationMs` comes from `profile.duration(of: element.kind)`. There
/// is no terminal sentinel tick (PRD §7a R1).
public enum TransmissionSchedule {

  /// Build a schedule from encoded elements and a timing profile.
  public static func build(
    elements: [TimedElement],
    profile: TimingProfile
  ) -> [ScheduleTick] {
    var ticks: [ScheduleTick] = []
    ticks.reserveCapacity(elements.count)

    var offset = 0
    for element in elements {
      let duration = profile.duration(of: element.kind)
      ticks.append(
        ScheduleTick(
          absoluteOffsetMs: offset,
          durationMs: duration,
          isOn: element.kind.isOn,
          sourceCharIndex: element.sourceCharIndex,
          elementIndexInMessage: element.elementIndexInMessage
        ))
      offset += duration
    }

    return ticks
  }

  /// Total transmission duration in milliseconds: `last.offset + last.duration`,
  /// or 0 for an empty schedule.
  public static func totalDurationMs(_ ticks: [ScheduleTick]) -> Int {
    guard let last = ticks.last else { return 0 }
    return last.endOffsetMs
  }
}
