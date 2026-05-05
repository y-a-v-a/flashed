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

- [x] 0.1 `MorseBeacon.xcodeproj` created at repo root by hand-writing `project.pbxproj` (objectVersion 56). iOS 17+, SwiftUI lifecycle, Swift 5.0 (latest 5.x). Explicit `MorseBeacon/Info.plist` (`GENERATE_INFOPLIST_FILE = NO`). Two targets: `MorseBeacon` (iOS app) and `MorseBeaconTests` (unit-test bundle). Shared scheme at `xcshareddata/xcschemes/MorseBeacon.xcscheme`. Verified with `xcodebuild -list` and `-showdestinations`. Source compilation verification deferred until iOS runtime installed (Xcode 26 separates SDK from simulator runtime; current host has SDK only).
- [x] 0.2 `PRODUCT_BUNDLE_IDENTIFIER = com.example.morsebeacon` (placeholder — user replaces for real signing). `CODE_SIGN_STYLE = Automatic`. `TARGETED_DEVICE_FAMILY = 1` (iPhone-only; iPad excluded per PRD non-goal). `SUPPORTS_MACCATALYST/MAC_DESIGNED_FOR_IPHONE_IPAD/XR_DESIGNED = NO`.
- [x] 0.3 `MorseBeacon/Info.plist` declares all four orientations (runtime locks via `OrientationLockHost` per FR-10; not enforced in plist). `LSRequiresIPhoneOS = true`. No background modes, no usage descriptions, no ATS keys, no capabilities. `UIApplicationSceneManifest` minimal (single scene, SwiftUI).
- [x] 0.4 On-disk tree matches `LAYOUT.md`: `MorseBeacon/{Core,Runtime,UI}/`, `MorseBeacon/{Assets.xcassets,PreviewContent}/`, `MorseBeaconTests/{Core,Runtime,Fixtures}/`, `scripts/`, `docs/`. Xcode groups mirror folders 1:1 via `path = ...; sourceTree = "<group>"`. `UI/.gitkeep` and `Tests/Fixtures/.gitkeep` preserve empty dirs in git.
- [x] 0.5 `.swift-format` at repo root with the dumped default config (2-space indent, 100-col line, ordered imports, etc.). `scripts/format.sh` runs `swift-format format -i` on all 30 Swift files; `scripts/check-format.sh` runs `swift-format lint --strict` (CI-ready) and is wired into `check-all.sh`. One-shot reformatted all existing files (4-space → 2-space + minor adjustments); 99/99 SwiftPM tests + iOS build still green.
- [x] 0.6 `MorseBeaconTests` Xcode target created with `MorseBeaconTests.swift` stub (one trivial `XCTAssertTrue(true)` test, documented as a placeholder for future iOS-only tests). Test target uses `BUNDLE_LOADER` / `TEST_HOST` to host on `MorseBeacon.app`. The 99 SwiftPM unit tests at `MorseBeaconTests/{Core,Runtime}/` are NOT part of this Xcode target — they import `Core` / `Runtime` as separate SwiftPM modules, while the Xcode app is monolithic `MorseBeacon`. iOS-only tests added later will use `@testable import MorseBeacon`. `MorseBeaconUITests` target deferred until an AC actually requires UI tests.
- [ ] 0.7 Decide: extract `Core/` as a local SwiftPM package at `Core-Package/` for fast `swift test` loop if Xcode test turnaround > 10s (per CLAUDE.md "What to run"). Defer until measured. When/if done, `MorseBeacon/Core/` is removed and the app target depends on the package.
  - *Note (2026-04-22):* a development-only `Package.swift` overlay exists at repo root pointing SwiftPM at `MorseBeacon/Core/` and `MorseBeaconTests/Core/` via explicit `path:`. This is NOT the 0.7 extraction — no files are moved, no `Core-Package/` exists. The overlay lets Core tests run via `swift test` before the Xcode project exists. It coexists with the future Xcode target and will be replaced by the real package if/when 0.7 is triggered.
