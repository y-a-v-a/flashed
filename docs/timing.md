# Timing

This document covers the maths behind Morse timing in this app, the two
timing models we support, why the `Core/` test suite asserts a specific
millisecond count for `"PARIS "`, and the procedure for measuring
end-to-end timing jitter on a real device (FR-12).

## 1. The two definitions of "1 word per minute"

There is no single agreed-on definition of WPM in Morse code. We support
both standard ones.

### PARIS

The traditional convention: 1 WPM = the word "`PARIS `" (with a trailing
space) sent once per minute. PARIS was chosen because at standard ratios
it works out to exactly **50 dit-units**:

| Element | Units |
|---------|------:|
| dit                 | 1 |
| dah                 | 3 |
| intra-character gap | 1 |
| inter-character gap | 3 |
| inter-word gap      | 7 |

Tallying the dit-units in `"PARIS "`:

```
P = ·−−·       1+1+3+1+3+1+1                    = 11
A = ·−          1+1+3                            =  5
R = ·−·         1+1+3+1+1                        =  7
I = ··          1+1+1                            =  3
S = ···         1+1+1+1+1                        =  5
inter-character gaps × 4                         = 12   (between P-A, A-R, R-I, I-S)
inter-word gap × 1                               =  7   (the trailing space)
                                                  ----
Total                                             = 50
```

So `dit_ms = 1200 / WPM` follows from "50 units per word, 60 seconds per
minute, WPM words per minute":

```
50 units × WPM words/min = total units/min
60_000 ms / (50 × WPM)   = ms per unit
                         = 1200 / WPM
```

At 20 WPM, dit = 60 ms. At 10 WPM, dit = 120 ms.

`Core/TimingProfile.swift` implements this as:

```swift
case .paris(let wpm):
  let dit = 1200 / wpm
  // dah = 3 × dit, charGap = 3 × dit, wordGap = 7 × dit, etc.
```

### Farnsworth

Bloom's Farnsworth method (ARRL, 1990) is a learning aid: dits and dahs
play at a fast **character WPM**, but the gaps between characters and
words are stretched so the **effective WPM** of the overall message is
slower. The user hears crisp, full-speed characters that don't slur, but
has more thinking time between them.

Setup: character WPM `c` and effective WPM `e ≤ c`.

- dit = `1200 / c` ms (same as PARIS at WPM `c`)
- dah = `3 × dit`
- intra-character gap = `1 × dit`
- inter-character and inter-word gaps are computed so that one PARIS
  word takes `60_000 / e` ms total.

A PARIS word has 31 character-units (`dit/dah/intraGap`) and 19 gap-units
(`charGap × 4 + wordGap × 1 = 12 + 7`):

```
60_000/e   = 31 × (1200/c)    +    19 × gapUnit_ms
gapUnit_ms = (60_000/e − 31 × 1200/c) / 19
charGap_ms = 3 × gapUnit_ms
wordGap_ms = 7 × gapUnit_ms
```

When `e == c`, this reduces algebraically to PARIS. In our integer-math
implementation, the per-unit rounding diverges by 1–4 ms at WPMs where
`1200/w` doesn't divide cleanly (7, 9, 13, 14, 17, 18, 19), so we
**short-circuit the equal case** to fall back to the PARIS path:

```swift
case .farnsworth(let charWpm, let effectiveWpm):
  // ...
  case .charGap, .wordGap:
    let multiplier = (element == .charGap) ? 3 : 7
    if effectiveWpm == charWpm {
      return multiplier * charDit       // PARIS-equivalent path
    }
    let totalMsPerWord = 60_000 / effectiveWpm
    let charPortion = 31 * 1200 / charWpm
    let gapTotal = totalMsPerWord - charPortion
    return gapTotal * multiplier / 19
```

This is a deliberate trade-off: matching PARIS exactly at the boundary
is more important than perfectly-accurate Farnsworth gap timing
(integer rounding loses at most ~few ms across a whole word).

## 2. The 50-unit invariant (AC-4)

The single test that pins all of the above down:

