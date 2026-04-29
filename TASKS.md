# TASKS — Morse Beacon

Ordered, check-off-able task list to get from empty repo to a shipping v1 that
satisfies `PRD.md`. Sections follow the inward→outward architecture rule from
`CLAUDE.md`: `Core/` → `Runtime/` → `UI/`, tests-first within each layer.

Phase 2 (haptic) and Phase 3 (audio) tasks are listed at the bottom and are
explicitly out of v1 scope — they exist here only so v1 design decisions
don't paint us into a corner.

---

## 0. Project bootstrap

Target layout is documented in `LAYOUT.md` (canonical). Tasks below reference
it by path.

- [ ] 0.1 Create Xcode project `MorseBeacon.xcodeproj` at repo root (iOS 17+, SwiftUI lifecycle, Swift 5.9+). Explicit `Info.plist` (not generated), located at `MorseBeacon/Info.plist`.
- [ ] 0.2 Set bundle id, team, signing. iPhone-only (no iPad idiom in v1).
- [ ] 0.3 Configure `MorseBeacon/Info.plist`: supported orientations (all — app locks at runtime via `OrientationLockHost`, not in plist), no capabilities beyond default, no background modes.
- [ ] 0.4 Create the on-disk tree exactly as specified in `LAYOUT.md`: `MorseBeacon/{Core,Runtime,UI}/`, `MorseBeacon/{Assets.xcassets,PreviewContent}/`, `MorseBeaconTests/{Core,Runtime,Fixtures}/`, `MorseBeaconUITests/`, `scripts/`, `docs/`. Xcode groups must mirror folders 1:1 (no "group without folder").
- [ ] 0.5 Add `.swift-format` (default config) at repo root; add CI step running `swift-format lint --strict` across the app target and tests.
- [ ] 0.6 Add unit-test target `MorseBeaconTests` wired to `MorseBeaconTests/`. Add empty `MorseBeaconUITests/` target stub (no tests yet — add only when an AC demands it).
- [ ] 0.7 Decide: extract `Core/` as a local SwiftPM package at `Core-Package/` for fast `swift test` loop if Xcode test turnaround > 10s (per CLAUDE.md "What to run"). Defer until measured. When/if done, `MorseBeacon/Core/` is removed and the app target depends on the package.
  - *Note (2026-04-22):* a development-only `Package.swift` overlay exists at repo root pointing SwiftPM at `MorseBeacon/Core/` and `MorseBeaconTests/Core/` via explicit `path:`. This is NOT the 0.7 extraction — no files are moved, no `Core-Package/` exists. The overlay lets Core tests run via `swift test` before the Xcode project exists. It coexists with the future Xcode target and will be replaced by the real package if/when 0.7 is triggered.
- [x] 0.8 Add `.gitignore` (Xcode, SwiftPM, DerivedData, xcuserdata, `.DS_Store`). *(commit 191df2b)*
- [x] 0.9 `scripts/check-core-purity.sh` greps `MorseBeacon/Core/` for forbidden tokens. Final list: `import UIKit`, `import SwiftUI`, `import Combine`, `import Dispatch`, `Foundation.Timer`, `NSTimer`, `Timer(`, `DispatchQueue`, `DispatchSource`, `DispatchTime`, `CFAbsoluteTime`, `CFRunLoop`, `RunLoop.`. Exit non-zero on any hit. Currently passing on 10 Core files.
- [x] 0.10 `scripts/check-screen-isolation.sh` greps the app target for `UIScreen.` and `UIApplication.shared.isIdleTimerDisabled` (qualified access patterns, to avoid false positives in doc comments and on our own protocol). Allows matches only in `MorseBeacon/Runtime/UIKitScreenProxy.swift` — sharper than the original "only ScreenController" rule because the controller is now pure logic delegating to a proxy. LAYOUT.md updated.
- [ ] 0.11 CI: `.github/workflows/ci.yml` running, in order: `scripts/check-core-purity.sh`, `scripts/check-screen-isolation.sh`, `swift-format lint --strict`, `xcodebuild test` on macOS runner against iPhone 15 simulator. Fail on any warning (treat warnings as errors at project level).

