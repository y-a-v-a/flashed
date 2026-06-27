# Morse Beacon — Product Requirements Document

**Version:** 0.1 (v1 spec)
**Platform:** iOS 17+ (iPhone)
**Language:** Swift 5.9+, SwiftUI
**Status:** Draft for implementation

---

## 1. Concept

A single-purpose transmit-only optical Morse beacon. The user types a short message, confirms, and after a 5-second countdown the phone screen becomes a high-brightness flashing light source transmitting that message in International Morse code. Intended use: night-time line-of-sight signaling between people by holding up the phone in a direction.

The app does not receive, decode, or record. It is an emitter.

Inspiration: Apple Watch "Flashlight" search-light feature. Conceptually: the phone becomes a semaphore lamp.

## 2. Goals and non-goals

**Goals**
- Make it physically possible to signal Morse optically with a modern phone.
- Keep the transmission timing accurate enough that a human operator on the receiving end could decode it.
- Give the sender live feedback on what is being transmitted right now.
- Minimal UI, zero accounts, zero telemetry, zero network.

**Non-goals (v1)**
- Morse reception or decoding.
- Haptic Morse output (Phase 2 — see §10).
- Audio Morse output (Phase 3 — see §11).
- Camera-flash LED transmission.
- watchOS companion (scoped out of v1 per user decision).
- Message history, saved drafts, templates.
- Sharing or export.

## 3. User flow

1. **Input screen.** Text field, character counter, "Transmit" button. Settings gear in corner.
2. **Confirm + countdown.** Tap Transmit → 5-second countdown overlay with large numeral and "Aim your phone" caption. Tap anywhere to cancel.
3. **Beacon screen.** Orientation locks to current orientation. Top strip shows HUD at neutral brightness. Remainder of screen flashes black/white per Morse timing. Tap anywhere to abort.
4. **End of transmission.** Screen returns to neutral. Buttons: "Transmit again" (repeats same message) and "Done" (back to input, brightness restored).

## 4. Functional requirements

### 4.1 Input
- FR-1: Accept A–Z, a–z (normalized to upper-case), 0–9, space, and punctuation `. , ? ' ! / ( ) & : ; = + - _ " $ @`.
- FR-2: Reject any other character at input time with inline indication; do not allow "Transmit" until input is valid and non-empty.
- FR-3: Maximum message length: 160 characters.
- FR-4: Persist the last message across app launches (UserDefaults). No other persistence.

### 4.2 Encoding
- FR-5: Encode using ITU International Morse Code table.
- FR-6: Produce a flat stream of timed elements: `dit`, `dah`, `intraCharGap`, `charGap`, `wordGap`.
- FR-7: Element durations derived from a `TimingProfile`:
  - **PARIS** (standard): dit = 1200 / WPM ms; dah = 3× dit; intraCharGap = 1× dit; charGap = 3× dit; wordGap = 7× dit.
  - **Farnsworth**: dit/dah use character WPM; charGap and wordGap computed from effective WPM so the overall message rate matches the slower target while individual characters stay crisp.
- FR-8: WPM range: 5–20. Farnsworth effective WPM ≤ character WPM.

### 4.3 Transmission
- FR-9: Beacon screen is split: top strip (HUD) at fixed 40% white, a 4pt pure black separator, remainder (flash area) toggling between pure black and pure white.
- FR-10: During transmission:
  - `UIApplication.isIdleTimerDisabled = true`
  - `UIScreen.main.brightness` saved, then set to 1.0
  - orientation locked to whatever it was when countdown ended
- FR-11: On transmission end (natural or aborted): idle timer re-enabled, brightness restored to saved value, orientation unlocked.
- FR-12: Timing uses absolute-deadline scheduling: the scheduler computes `t0 + cumulativeUnits × unitDuration` for each flip, not incremental sleeps. Target jitter: < 10 ms per flip on recent hardware.
- FR-13: Tap anywhere on beacon screen aborts immediately and cleans up per FR-11.

### 4.4 HUD
- FR-14: Top strip is 88pt tall (fits Dynamic Island / notch safely), two monospaced lines:
  - **Line 1**: source message, current character highlighted (inverse video with colored background — suggest amber `#FFA500` on black text for dim adaptation).
  - **Line 2**: full message rendered as Morse (using `·` for dit, `−` for dah, single space between elements of a character, 3-space gap between characters, 7-space gap between words), current element highlighted the same way.
