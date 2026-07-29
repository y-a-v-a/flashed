# Morse Beacon

> Turn an iPhone into a signal lamp. Type a message, aim the phone, and the
> screen flashes it in International Morse code at full brightness — accurately
> enough that a person on the other end can read it back.

**iOS 17+ · Swift 5.9 / SwiftUI · transmit-only · no network, no accounts, no telemetry.**

> [!WARNING]
> **Photosensitivity.** This app produces rapid flashing light that may trigger
> seizures in people with photosensitive epilepsy. Do not use it if you, or
> anyone who can see the screen, is affected. The app gates first launch behind
> an explicit acknowledgement and caps the flash rate when *Reduce Motion* is on
> — but the responsibility to use it safely is the operator's.

---

## Why this exists

A phone screen is a bright, finely controllable light source almost everyone
already carries. Morse code is the oldest protocol for turning a light on and
off into language. Put the two together and a modern phone becomes a **semaphore
lamp** — a way to signal another human across a distance with nothing but
line-of-sight and a shared, century-old code.

The use case is deliberately narrow: **night-time, line-of-sight signaling
between people**. Two hikers on opposing ridges. A boat and a shore. A window
and a street. Anywhere a steady flashing light carries further and reads cleaner
than a shout. The inspiration is the Apple Watch flashlight's search-light mode —
this takes that idea and gives it grammar.

Two principles fall out of that goal and shape everything else:

- **It is an emitter, not a transceiver.** The app does not listen, decode, or
  record — there is no camera, no microphone, no history. A beacon you can trust
  is a beacon that obviously *cannot* be doing anything else. That single
  decision is why there is no network code, no permissions prompt, and nothing
  to sign in to.

- **The timing is the product.** A flashing screen is only useful if a human can
  *decode* it. That means the gap between two dits has to be reliably shorter
  than the gap between two letters, every time, regardless of what the UI is
  doing. Everything in the architecture below exists to protect that one
  property.