```swift
// MorseBeaconTests/Core/TransmissionScheduleTests.swift
func test_parisInvariantIs50Units() throws {
  let ticks = try schedule("PARIS ", .paris(wpm: 20))
  XCTAssertEqual(TransmissionSchedule.totalDurationMs(ticks), 3000)
}
```

3000 ms = 50 units × 60 ms/unit at 20 WPM. If anyone ever changes the
encoder, the table, the timing profile, or the schedule builder in a way
that alters the unit count, this test fails. AC-4 is therefore a
load-bearing arithmetic check that ripples through every piece of
`Core/`.

The `test_parisInvariant_scalesWithWPM` test asserts the same property
at 5 / 10 / 15 / 20 WPM, where `1200/WPM` divides cleanly.

## 3. FR-12 jitter

Spec: "Target jitter: < 10 ms per flip on recent hardware."

The implementation uses `DispatchSourceTimer` with the `.strict` flag,
each timer scheduled at an **absolute deadline** anchored to a single
`DispatchTime` reference captured at clock construction:

```swift
// Runtime/Clock.swift
public final class DispatchClock: Clock {
  private let referenceTime: DispatchTime  // captured once

  public func schedule(at targetMs: Int, _ work: @escaping () -> Void) -> ClockSubscription {
    let timer = DispatchSource.makeTimerSource(flags: [.strict], queue: queue)
    let deadline = referenceTime + .milliseconds(targetMs)
    timer.schedule(deadline: deadline, leeway: .nanoseconds(0))
    // ...
  }
}
```

`Transmitter.start` then schedules **one timer per tick** at
`txStart + tick.absoluteOffsetMs`:

```swift
// Runtime/Transmitter.swift
for tick in schedule {
  let target = txStart + tick.absoluteOffsetMs
  let sub = clock.schedule(at: target) { [weak self] in
    self?.applyIfCurrent(generation: gen) {
      $0.state = .transmitting(currentTick: tick)
    }
  }
  subscriptions.append(sub)
}
```

This avoids cumulative drift: no "sleep N ms then advance, sleep N more
ms then advance" loop where each sleep contributes its own error. Every
tick's deadline is computed from `referenceTime` independently; they
fire on their own absolute clocks.

### On-device measurement procedure (TASKS 2.2.10)

This is **not yet executed**; documented here so it can be when a real
device is available.

1. Build a Release configuration onto a physical iPhone (12 or newer).
2. Add temporary instrumentation around the `applyIfCurrent` block:

   ```swift
   let now = DispatchTime.now().uptimeNanoseconds
   let expectedNs = UInt64(target) * 1_000_000  // ms → ns
   let deltaNs = Int64(now) - Int64(expectedNs)
   logger.log("tick \(tick.elementIndexInMessage) Δ=\(deltaNs / 1000)µs")
   ```

3. Transmit `"PARIS PARIS PARIS PARIS PARIS"` at 20 WPM (1500 ticks-ish).
4. Collect deltas via `os_log` / Console.app.
5. Assert: 99th-percentile |Δ| < 10 ms; max |Δ| < 25 ms.
6. Repeat under load: scrolling another app, with low-power mode, on a
   warm device, etc.

Failures here would point at:
- DispatchSource leeway not honoured under thermal throttling
- Main-queue contention from SwiftUI redraw cost
- The `.strict` flag not being respected

If the simple per-tick scheduling can't hit < 10 ms reliably, the
fallback is a CADisplayLink-driven scheduler that ticks every frame and
checks "which tick(s) have we crossed since last frame". That's a 60Hz
sampling rate, so worst-case error is one frame (~16 ms) — close to the
target but on the wrong side of it. Better to make absolute-deadline
DispatchSourceTimer work first.

## 4. Things this app does NOT do

- **Sub-millisecond timing.** All durations are integer milliseconds
  (`Int`, not `TimeInterval`). PRD CLAUDE.md rule. Worst-case rounding
  error is a few ms across a long message — well within the < 10 ms
  per-flip target.
- **Drift correction.** No attempt to "catch up" if a tick fires late.
  The next tick's deadline is independent of the previous one; lateness
  doesn't compound.
- **Resync against an NTP source.** Out of scope for v1. The internal
  monotonic clock is good enough for line-of-sight signaling.