- FR-15: Both lines horizontally auto-scroll to keep the highlighted element/character roughly centered. Scrolling is instantaneous at character boundaries (no animation that could compete with the flash timing visually).
- FR-16: HUD strip remains visible and at constant brightness throughout transmission. It does not flash.

### 4.5 Settings
- FR-17: Timing model selector: PARIS or Farnsworth.
- FR-18: Character WPM slider: 5–20, default 10.
- FR-19: Farnsworth effective WPM slider (only shown when Farnsworth selected): 5–character WPM, default 8.
- FR-20: Settings persist via UserDefaults.

### 4.6 Safety and accessibility
- FR-21: On first launch, show a full-screen warning: "This app produces rapid flashing light that may trigger seizures in people with photosensitive epilepsy. Do not use if you or anyone nearby is affected." Require explicit acknowledgement. Store acknowledgement flag.
- FR-22: If `UIAccessibility.isReduceMotionEnabled` is true, cap maximum WPM at 10 (slower flashes).
- FR-23: Tap-to-abort target is the entire beacon screen. No small hit targets.

## 5. Non-functional requirements

- NFR-1: Launch to input screen in under 500 ms on iPhone 12 or newer.
- NFR-2: No network calls of any kind. No third-party SDKs. No analytics.
- NFR-3: Core encoding and scheduling logic has no UIKit/SwiftUI imports and is covered by unit tests (≥90% line coverage for `Core/`).
- NFR-4: App binary size target: < 5 MB.
- NFR-5: Works entirely offline. No entitlements beyond what iOS grants by default.

## 6. Architecture

```
MorseBeacon/
├── Core/                          (pure Swift, no UI imports)
│   ├── MorseTable.swift
│   ├── MorseEncoder.swift
│   ├── TimingProfile.swift
│   └── TransmissionSchedule.swift
├── Runtime/                       (device bindings)
│   ├── Transmitter.swift
│   └── ScreenController.swift
├── UI/                            (SwiftUI)
│   ├── App.swift
│   ├── InputView.swift
│   ├── CountdownView.swift
│   ├── BeaconView.swift
│   ├── SettingsView.swift
│   └── SafetyWarningView.swift
└── Tests/
    ├── MorseEncoderTests.swift
    ├── TimingProfileTests.swift
    └── TransmissionScheduleTests.swift
```

**Core responsibilities**
- `MorseTable`: static `[Character: [Element]]` mapping.
- `MorseEncoder`: `String → [TimedElement]` where `TimedElement = (kind: ElementKind, sourceCharIndex: Int?, elementIndexInMessage: Int)`. Source indices enable HUD highlighting.
- `TimingProfile`: encodes PARIS or Farnsworth; produces element durations in milliseconds.
- `TransmissionSchedule`: given `[TimedElement]` + `TimingProfile`, produces `[ScheduleTick]` where each tick is `(absoluteOffsetMs: Int, isOn: Bool, sourceCharIndex: Int?, elementIndexInMessage: Int)`.

**Runtime responsibilities**
- `Transmitter`: ObservableObject. Holds schedule, drives playback using `DispatchSourceTimer` with absolute deadlines anchored to `DispatchTime.now()` at start. Publishes `@Published` current state (`.idle | .countdown(secondsLeft) | .transmitting(tick) | .finished`). Handles abort.
- `ScreenController`: saves/restores brightness and idle timer; imperative API called from `BeaconView.onAppear/onDisappear`.

**UI responsibilities**
- Views bind to `Transmitter` state. `BeaconView` uses `TimelineView(.animation)` or observes `Transmitter.$currentTick` to drive the flash and HUD. The actual timing source of truth is `Transmitter`, not SwiftUI — SwiftUI just renders whatever `isOn` the transmitter publishes.

## 7. Data model