## 1. Core — pure Swift, no UIKit/SwiftUI/Foundation.Timer

Rules: `Int` milliseconds, deterministic, tests before code.

### 1.1 Morse table

- [x] 1.1.1 Test: every character in FR-1 allowed set has a mapping; disallowed chars don't. *(MorseTableTests: `test_supports_*`)*
- [x] 1.1.2 Test: spot-check well-known encodings (A = `·−`, N = `−·`, SOS = `···/−−−/···`, `?` = `··−−··`). *(MorseTableTests: `test_symbols_*`)*
- [x] 1.1.3 Implement `MorseTable` as a `[Character: [MorseSymbol]]` where `MorseSymbol` is `.dit | .dah`. Plus `supports(_:)` as single source of truth for R2. 15/15 tests passing in 3ms.

### 1.2 Element kinds and timed elements

- [x] 1.2.1 Define `enum ElementKind { case dit, dah, intraGap, charGap, wordGap }`. Added `isOn: Bool` convenience for channel-agnostic downstream use.
- [x] 1.2.2 Define `struct TimedElement { kind; sourceCharIndex: Int?; elementIndexInMessage: Int }`.

### 1.3 `MorseEncoder`

- [x] 1.3.1 Test: encoding `""` → `[]`.
- [x] 1.3.2 Test: encoding `"E"` (single dit) → `[dit(sourceCharIndex:0, idx:0)]` — no trailing gap.
- [x] 1.3.3 Test: encoding `"EE"` → `dit, charGap, dit` with correct source indices.
- [x] 1.3.4 Test: encoding `"E E"` (with space) → `dit, wordGap, dit`.
- [x] 1.3.5 Test: encoding `"AN"` → `dit, intraGap, dah, charGap, dah, intraGap, dit` with right indices.
- [x] 1.3.6 Test: lowercase normalized to uppercase produces identical output to uppercase.
- [x] 1.3.7 Per R2: `MorseTable.supports(_ c: Character) -> Bool` exists; tests cover the full FR-1 set and representative rejections. *(covered in 1.1)*
- [x] 1.3.8 Per R2: `struct ValidatedMessage` with throwing init; tests cover accept valid, reject with correct index, case normalization, 160-char cap, and "first bad char wins" semantics.
- [x] 1.3.9 Test: `sourceCharIndex` is nil for `charGap`/`wordGap`, non-nil for dit/dah/intraGap.
- [x] 1.3.10 Test: `elementIndexInMessage` is monotonically increasing by 1 from 0.
- [x] 1.3.11 Implement `MorseEncoder.encode(_ message: ValidatedMessage) -> [TimedElement]` — total, non-throwing. 39/39 Core tests passing.

### 1.4 `TimingProfile`