This is v1: optical only. The same engine is designed to drive **haptic** and
**audio** channels next *without* a rewrite — the reasoning is in
[How it works](#how-it-works) and the plan in [Roadmap](#roadmap).

## How it works

The product *is* a timing engine with a flashlight bolted on. The codebase is
organised so the engine can be reasoned about and tested in complete isolation
from the phone.

```
Core/      pure Swift — the Morse engine. No UIKit, no SwiftUI, no Timer, no clock.
  ↓        Durations are Int milliseconds. Deterministic. Trivially unit-testable.
Runtime/   device bindings — the real clock, the screen, app lifecycle.
  ↓        Turns the engine's abstract schedule into pixels at the right moments.
UI/        SwiftUI — observes Runtime, renders. Owns no timing of its own.
```

Dependencies only point inward. `Core/` knows nothing about the layers around
it. A grep script ([`check-core-purity.sh`](scripts/check-core-purity.sh))
fails the build if a forbidden import ever leaks in. This isn't dogma — it's
what makes the timing testable without a simulator, and portable to the future
channels.

Four design decisions carry the whole thing:

**1. The schedule is channel-agnostic.**
`Core/` encodes a message into a flat stream of `ScheduleTick`s. A tick is a
*span*, not an edge: it says "the channel is **on** from millisecond X for Y
milliseconds," and nothing about *what* "on" means. The optical flash is just
one subscriber that paints white when a tick is on. A haptic buzz or an audio
tone are other subscribers to the same stream. Because a tick is fully
self-describing, no emitter ever has to peek at the next tick to know when the
current one ends — which is exactly the property the future haptic/audio
channels depend on.

**2. Scheduling is absolute, never incremental.**
The transmitter computes each flip's wall-clock deadline as
`t₀ + cumulative_units × unit_duration` and arms a `DispatchSourceTimer` with
the `.strict` flag for it. It never says "sleep for one dit, then sleep for
another." Incremental sleeps accumulate drift; under UI load that drift is the
difference between a readable message and gibberish. Absolute deadlines anchored
to a single reference time keep per-flash jitter inside the target of <10 ms.
This is also why `Core/` is forbidden from importing `Timer` — the clock is
injected, so tests run the entire schedule in synchronous *virtual* time and
assert exact millisecond offsets.

**3. Timing accuracy is a test invariant, not an aspiration.**
Morse speed is defined by convention: the word `PARIS ` (with the trailing
space) is exactly **50 dit-units**, so "20 WPM" means 1000 units per minute and
one dit = `1200 / wpm` ms. The test suite pins this directly — encoding
`"PARIS "` at 20 WPM must total **3000 ms** to the millisecond. Any change to
the timing code that breaks that number breaks the build. The app supports both
the standard **PARIS** model and the **Farnsworth** model (full-speed characters
with stretched gaps, for learners), and Farnsworth is proven to reduce *exactly*
to PARIS when the two speeds are equal.

**4. Invalid input is unrepresentable downstream.**
The only way to get a message into the engine is to construct a
`ValidatedMessage`, whose initializer rejects any unsupported character and
reports the offending index. Past that boundary the encoder is *total* — it
cannot fail, has no error path, and needs no defensive checks. The UI builds a
`ValidatedMessage` as you type, so the "Transmit" button is simply disabled
until what you have is something the engine can guarantee it can send.

The single source of truth for playback state is one object, `Transmitter`. It
publishes its state; views *observe* it. No view runs its own timer. When you
tap to abort, one synchronous state change unwinds everything — and a generation
counter makes any timer callback still in flight from the old run a harmless
no-op. Brightness and the idle timer are touched through exactly one file
(`UIKitScreenProxy`); `ScreenController` snapshots them when the beacon appears
and restores them when it leaves, so the app can never walk away leaving your
screen pinned at full brightness.

For the full reasoning — the Farnsworth algebra, the 50-unit proof, the jitter
strategy — see [`docs/timing.md`](docs/timing.md). For the layer rules, see
[`CLAUDE.md`](CLAUDE.md) and [`LAYOUT.md`](LAYOUT.md). For requirements and
acceptance criteria, [`PRD.md`](PRD.md). For a plain-language one-pager to
hand to a non-developer — what the app is and does, no code — open
[`docs/explainer.html`](docs/explainer.html) in a browser (or host it
anywhere; it's a single self-contained file).

## How to use it

1. **Acknowledge the safety warning** (first launch only).
2. **Type a message** — up to 160 characters (see [`PRD.md`](PRD.md) for the
   exact supported set). Inline validation flags the first unsupported character
   and keeps *Transmit* disabled until the message is something the engine can
   guarantee it can send. Your last message is remembered between launches.
3. **Tap Transmit** → a **5-second countdown** gives you time to aim the phone
   and warn bystanders. Tap anywhere to cancel.
4. **Aim.** The screen splits: a dim, non-flashing HUD strip at the top shows
   your text and its Morse with a highlight that moves in lockstep with the
   flash; the rest of the screen is the beacon, snapping between pure black and
   pure white. Orientation locks so it won't rotate mid-message.
5. **Tap anywhere to abort** — instantly, anywhere on screen. When the message
   finishes, "Transmit again" repeats it or "Done" returns you to input, with
   your original brightness restored.

Speed and model live in **Settings** (gear icon): PARIS or Farnsworth, character
WPM 5–20, and a Farnsworth effective-WPM slider. With *Reduce Motion* enabled,
the maximum speed is capped at 10 WPM for a gentler flash.

Screenshots of all five screens (safety gate, input, settings, countdown,
beacon) can be regenerated headlessly at any time with
`./scripts/take-screenshots.sh`. They are deliberately not committed —
status-bar clocks and other ephemera would churn every commit; the script
is the artefact.

## Build, test, verify

No third-party dependencies — Apple frameworks only. Requires **Xcode 15 or
newer** (iOS 17 SDK, Swift 5.9); there is nothing else to install.

```bash
# Fast loop — Core *and* Runtime in synchronous virtual time, no simulator (~0.3s).
# This is the payoff of the injected clock (How it works #2): the entire schedule
# runs and is asserted to the millisecond without a device in the loop.
swift test

# Build and test the full app. These scripts auto-detect an installed simulator;
# the raw xcodebuild form is shown only for reference.
./scripts/build-ios.sh
./scripts/test-ios.sh
xcodebuild -scheme MorseBeacon -destination 'platform=iOS Simulator,name=iPhone 17' test
# ^ substitute any device from `xcrun simctl list devices available`

# Run every CI gate at once: purity → isolation → network-free → format → tests → build
./scripts/check-all.sh
```

To run the app interactively, open `MorseBeacon.xcodeproj` in Xcode and run the
`MorseBeacon` scheme (⌘R). The `Core/` engine also has a SwiftPM manifest at the
repo root so `swift test` can exercise it — and `Runtime`, in virtual time —
without an Xcode project at all. That's the loop you live in while changing the
engine.

The architecture rules in [`CLAUDE.md`](CLAUDE.md) are not honour-system: each is
an executable gate that fails [CI](.github/workflows/ci.yml), so the boundaries
can't quietly erode.

| Gate (enforced in CI) | What it guarantees |
|---|---|
| `check-core-purity.sh` | `Core/` imports no UIKit/SwiftUI/`Timer`/`Dispatch` |
| `check-screen-isolation.sh` | only `UIKitScreenProxy` touches brightness / idle timer |
| `check-no-network.sh` | no networking primitive anywhere in the app target |
| `check-format.sh` | `swift-format lint --strict` is clean |
| `swift test` + `build-ios.sh` | the 109-test suite passes; the app compiles for the simulator |

Two further scripts are run **manually** (not in CI): `measure-core-coverage.sh`
reports `Core/` line coverage — ~97% against a ≥90% target, see
[`docs/coverage.md`](docs/coverage.md) — and `measure-binary-size.sh` reports the
release binary size, ~1.9 MB against a <5 MB target.

> [!NOTE]
> Some properties can only be confirmed on real hardware — actual screen
> brightness, the orientation lock, per-flash timing jitter under load, and
> clean abort on backgrounding. The Simulator can't reproduce them. The
> on-device sign-off procedure lives in
> [`docs/on-device-checklist.md`](docs/on-device-checklist.md).

## Put it on your phone — no App Store needed

There is no App Store listing, and none is required: Apple lets you install
your own build on your own iPhone with a free Apple ID. In short — open
`MorseBeacon.xcodeproj`, set your team and a unique bundle ID under
**Signing & Capabilities**, plug in the phone, **⌘R**. Or headlessly:

```bash
TEAM_ID=ABCDE12345 BUNDLE_ID=com.you.morsebeacon ./scripts/install-on-device.sh
```

One-time device setup (Developer Mode, trusting the certificate), the
free-tier fine print (7-day signature, three sideloaded apps), and the
options for giving the app to someone else are all in
[`docs/install-on-device.md`](docs/install-on-device.md).

## Known constraints

These are physics and OS behaviour, not bugs — document, don't fight them:

- **Auto-Brightness** (Settings → Accessibility → Display) can pull brightness
  back down while the beacon runs. iOS gives no API to disable it; turn it off
  manually for maximum range.
- **True Tone** and **Night Shift** warm the screen's white point. We can't
  disable them programmatically; the beacon still works, the white is just
  slightly less cold.
- **Low-power mode / thermal throttling** can override a requested brightness of
  1.0. The app asks for full brightness; the system has the last word.
- The flash area is **pure black/white with no animation** — sharp edges are
  what make it decodable; a fade would smear dit and dah together.

## Roadmap

Both ride the same channel-agnostic schedule (How it works #1) — they are new
*emitters*, not new engines:

- **Phase 2 — Haptic.** Press the phone against a rigid conductor (a pipe, a
  wall stud, a door) and the Taptic Engine couples Morse into the structure.
  This signals *through* walls and floors, and works where light is unwanted
  (covert) or useless (fog, daylight).
- **Phase 3 — Audio.** A pure 600–800 Hz sidetone through the speaker carries
  Morse across open air, and doubles as a sensory-substitute output for people
  who'd rather hear than watch. Loud and overt where haptic is silent.

A watchOS companion, message history, and prosigns are explicitly out of scope.
The full phased spec is in [`PRD.md`](PRD.md) §10–11.

## How this was built

Morse Beacon was built **spec-first**: [`PRD.md`](PRD.md) and
[`CLAUDE.md`](CLAUDE.md) were written before any code, and the implementation
was driven task-by-task from [`TASKS.md`](TASKS.md) — tests before code for
every `Core/` behaviour, one committed task at a time. Much of that
implementation work was done in pair with the **[pi](https://github.com/y-a-v-a)
coding agent**, working through the task list under the architecture and style
rules in `CLAUDE.md`. The result is a small codebase where the *reasoning*
behind each decision is written down next to it — which is the point.

## Standards & references

- **ITU-R M.1677-1** — International Morse code timing specification.
- **PARIS timing** — dit = `1200 / WPM` ms; `PARIS ` = 50 units.
- **Jon Bloom, "The Farnsworth Method"** (ARRL, 1990) — slow-rate, crisp-character timing.

## License

Released under the **MIT License** — see [`LICENSE`](LICENSE). In short: use,
fork, and build on it freely; keep the copyright notice; no warranty.

---

## Author

© 2026 Vincent Bruijn · [vincentbruijn.nl](https://vincentbruijn.nl) · [info@vincentbruijn.nl](mailto:info@vincentbruijn.nl)