```
enum ElementKind { case dit, dah, intraGap, charGap, wordGap }

struct TimedElement {
    let kind: ElementKind
    let sourceCharIndex: Int?      // nil for inter-character/inter-word gaps
    let elementIndexInMessage: Int // monotonic, used for HUD line 2 highlight
}

enum TimingProfile {
    case paris(wpm: Int)
    case farnsworth(charWpm: Int, effectiveWpm: Int)

    func duration(of kind: ElementKind) -> Int  // ms
}

struct ScheduleTick {
    let absoluteOffsetMs: Int
    let durationMs: Int            // span model: tick is active from offset to offset+duration
    let isOn: Bool
    let sourceCharIndex: Int?
    let elementIndexInMessage: Int
}
```

## 7a. Resolved design decisions (appended 2026-04-20)

These resolve the open questions raised in `TASKS.md` before their implementing
tasks are picked up. Listed here so the PRD remains the single source of truth.

**R1 — `ScheduleTick` is a span, not an edge.** Each tick carries `durationMs`
and is 1:1 with a `TimedElement`. Gaps are emitted as `isOn=false` ticks.
Total transmission length = sum of tick durations = `last.offset + last.duration`.
No terminal sentinel tick. `Transmitter` transitions to `.finished` at
`t0 + totalDurationMs`. Rationale: each tick is self-describing; emitters
(optical, and later haptic/audio) never need to look ahead to tick N+1 to
know when tick N ends. This is the property Phase 2 depends on.

**R2 — Encoder is total; validation lives at the domain boundary.**
Introduce `struct ValidatedMessage` in `Core/` with a failable/throwing init
that checks every character against `MorseTable.supports(_:)`. The only way
to construct one is through that init. `MorseEncoder.encode(_: ValidatedMessage)
-> [TimedElement]` is non-throwing and total. `InputView` constructs a
`ValidatedMessage` as the user types; failure cases surface the offending
character and index for inline UI feedback. Single source of truth for
"what is a valid message": `MorseTable`.

**R3 — "Transmit again" shows the full 5-second countdown.** The countdown
is treated as a bystander-safety and last-chance-cancel gate, not merely an
aiming aid. Consistency of path into beacon mode is preserved: every entry
to `BeaconView` passes through `CountdownView`. If field use reveals the
5-second tax is unacceptable for back-and-forth signaling, revisit in v1.1
with a shorter repeat-countdown, not by skipping it outright.

**R4 — HUD highlight strictly follows the tick (no stickiness).** During
`charGap` and `wordGap` ticks, neither HUD line shows a highlight; both go
to a neutral (un-highlighted) state. The highlight reappears on the next
dit/dah tick. Rationale: "lockstep with the flash" (AC-3) is interpreted
literally — if the channel is off, the HUD is un-highlighted. Trade-off
accepted: the HUD will visibly blink between highlighted and neutral during
gaps. Auto-scroll (FR-15) anchors to the *most recent* highlighted element's
position during gaps, so the viewport does not drift while un-highlighted.
Note: intraGap is short (1 dit) and lives inside a single character; it
still un-highlights per this rule, but the perceptual effect is minimal.

## 8. Deferred / open

- watchOS companion (v2 candidate).
- Prosign insertion (`<CT>`, `<AR>`, `<SK>`) — not in v1.
- Custom dit/dah glyphs — using `·` and `−` for v1, revisit if legibility is poor.

## 9. Acceptance criteria

- AC-1: Typing "SOS" at 10 WPM PARIS produces a transmission of correct duration within ±50 ms end-to-end on device.
- AC-2: Tapping the beacon screen mid-transmission returns the user to the input screen within 200 ms with brightness restored.
- AC-3: The HUD's highlighted character and Morse element advance in lockstep with the flash, verifiable by screen recording.
- AC-4: Encoder round-trip test: encoding `"PARIS "` (with trailing space) at 20 WPM PARIS produces exactly 60 dit-units total duration (the standard definition of 1 WPM PARIS is "PARIS " per minute = 50 units/minute → at 20 WPM = 1000 units/minute).
- AC-5: Backgrounding the app during transmission aborts cleanly and restores brightness on next foreground.

---

## 10. Phase 2 — Haptic channel