- [x] 1.4.1 Test (PARIS): `paris(wpm: 20).duration(.dit)` == 60 ms (`1200/20`).
- [x] 1.4.2 Test (PARIS ratios): dah = 3×dit, intraGap = 1×dit, charGap = 3×dit, wordGap = 7×dit. Asserted across all WPMs 5–20.
- [x] 1.4.3 Test (Farnsworth): dit/dah use char WPM; charGap/wordGap stretched so that sending "PARIS " at effective WPM takes `60_000 / effectiveWpm` ms (tolerance ≤20 ms for integer rounding across 5 gaps).
- [x] 1.4.4 Test (Farnsworth guard): `effectiveWpm <= charWpm` enforced via `makeFarnsworth` factory returning nil.
- [x] 1.4.5 Test: WPM range 5–20 enforced at construction via `makeParis` / `makeFarnsworth` factories.
- [x] 1.4.6 Implement `TimingProfile` as `enum` with associated values + `duration(of:) -> Int`. Short-circuit at `effectiveWpm == charWpm` keeps Farnsworth exactly equal to PARIS (load-bearing property; without it Bloom's formula diverges by 1–4 ms at awkward WPMs). 12 new tests, 51 total passing.

### 1.5 `TransmissionSchedule`

- [x] 1.5.1 Per R1: schedule for `"E"` at 20 WPM PARIS = exactly one `ScheduleTick(offset:0, duration:60, isOn:true, …)`. No terminal sentinel. Total duration = `last.offset + last.duration`.
- [x] 1.5.2 Test (AC-4 invariant): `TransmissionSchedule.totalDurationMs(schedule("PARIS ", .paris(20))) == 3000`. `test_parisInvariantIs50Units` passing.
- [x] 1.5.3 Test: every dit/dah element → `isOn=true` tick; every gap element → `isOn=false` tick. Ticks are 1:1 with elements.
- [x] 1.5.4 Test: `absoluteOffsetMs` strictly monotonic; each tick's `offset == previous.offset + previous.duration`.
- [x] 1.5.5 Test: `sourceCharIndex` and `elementIndexInMessage` propagate to ticks correctly.
- [x] 1.5.6 Test: `SOS` at 10 WPM PARIS produces 3240 ms exactly (27 units × 120 ms). Matches AC-1 at the schedule layer.
- [x] 1.5.7 Implement `TransmissionSchedule.build(elements:profile:) -> [ScheduleTick]` + `totalDurationMs`. 11 new tests, 62 total passing.

### 1.6 HUD rendering helpers (still pure Swift)

- [x] 1.6.1 Test: `MorseRenderer.renderLine2(elements)` produces `"·−   −·"` for `"AN"` (3-space charGap, 7-space wordGap, **zero-width intraGap** — the parenthetical in the original task text said "single space intraGap" but that contradicted the expected string value `"·−   −·"`; went with the string convention, which matches conventional Morse-in-text rendering and doesn't collide with R4's "no highlight during gap ticks").
- [x] 1.6.2 Test: element-index → column-index mapping is correct (used by HUD scroller).
- [x] 1.6.3 Implement `MorseRenderer` returning `Line2 { string, elementIndexToColumn }`. 10 new tests, 72 Core tests total, all passing in 9ms.

### 1.7 Core coverage gate

- [x] 1.7.1 Verify ≥90% line coverage for `Core/` (NFR-3). **Measured: 97.21% lines, 94.74% functions, 96.43% regions.** Procedure: `./scripts/measure-core-coverage.sh`. Two non-100% files (`MorseEncoder.swift` 88.64%, `ValidatedMessage.swift` 96.77%) miss only documented unreachable defensive branches — see `docs/coverage.md`.
- [x] 1.7.2 Verify `Core/` has zero imports of UIKit/SwiftUI/`Foundation.Timer` etc. via `scripts/check-core-purity.sh` (passes; runs in CI per 0.11).

## 2. Runtime — device bindings

### 2.1 `ScreenController`

- [x] 2.1.1 API: `acquire()` snapshots `proxy.brightness` and `proxy.isIdleTimerDisabled`, sets brightness=1.0 and idle disabled. `release()` restores both. Both idempotent. Pure-Swift logic; UIKit binding lives in `UIKitScreenProxy.swift` behind `#if canImport(UIKit)`.
- [x] 2.1.2 Tests against `FakeScreenProxy` (in-memory + event-recording): acquire snapshots before writing; double-acquire does NOT re-snapshot (guards against the bug class where the second acquire captures its own freshly-set 1.0 as "previous"); release without acquire is a true no-op (proxy is not even read); release restores captured `idleTimerDisabled=true` correctly; reacquire-after-release captures the new previous value. 8 tests passing.
- [x] 2.1.3 Only `UIKitScreenProxy.swift` touches `UIScreen.` / `UIApplication.shared.isIdleTimerDisabled`, enforced by `scripts/check-screen-isolation.sh`.

### 2.2 `Transmitter`

- [ ] 2.2.1 Define `enum TransmitterState { case idle, countdown(secondsLeft: Int), transmitting(currentTick: ScheduleTick), finished, aborted }`. Published.
- [ ] 2.2.2 Define channel-agnostic `ScheduleTick` publication — do NOT name the field `flashOn`; name it `isOn` with the documented meaning "channel active for the span `[offset, offset+duration)`" (CLAUDE.md Architecture rules; PRD R1).
- [ ] 2.2.3 Implement countdown using `DispatchSourceTimer` (5→0).
- [ ] 2.2.4 Implement playback using `DispatchSourceTimer` with `.strict` flag and absolute deadlines: `t0 = DispatchTime.now()`, each tick scheduled at `t0 + .milliseconds(tick.absoluteOffsetMs)`. No incremental sleeps.
- [ ] 2.2.5 `abort()` cancels timer, publishes `.aborted`, triggers cleanup.
- [ ] 2.2.6 Observe `UIApplication.didEnterBackgroundNotification` → auto-abort (AC-5).
- [ ] 2.2.7 Test: given a fake clock + fake timer, ticks are fired at the correct offsets for a `SOS` schedule.
- [ ] 2.2.8 Test: abort while transmitting produces `.aborted` within one tick.
- [ ] 2.2.9 Test: on finish, publishes `.finished` exactly once at `t0 + schedule.totalDurationMs` (per R1, no terminal sentinel tick is consumed to trigger this — Transmitter schedules `.finished` itself).
- [ ] 2.2.10 Instrumented on-device test for jitter: log `DispatchTime.now()` deltas, assert < 10 ms jitter per flip on iPhone 12+ (FR-12). Document results in `docs/timing.md`.

### 2.3 Reduce-Motion clamp

- [x] 2.3.1 `AccessibilityFlags` value type (Equatable, Hashable, Sendable) with `isReduceMotionEnabled: Bool` and `maxCharacterWPM: Int` (caps at 10 if Reduce Motion is on, 20 otherwise; FR-22). `current()` static factory behind `#if canImport(UIKit)` reads `UIAccessibility.isReduceMotionEnabled`. Tests construct snapshots directly. 3 tests passing.

### 2.4 Clock (preparation for 2.2)

- [x] 2.4.1 `Clock` protocol: `nowMs: Int` and `schedule(at:_:) -> ClockSubscription` for absolute-deadline scheduling per FR-12.
- [x] 2.4.2 `DispatchClock` production impl using `DispatchSourceTimer` with `.strict` flag and absolute deadlines anchored to a single `referenceTime` captured at init. Avoids the cumulative drift of incremental sleeps.
- [x] 2.4.3 `ClockSubscription` is thread-safe and cancel-idempotent. Smoke tests verify monotonic `nowMs`, fires-near-target, cancel-prevents-fire, double-cancel-safe. (Tight jitter tolerance is FR-12's on-device measurement, not these unit tests.)

## 3. UI — SwiftUI

### 3.1 App shell

- [ ] 3.1.1 `MorseBeaconApp` with single `WindowGroup` hosting a root coordinator view.
- [ ] 3.1.2 Root view chooses: `SafetyWarningView` (if not acknowledged) → `InputView`.
- [ ] 3.1.3 Inject shared `Transmitter`, `Settings` (observable), `ScreenController` into environment.

### 3.2 `SafetyWarningView`

- [ ] 3.2.1 Full-screen modal, dismissible only via explicit "I understand" button (FR-21).
- [ ] 3.2.2 Persist acknowledgement flag in UserDefaults (`safetyAcknowledgedV1`).
- [ ] 3.2.3 Snapshot test (optional) for layout.

### 3.3 `InputView`

- [ ] 3.3.1 Text field, multiline capable, 160-char cap (FR-3) with live counter.
- [ ] 3.3.2 Live validation via `ValidatedMessage` init (R2); on failure, underline the offending character at the reported index; Transmit disabled while invalid or empty. Single source of truth: `MorseTable.supports(_:)`.
- [ ] 3.3.3 Load last message from UserDefaults on appear; save on change (FR-4).
- [ ] 3.3.4 Settings gear → pushes `SettingsView`.
- [ ] 3.3.5 Transmit button → pushes `CountdownView`.
- [ ] 3.3.6 Accessibility labels for text field, counter, Transmit, Settings.

### 3.4 `SettingsView`

- [ ] 3.4.1 Picker: PARIS | Farnsworth (FR-17).
- [ ] 3.4.2 Character WPM slider 5–20, default 10 (FR-18). Clamp max to 10 if Reduce Motion is on (FR-22).
- [ ] 3.4.3 Effective WPM slider 5–charWpm, only visible under Farnsworth (FR-19).
- [ ] 3.4.4 Persist via UserDefaults (FR-20).
- [ ] 3.4.5 Re-show safety warning link; "Reset last message" button.

### 3.5 `CountdownView`

- [ ] 3.5.1 5s countdown with large numeral, "Aim your phone" caption. Per R3: shown on every entry to beacon mode, including "Transmit again."
- [ ] 3.5.2 Tap anywhere cancels, pops back to Input.
- [ ] 3.5.3 On 0, pushes `BeaconView`.

### 3.6 `BeaconView`

- [ ] 3.6.1 Orientation lock at appear: implement `OrientationLockHostingController` (UIViewControllerRepresentable) overriding `supportedInterfaceOrientations` (CLAUDE.md gotcha).
- [ ] 3.6.2 `onAppear`: `ScreenController.acquire()`, `Transmitter.start(schedule)`. `onDisappear`: `ScreenController.release()`.
- [ ] 3.6.3 Layout: top strip 88pt (HUD), 4pt black separator, rest = flash area (FR-9, FR-14).
- [ ] 3.6.4 Flash area binds to `Transmitter.currentTick.isOn`: pure black ↔ pure white, no animation.
- [ ] 3.6.5 HUD Line 1: source text, current character highlighted (amber `#FFA500` bg, black fg — FR-14). Monospaced. Per R4: highlight appears only during dit/dah/intraGap ticks whose `sourceCharIndex` is non-nil; neutral during charGap/wordGap.
- [ ] 3.6.6 HUD Line 2: Morse rendering via `MorseRenderer`, current element highlighted. Per R4: no highlight during gap ticks.
- [ ] 3.6.7 Auto-scroll both HUD lines to keep highlight centered; no smooth animation at element level (FR-15). Per R4: during un-highlighted gap ticks, the viewport holds at the most recent highlighted position (no drift).
- [ ] 3.6.8 Full-screen tap gesture → `Transmitter.abort()`, navigate back (FR-13, AC-2 < 200 ms).
- [ ] 3.6.9 On `.finished`: show "Transmit again" / "Done" overlay (user flow §3.4). Overlay may appear on a neutral screen after restoring brightness.
- [ ] 3.6.10 Handle backgrounding AND call interruptions (`AVAudioSession` interruption / phone call): rely on Transmitter's observers to abort; view cleans up on disappear.

### 3.7 Visual polish pass

- [ ] 3.7.1 Dark-first palette; UI chrome uses system materials except inside `BeaconView`.
- [ ] 3.7.2 Dynamic Type support for Input/Settings (not HUD — HUD is fixed monospace for legibility at distance).
- [ ] 3.7.3 VoiceOver pass on non-beacon screens.

## 4. Wiring and integration

- [ ] 4.1 Settings → TimingProfile factory helper.
- [ ] 4.2 Message + TimingProfile → `[TimedElement]` → `[ScheduleTick]` pipeline builder with one test covering the full pipeline for "SOS" @ 10 WPM (supports AC-1).
- [ ] 4.3 "Transmit again" re-runs the same pipeline with identical inputs (no text re-entry).

## 5. Verification against PRD acceptance criteria

- [ ] 5.1 AC-1: "SOS" @ 10 WPM PARIS, measured end-to-end on device within ±50 ms. Record procedure in `docs/ac1-measurement.md`.
- [ ] 5.2 AC-2: Tap-to-abort returns to input < 200 ms with brightness restored. Verify on device.
- [ ] 5.3 AC-3: HUD highlight and flash stay in lockstep. Verify by 240fps screen recording.
- [ ] 5.4 AC-4: `Tests/TransmissionScheduleTests.testParisInvariantIs50Units` passes (encoded in 1.5.2).
- [ ] 5.5 AC-5: Background-during-transmission aborts cleanly; brightness restored on foreground.

## 6. Pre-release checks

- [ ] 6.1 `xcodebuild test` clean on iPhone 15 simulator + one physical device.
- [ ] 6.2 Zero warnings, zero force unwraps outside `Tests/`, zero `try!` in production.
- [ ] 6.3 `scripts/check-core-purity.sh` passes locally and in CI (enforces `Core/` has no UIKit/SwiftUI/Foundation.Timer imports).
- [ ] 6.4 `scripts/check-screen-isolation.sh` passes locally and in CI (enforces only `MorseBeacon/Runtime/ScreenController.swift` touches `UIScreen` / `isIdleTimerDisabled`).
- [ ] 6.5 Binary size < 5 MB (NFR-4). Measure `.ipa` via Xcode Organizer.
- [ ] 6.6 Launch time < 500 ms on iPhone 12+ (NFR-1). Measure with Instruments.
- [ ] 6.7 Confirm no network calls: run app behind Little Snitch / `nscurl` + Instruments Network profile. Should be silent.
- [ ] 6.8 App Store metadata: description, screenshots (dark beacon frame + input + settings), privacy nutrition label (all "data not collected"), photosensitivity warning in description.
- [ ] 6.9 TestFlight pass with at least one external tester doing a real night-time line-of-sight test.

## 7. Documentation

- [ ] 7.1 README: what it is, how to build, how to use, photosensitivity warning, known constraints (Auto-Brightness, True Tone, Night Shift — CLAUDE.md gotchas).
- [ ] 7.2 `docs/timing.md`: explain PARIS vs Farnsworth, where the 50-unit invariant comes from, jitter measurement procedure.
- [ ] 7.3 Inline doc comments on `Core/` public API only. Keep comments sparse per CLAUDE.md style.

---

## Phase 2 — Haptic channel (deferred, do not start in v1)

Listed so the v1 `Transmitter` design does not block it. See PRD §10.

- [ ] P2.1 Confirm v1 `Transmitter` exposes `AnyPublisher<ScheduleTick, Never>` (or equivalent) with no optical-specific semantics. Add a test asserting a second subscriber receives identical ticks — this is the one thing v1 MUST get right for P2 not to require a rewrite.
- [ ] P2.2 `HapticEmitter` using `CHHapticEngine` (FR-P2-1/2/3).
- [ ] P2.3 Independent haptic WPM 4–10, default 7 (FR-P2-4).
- [ ] P2.4 Multi-channel gating rule per FR-P2-5.
- [ ] P2.5 Graceful fallback per FR-P2-6; thermal halt per §10 open questions.
- [ ] P2.6 Empirical range test through steel pipe / wood stud / drywall / concrete. Write up in `docs/p2-field-test.md`.

## Phase 3 — Audio tone channel (deferred, do not start in v1)

- [ ] P3.1 `AudioEmitter` using `AVAudioEngine` sine oscillator, gated by ticks, 5 ms attack/release (FR-P3-3).
- [ ] P3.2 Frequency picker 400–1000 Hz step 100, default 700 (FR-P3-1).
- [ ] P3.3 Audio WPM 5–30, default 15 (FR-P3-4).
- [ ] P3.4 Audio session category decision (FR-P3-6 open question) — prototype both `.playback` and `.ambient`, pick one, document.
- [ ] P3.5 Multi-channel WPM-match gating (FR-P3-5).

---

## Open questions to resolve before coding

1. Terminal tick convention in `TransmissionSchedule` (task 1.5.1): emit a closing `isOn=false` tick at total duration, or rely on state machine alone? Recommendation: emit it — simplifies `Transmitter` and HUD end-state.
2. Encoder error API (task 1.3.7): `throws` vs `Result`. Recommendation: `throws` — SwiftUI views can catch and surface inline.
3. Should "Transmit again" skip the 5s countdown? PRD §3.4 is silent. Recommendation: keep the countdown for consistency and safety.
4. HUD Line 2 highlight granularity during gaps: highlight the gap itself, or keep the previous element lit? Recommendation: no highlight during `charGap`/`wordGap`; keep intraGap visually attached to its character.

**Status:** all four resolved 2026-04-20. See `PRD.md` §7a (R1–R4).

- Q1 → R1: tick carries `durationMs`; ticks are spans, 1:1 with elements; no terminal sentinel.
- Q2 → R2: `ValidatedMessage` at the domain boundary; encoder is total; `MorseTable` is the single validity source.
- Q3 → R3: full 5-second countdown on every entry, including "Transmit again."
- Q4 → R4: HUD highlight strictly follows ticks; neutral during gap ticks; scroll viewport holds during gaps.