- [x] 0.8 Add `.gitignore` (Xcode, SwiftPM, DerivedData, xcuserdata, `.DS_Store`). *(commit 191df2b)*
- [x] 0.9 `scripts/check-core-purity.sh` greps `MorseBeacon/Core/` for forbidden tokens. Final list: `import UIKit`, `import SwiftUI`, `import Combine`, `import Dispatch`, `Foundation.Timer`, `NSTimer`, `Timer(`, `DispatchQueue`, `DispatchSource`, `DispatchTime`, `CFAbsoluteTime`, `CFRunLoop`, `RunLoop.`. Exit non-zero on any hit. Currently passing on 10 Core files.
- [x] 0.10 `scripts/check-screen-isolation.sh` greps the app target for `UIScreen.` and `UIApplication.shared.isIdleTimerDisabled` (qualified access patterns, to avoid false positives in doc comments and on our own protocol). Allows matches only in `MorseBeacon/Runtime/UIKitScreenProxy.swift` — sharper than the original "only ScreenController" rule because the controller is now pure logic delegating to a proxy. LAYOUT.md updated.

### 0.x Local check scripts

- [x] 0.x.1 `scripts/build-ios.sh`: wraps `xcodebuild build` for `generic/platform=iOS Simulator` with `CODE_SIGNING_ALLOWED=NO`. Quiet on success, full log on failure. ~1–2 s incremental, ~30–60 s clean.
- [x] 0.x.2 `scripts/test-ios.sh`: runs the Xcode unit-test target on the first available iPhone simulator (auto-detected via `simctl list`).
- [x] 0.x.3 `scripts/check-all.sh`: runs every gate in dependency order — purity → isolation → SwiftPM tests → iOS build → iOS tests (opt-in via `RUN_IOS_TESTS=1`). 2.4 s without iOS tests, ~70 s with.
- [x] 0.11 `.github/workflows/ci.yml` runs on `macos-15` runner. Fail-fast step order: env dump → core purity → screen isolation → format lint --strict → SwiftPM unit tests (`swift test --parallel`) → iOS Simulator build (`./scripts/build-ios.sh`) → iOS Simulator tests (`./scripts/test-ios.sh`). Concurrency group cancels superseded runs. `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` in pbxproj enforces no-warnings rule at compile time.

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