**Rationale.** The phone pressed against a rigid conductor (heating pipe, metal door, wall stud) couples the Taptic Engine's output into the structure acoustically. This extends the beacon's useful range to scenarios where line-of-sight isn't possible: through walls, floors, between rooms of a building. It also extends usefulness to conditions where light is unwanted (covert signaling) or useless (fog, daylight at distance).

**Scope.**
- Add a second emitter channel driven by the same `TransmissionSchedule` that drives the optical channel.
- User can enable optical, haptic, or both simultaneously for a given transmission.
- Dedicated WPM range for haptic: 4–10 (haptic pulses smear together above ~10 WPM).

**Functional requirements.**
- FR-P2-1: Haptic output uses `CoreHaptics` (`CHHapticEngine`) with `.hapticTransient` for dits and `.hapticContinuous` for dahs.
- FR-P2-2: Dit is a single sharp transient. Dah is a continuous haptic of `3 × ditDurationMs` at maximum supported intensity and sharpness.
- FR-P2-3: Inter-element gaps are genuine silence (no haptic output).
- FR-P2-4: Haptic WPM is independent of optical WPM and defaults to 7.
- FR-P2-5: When both channels are active, they share a single schedule so optical flashes and haptic pulses are phase-locked. If user selects different WPMs for the two channels, disable simultaneous mode and require one channel at a time (v2 scope limit).
- FR-P2-6: On devices without Taptic Engine support (older hardware, though iOS 17+ minimum already excludes most), gracefully hide the haptic option.
- FR-P2-7: Haptic transmission does not require screen to be on — allow user to lock the phone's screen (or use a dimmed screen mode) to save battery while haptic runs. If this requires background audio session tricks, document them; otherwise keep screen dimly on.
- FR-P2-8: HUD behavior during haptic-only transmission: same top strip, but flash area stays black (or shows a pulsing dot matching the pulse for visual confirmation). No full-screen flashing.

**Architectural note.** The v1 `Transmitter` must publish a schedule tick stream that is channel-agnostic. Emitters subscribe. This is a cheap design decision to make now and prevents a rewrite at Phase 2. See CLAUDE.md §Architecture rules.

**Open questions for Phase 2 spec.**
- Can we key the Taptic Engine precisely enough for readable 7 WPM through a pipe? Needs empirical test on device against typical materials (steel pipe, wooden stud, drywall, concrete).
- Battery impact of sustained `CHHapticEngine` use — if it's severe, add a battery-level warning and/or auto-stop threshold.
- Thermal: CoreHaptics under sustained load can warm the device. Monitor `ProcessInfo.thermalState` and halt gracefully at `.serious`.

---

## 11. Phase 3 — Audio tone channel

**Rationale.** A pure tone (600–800 Hz, the traditional Morse sidetone range) played through the phone's speaker is audible at meaningful distances through air, and when the phone is pressed against a rigid conductor it couples even better than haptic — the speaker diaphragm is a more efficient acoustic transducer for sustained tones than the Taptic Engine. Complements Phase 2: haptic is silent/covert, audio is loud/overt.

**Scope.**
- Third channel, same schedule.
- Tone generation via `AVAudioEngine` with a sine oscillator, gated on/off per schedule tick.

**Functional requirements.**
- FR-P3-1: Tone frequency user-selectable in 100 Hz steps, range 400–1000 Hz, default 700 Hz.
- FR-P3-2: Volume respects system volume; do not force maximum.
- FR-P3-3: Tone envelope has 5 ms attack/release to avoid clicks at key-down/key-up (standard Morse practice).
- FR-P3-4: Audio WPM range 5–30, default 15. Audio can tolerate higher rates than haptic or optical.
- FR-P3-5: Multi-channel combinations allowed (optical + audio, haptic + audio, all three) provided WPMs match; otherwise same limitation as FR-P2-5.
- FR-P3-6: Respects silent mode switch — if silent mode is on, show a one-time banner explaining audio channel is muted, do not override.

**Open questions for Phase 3.**
- Audio session category: `.playback` seems right (plays when screen locked, ignores ringer), but that conflicts with FR-P3-6 if we use it. `.ambient` respects the silent switch but stops when screen locks. Likely `.playback` + an explicit user setting.
- Accessibility: audio channel doubles as a sensory-substitute output for users who want to hear rather than see the Morse. Worth featuring that framing in-app.
