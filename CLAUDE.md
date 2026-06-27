# CLAUDE.md — Morse Beacon

This file is read by Claude Code at session start. Keep it tight.

## Project

iOS app (Swift / SwiftUI, iOS 17+). Transmit-only optical Morse code beacon.
User types a message → 5s countdown → screen flashes Morse at full brightness
with a non-flashing HUD strip at top showing the source text and Morse with
a moving highlight.

See `PRD.md` for full requirements. This file is for working style, not scope.

## Working agreement

- **Spec before code.** Anything larger than a single function gets a short
  plan first. No speculative refactors.
- **Core is pure.** `Core/` must not import UIKit, SwiftUI, Foundation's
  `Timer`, or anything platform-bound. Duration is `Int` milliseconds, not
  `TimeInterval`. This keeps it trivially unit-testable and portable.
- **Tests first for `Core/`.** Encoder and schedule generator are
  deterministic; write the test for each new behavior before the
  implementation.
- **Timing is the load-bearing detail.** Treat the PARIS definition (the
  word "PARIS " = 50 dit-units) as a test invariant. Any change to timing
  code must still satisfy AC-4.
- **No third-party dependencies.** SwiftPM allowed for test-only helpers
  if truly needed; production code is Apple frameworks only.
- **No telemetry, no network, no accounts.** Not now, not later. If a
  solution seems to require any of these, stop and ask.

## Code style

- Swift 5.9+, `swift-format` default config.
- `struct` over `class` wherever possible. `class` only for
  `ObservableObject` and where reference semantics are genuinely needed.
- Prefer `enum` with associated values over flag structs.
- No force unwraps outside of tests. No `try!` in production code.
- Comments are sparse: explain *why*, never *what*. If the code needs a
  comment to explain what it does, rename something.
- File-private types and helpers stay file-private.

## Architecture rules

- `Core/` → `Runtime/` → `UI/`. Dependencies only point inward.
  `Core/` knows about nothing else. `Runtime/` imports `Core/` and Apple
  frameworks. `UI/` imports both.
- `Transmitter` is the single source of truth for playback state. Views
  observe it; they do not schedule their own timers.
- Brightness and idle-timer manipulation lives only in `ScreenController`.
  No other file touches `UIScreen` or `UIApplication.isIdleTimerDisabled`.
- **Channel-agnostic schedule.** `Transmitter` publishes a tick stream
  (`ScheduleTick`) that does not know about optical output. The optical
  flash is one *emitter* subscribing to that stream. Haptic (Phase 2) and
  audio (Phase 3) will be additional emitters. Do not bake `isOn` into the
  `Transmitter`'s public API as if it only means "screen white"; treat it
  as "channel active during this tick" and let each emitter interpret it.
  This is a free design decision in v1 and an expensive rewrite in v2.

## What to run

- Build: `./scripts/build-ios.sh` — wraps `xcodebuild build` with a
  `generic/platform=iOS Simulator` destination, so it needs no specific device.
- Test (app): `./scripts/test-ios.sh` — auto-detects an installed iPhone
  simulator. Raw form: `xcodebuild -scheme MorseBeacon -destination
  'platform=iOS Simulator,name=iPhone 17' test`; substitute any device from
  `xcrun simctl list devices available` (don't hard-code a device that may not
  be installed on the current Xcode).
- Core/Runtime tests (fast loop): `swift test` runs the SwiftPM overlay at the
  repo root (no Xcode project needed). Extract `Core/` to `Core-Package/` only
  if turnaround exceeds 10s (TASKS 0.7).

## Definition of done for a task

1. New/changed behavior has a test in `Tests/`.
2. `xcodebuild test` passes.
3. No new warnings.
4. PRD acceptance criteria still pass (re-verify the relevant ones).
5. If a PRD assumption turned out wrong, update `PRD.md` in the same change.

## Things to ask before doing

- Adding any file outside the four directories in the architecture sketch.
- Adding a dependency of any kind.
- Changing the public shape of `Core/` types after initial implementation.
- Anything touching the safety warning flow or photosensitivity caps.

## Known constraints and gotchas

- `UIScreen.main.brightness` can be overridden by the system (low-power mode,
  thermal throttling). Test on device, not only simulator.
- Auto-Brightness in Settings may fight our brightness set; we cannot
  disable it programmatically. Document this in the app's first-run notes.
- `DispatchSourceTimer` with `.strict` flag + absolute deadlines gives
  best timing. Avoid `Timer.scheduledTimer` — it's RunLoop-bound and drifts
  under UI load.
- Orientation lock in SwiftUI requires a UIKit bridge
  (`UIViewControllerRepresentable` + overriding
  `supportedInterfaceOrientations`). Plan for this in `BeaconView`.
- True Tone and Night Shift will warm the white point. We cannot disable
  them. Accept and document.

## Reference

- ITU-R M.1677-1 (International Morse Code timing spec).
- PARIS timing: dit = 1200 / WPM milliseconds.
- Farnsworth method: Jon Bloom, "The Farnsworth Method" (ARRL, 1990).