- [x] 2.2.1 `TransmitterState` enum (`.idle`, `.countdown(secondsLeft:)`, `.transmitting(currentTick:)`, `.finished`, `.aborted`). `Equatable`, `Sendable`. Allowed transitions documented in-file.
- [x] 2.2.2 Channel-agnostic publication: `state` is `@Published`; the `currentTick` convenience extracts the live `ScheduleTick` whose `isOn` field has the R1 "channel active for `[offset, offset+duration)`" meaning. No optical-specific naming.
- [x] 2.2.3 Countdown driven by absolute-deadline scheduling on the injected `Clock`. `start(_:countdownSeconds:5)` schedules N-1 tick-down callbacks at `t0 + 1s`, `t0 + 2s`, ..., then transmission begins at `t0 + N*1000`.
- [x] 2.2.4 Playback uses `DispatchClock` (DispatchSourceTimer + .strict + absolute deadlines from `referenceTime`). Each tick scheduled at `txStart + tick.absoluteOffsetMs`. No incremental sleeps. Verified via `FakeClock` virtual-time tests.
- [x] 2.2.5 `abort()` cancels all subscriptions, bumps the generation counter (invalidating any callbacks already in flight on the clock's queue), and sets `.aborted`. No-op from terminal states.
- [x] 2.2.6 `Transmitter.observeBackgrounding()` (behind `#if canImport(UIKit)`) returns an `NSObjectProtocol` token observing `UIApplication.didEnterBackgroundNotification`; on fire, calls `abort()`.
- [x] 2.2.7 `FakeClock` lets tests advance virtual time synchronously. Ticks fire at correct offsets for E, AN, and HELLO schedules. State stream observable via `tx.$state.sink`.
- [x] 2.2.8 `test_abortDuringTransmission_stopsRemainingTicks` and `test_abortDuringCountdown_setsAbortedAndCancelsPending` cover both phases. Generation counter ensures stale callbacks become no-ops.
- [x] 2.2.9 `test_finishedPublishedExactlyOnce` verifies `.finished` is emitted once at `t0 + schedule.totalDurationMs` and not republished by later clock advancement.
- [ ] 2.2.10 Instrumented on-device test for jitter: log `DispatchTime.now()` deltas, assert < 10 ms jitter per flip on iPhone 12+ (FR-12). Document results in `docs/timing.md`. *(Deferred until iOS device available; needs real Xcode project per task 0.1.)*

**Implementation notes:**
- Restart-after-terminal-state semantics needed care. First attempt used a setState guard that suppressed transitions from `.aborted`/`.finished`, which also blocked legitimate restarts ("Transmit again"). Replaced with a generation counter: each `start()` / `abort()` bumps it; callbacks check it before mutating. Stale callbacks become no-ops. Cleaner and race-safe against `DispatchClock` callbacks already in flight.
- 13 new tests, 99 total Core+Runtime tests passing. Total line coverage 98.54% (Transmitter at 97.56%).

### 2.3 Reduce-Motion clamp

- [x] 2.3.1 `AccessibilityFlags` value type (Equatable, Hashable, Sendable) with `isReduceMotionEnabled: Bool` and `maxCharacterWPM: Int` (caps at 10 if Reduce Motion is on, 20 otherwise; FR-22). `current()` static factory behind `#if canImport(UIKit)` reads `UIAccessibility.isReduceMotionEnabled`. Tests construct snapshots directly. 3 tests passing.

### 2.4 Clock (preparation for 2.2)

- [x] 2.4.1 `Clock` protocol: `nowMs: Int` and `schedule(at:_:) -> ClockSubscription` for absolute-deadline scheduling per FR-12.
- [x] 2.4.2 `DispatchClock` production impl using `DispatchSourceTimer` with `.strict` flag and absolute deadlines anchored to a single `referenceTime` captured at init. Avoids the cumulative drift of incremental sleeps.
- [x] 2.4.3 `ClockSubscription` is thread-safe and cancel-idempotent. Smoke tests verify monotonic `nowMs`, fires-near-target, cancel-prevents-fire, double-cancel-safe. (Tight jitter tolerance is FR-12's on-device measurement, not these unit tests.)

## 3. UI — SwiftUI

### 3.1 App shell

- [x] 3.1.1 `MorseBeaconApp` with single `WindowGroup` hosting `RootView`.
- [x] 3.1.2 `RootView` reads `@AppStorage("safetyAcknowledgedV1")` and shows `SafetyWarningView` when false, an `InputPlaceholderView` (replaced by `InputView` in 3.3) when true.
- [ ] 3.1.3 Inject shared `Transmitter`, `SettingsStore`, `ScreenController` into environment. *(Deferred until first consumer view needs them; 3.3 InputView will trigger this.)*

### 3.2 `SafetyWarningView`

- [x] 3.2.1 Full-screen black background, yellow `bolt.trianglebadge.exclamationmark.fill` icon, photosensitivity warning text per FR-21 (verbatim), bottom "I understand" yellow button. Dismissible only via the button — no swipe, no tap-outside.
- [x] 3.2.2 Persists ack via `@AppStorage("safetyAcknowledgedV1")`.
- [x] 3.2.3 Layout verified by booting the app in iOS Simulator and screenshotting; matches FR-21 text. Snapshot tests deferred (require iOS-only test target work).

**Implementation note.** Verified end-to-end by booting iPhone 17 Pro simulator (`xcrun simctl boot/install/launch`) and capturing the launch screenshot. Loop is: edit → `./scripts/build-ios.sh` → `simctl install/launch` → `simctl io screenshot`. Reproducible without opening Xcode.

### 3.3 `InputView`

- [x] 3.3.1 `TextEditor` (multiline) with live `"\(count) / \(maxLength)"` counter. 160-char cap enforced at typing layer via `.onChange` truncation.
- [x] 3.3.2 Live validation via `ValidatedMessage` init. Inline red error label below the editor: "Character '‘X’' at position N is not supported" (1-indexed for humans). Transmit disabled while invalid or empty. The character isn't underlined in-editor (would require AttributedString/UITextView bridging — deferred); the error label is sufficient.
- [x] 3.3.3 Bound directly to `settings.lastMessage`; SettingsStore handles UserDefaults persistence transparently.
- [x] 3.3.4 Gear icon in toolbar pushes `SettingsView` via `NavigationLink`.
- [x] 3.3.5 Transmit builds `ValidatedMessage → [TimedElement] → [ScheduleTick]` via `settings.makeTimingProfile()`, then calls `transmitter.start(schedule)` and presents `TransmissionContainerView` as a `fullScreenCover`.
- [x] 3.3.6 `accessibilityLabel` set on the message editor, character counter, gear button, and Transmit button. Transmit's `accessibilityHint` distinguishes enabled vs disabled.

**Visual verification:** screenshotted three states via `MB_LAUNCH_TO=input` — empty (placeholder, disabled button), valid ("SOS HELP" + 8/160 + enabled blue button), invalid ("HELL#O" + red error + disabled button).

### 3.4 `SettingsStore` + `SettingsView`

- [x] 3.4.0 `SettingsStore` (Runtime, not UI — LAYOUT updated). `ObservableObject` over `UserDefaults`, no SwiftUI dependency. `@Published` for timingModel, characterWPM, effectiveWPM, lastMessage. Defensive clamping on read; persistence via Combine sinks (`dropFirst()` so initial values don't write themselves back). 10 unit tests via SwiftPM cover defaults, reads, clamping, persistence round-trip, and `makeTimingProfile()` for both PARIS and Farnsworth.
- [x] 3.4.1 Picker PARIS | Farnsworth, segmented style.
- [x] 3.4.2 Character WPM slider 5–20, default 10. Reduce Motion (`@Environment(\.accessibilityReduceMotion)`) caps at 10 with explanatory caption; `enforceCaps()` runs on appear and on Reduce Motion change to clamp any out-of-range stored value. Slider's range itself is reactive.
- [x] 3.4.3 Effective WPM slider 5–charWpm, conditionally visible under Farnsworth. `.onChange(of: store.characterWPM)` clamps effectiveWPM if char drops below it.
- [x] 3.4.4 Persistence is by `SettingsStore`'s Combine sinks; views write through `@ObservedObject`.
- [x] 3.4.5 "Show safety warning again" toggles `@AppStorage("safetyAcknowledgedV1")` to false. "Reset last message" clears `store.lastMessage`; disabled when already empty.

**Visual verification:** screenshotted both PARIS and Farnsworth states via `MB_LAUNCH_TO=settings` (a new debug-only env-var route in `MorseBeaconApp` that bypasses navigation; documented in `docs/dev-workflow.md`). All controls render correctly; conditional Effective WPM section toggles.

### 3.5 `CountdownView`

- [x] 3.5.1 Large monospaced numeral (220pt), "Aim your phone" caption, "Tap anywhere to cancel" footer. Number bound to `transmitter.state`'s `.countdown(secondsLeft:)` value with `.contentTransition(.numericText(countsDown: true))` for smooth animated counting on iOS 17+. Per R3, every entry to beacon mode (including "Transmit again") goes through the countdown.
- [x] 3.5.2 Outer tap gesture on `TransmissionContainerView` calls `transmitter.abort()` during `.countdown` or `.transmitting`; on `.aborted`, the cover dismisses back to InputView via `.onChange(of: transmitter.state)`.
- [x] 3.5.3 When state advances from `.countdown` to `.transmitting`, the container view switches to `BeaconView` (currently a placeholder — full impl is 3.6). When state reaches `.finished`, switches to `FinishedView` with "Transmit again" / "Done" buttons (PRD §3.4).

**Visual verification:** `MB_LAUNCH_TO=countdown` shows the number animating from 5 down to 0 driven by the real `DispatchClock` — which means the countdown timer pipeline is live, not just static rendering. `MB_LAUNCH_TO=finished` shows the post-transmission screen with checkmark + Transmit again / Done buttons.

### 3.6 `BeaconView`

- [x] 3.6.0 Stub replaced with full implementation.
- [x] 3.6.1 `OrientationLockHost` (UIViewControllerRepresentable) wraps the BeaconView contents in a `LockingHostingController` that captures the current `interfaceOrientation` at `viewDidAppear` and overrides `supportedInterfaceOrientations` to that value. Restores `.all` on `viewWillDisappear`. Uses `requestGeometryUpdate(.iOS(...))` (iOS 16+ API; we target 17+).
- [x] 3.6.2 `BeaconView.onAppear` calls `screenController?.acquire()`; `onDisappear` calls `release()`. The `ScreenController` is injected via SwiftUI environment from `MorseBeaconApp` (single instance for the app's lifetime). `Transmitter.start` happens earlier in `InputView.startTransmission()`, not in BeaconView — BeaconView is a passive observer of `transmitter.state`.
- [x] 3.6.3 Layout per FR-9: HUD strip at the top (height = `Theme.hudStripHeight` = 88pt), 4pt black separator, flash area filling the rest. `.ignoresSafeArea()` so the flash area is true full-screen.
- [x] 3.6.4 `FlashAreaView` is `(isOn ? Color.white : Color.black)` filling all available space. No animation — sharp on/off transitions for downstream Morse decoding.
- [x] 3.6.5 HUD Line 1: source text in white monospaced 28pt, current char highlighted with `Theme.hudHighlightBackground` (amber `#FFA500`) on `Theme.hudHighlightForeground` (black). Per R4 the highlight appears only on `tick.isOn` (i.e., dit/dah, since intraGap is also off). The original task spec said "dit/dah/intraGap" should highlight; correcting per R4: intraGap also un-highlights to maintain strict lockstep with the channel state.
- [x] 3.6.6 HUD Line 2: `MorseRenderer.renderLine2(elements)` output rendered as one Text-per-column for ScrollView targeting; current column highlighted via the same amber/black palette.
- [x] 3.6.7 Auto-scroll uses `ScrollViewReader.scrollTo(id:anchor:.center)` keyed on `lastCharIndex` / `lastColumn` (the most-recent highlighted positions). Wrapped in `withTransaction(t)` with `t.disablesAnimations = true` so jumps are instant per FR-15. Per R4, viewport holds during gap ticks because `lastCharIndex` / `lastColumn` only update on `tick.isOn`.
- [x] 3.6.8 Tap-to-abort handled by parent `TransmissionContainerView`'s outer `.onTapGesture` (FR-13 — entire beacon screen aborts). AC-2's <200 ms requirement is satisfied by the abort path: synchronous state mutation, immediate dismiss via `.onChange(of: state)`.
- [x] 3.6.9 `.finished` shows `FinishedView` (already implemented in CountdownView.swift) with "Transmit again" / "Done" buttons. Brightness restored by then because `BeaconView.onDisappear` fires when the switch leaves the `.transmitting` case.
- [x] 3.6.10 Backgrounding wired in `MorseBeaconApp.body` via `transmitter.observeBackgrounding()`, token retained in `@State backgroundingToken: NSObjectProtocol?` for app lifetime. Transmitter's `abort()` triggers on `UIApplication.didEnterBackgroundNotification`; container dismisses on `.aborted`. Phone-call interruption deferred (PRD doesn't specify; AVAudioSession not yet involved since no audio channel).

**Visual verification:** screenshotted via `MB_LAUNCH_TO=beacon` (sample SOS PARIS @ 5 WPM transmission). Two screenshots 1s apart caught:
- Gap tick: HUD un-highlighted, flash area black.
- Dah tick on 'O': HUD shows amber highlight on 'O' in line 1 and on the first '−' of '−−−' in line 2; flash area pure white.

This is the entire pipeline live: DispatchClock → Transmitter callback → state.transmitting(tick) → SwiftUI onChange → HUD highlight + flash color. AC-3 (lockstep) visually verified at 1-second granularity; tighter verification needs real-device 240fps recording.

**Simulator limits:** brightness/idle-timer/orientation-lock effects can't be observed in screenshots (simulator doesn't simulate physical screen brightness). The `acquire()`/`release()` calls are wired correctly per code review; runtime verification needs a real device.

**Note on FR-12 (jitter <10 ms).** The Transmitter's `DispatchClock` uses `.strict`-flagged DispatchSourceTimers with absolute deadlines anchored to a `referenceTime` captured at clock init. Per-tick scheduling at `txStart + tick.absoluteOffsetMs` avoids cumulative drift. On-device jitter measurement (TASKS 2.2.10) still pending.

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
