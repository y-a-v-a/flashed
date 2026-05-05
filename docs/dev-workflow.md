# Development workflow

This project is intentionally set up so **you never have to open Xcode.app**
to make progress. All build, test, lint, simulator, and screenshot steps
are scripted; the entire loop runs from the command line.

This is the load-bearing design choice for working in headless / agent /
CI environments without losing fidelity vs. a normal Xcode workflow.

## Required tools

- macOS host with **Xcode 15+** installed (only the *toolchain* is
  required — the Xcode app never has to be launched).
- Command-line tools selected: `xcode-select -p` should point inside
  `Xcode.app`.
- An iOS Simulator runtime. If absent, install headlessly:
  ```sh
  xcodebuild -downloadPlatform iOS
  ```

Everything else (`swift`, `swift-format`, `swiftc`, `xcodebuild`, `simctl`,
`xcrun`) is bundled with Xcode.

## The two parallel build systems

This project deliberately uses two:

| System    | What it builds                  | Where it runs | Speed         |
|-----------|---------------------------------|---------------|---------------|
| SwiftPM   | `Core`, `Runtime` library + their tests | macOS host (no simulator) | ~300 ms full test run |
| Xcode     | The full iOS app + UI           | iOS Simulator | ~30–60 s clean, ~1 s incremental |

`Package.swift` is the single source of truth for the SwiftPM side; the
Xcode `.xcodeproj` is the single source of truth for the iOS side. The
same Swift files feed both via `path:` overrides in `Package.swift` and
explicit file refs in `project.pbxproj`. A few Runtime files use
`#if SWIFT_PACKAGE` to gate `import Core` so each build system sees the
module structure it expects.

The trade-off is that adding a new file means updating the pbxproj by
hand. The benefit is that pure-logic work (Core + Runtime) gets
sub-second feedback through `swift test`, while UI work gets verified
on real iOS via `xcodebuild`.

## Daily loop

### 1. Make changes
Edit Swift files directly. SwiftPM tests run on macOS; UI changes need
the iOS path.

### 2. Format
```sh
./scripts/format.sh
```
Runs `swift-format format -i` over every `.swift` file. Idempotent.

### 3. Run the local check suite

Fast (no simulator boot, ~3 s):
```sh
./scripts/check-all.sh
```
Runs in dependency order:
1. `check-core-purity.sh` — grep guard: `Core/` has no UIKit/SwiftUI/Combine/Dispatch/timer/runloop refs.
2. `check-screen-isolation.sh` — grep guard: only `UIKitScreenProxy.swift` touches `UIScreen.` / `UIApplication.shared.isIdleTimerDisabled`.
3. `check-format.sh` — `swift-format lint --strict` on all Swift files.
4. `swift test` — Core + Runtime unit tests on macOS (currently 99 tests).
5. `build-ios.sh` — `xcodebuild build` for `generic/platform=iOS Simulator`.

Full (boots a simulator, ~70 s):
```sh
RUN_IOS_TESTS=1 ./scripts/check-all.sh
```
Adds `test-ios.sh` (the Xcode unit-test target). Currently this is just
the placeholder test stub; it'll matter when iOS-only tests appear.

### 4. Verify visually in the simulator (UI work only)

```sh
# Boot the first available iPhone simulator
SIM=$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone ' | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/')
xcrun simctl boot "$SIM" 2>/dev/null || true

# Build, install, launch
./scripts/build-ios.sh
APP=$(find ~/Library/Developer/Xcode/DerivedData -name MorseBeacon.app -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch "$SIM" com.example.morsebeacon

# Screenshot
xcrun simctl io "$SIM" screenshot /tmp/screen.png
open /tmp/screen.png   # or just inspect the PNG
```

#### Launching directly into a specific view

`simctl` cannot synthesize touch events, so reaching nested views by
tapping is impractical. The app honours an `MB_LAUNCH_TO` environment
variable in DEBUG builds that bypasses navigation and roots a chosen
view directly:

```sh
SIMCTL_CHILD_MB_LAUNCH_TO=settings xcrun simctl launch "$SIM" com.example.morsebeacon
```

The `SIMCTL_CHILD_` prefix is required — it tells `simctl` to forward
the variable to the launched app's environment. Add new routes to
`MorseBeaconApp.swift`'s `rootView` switch as new views land.

To screenshot a view that depends on `UserDefaults` state, write the
state first via the simulator's `defaults` command:

```sh
xcrun simctl spawn "$SIM" defaults write com.example.morsebeacon \
    settings.timingModel farnsworth
```

#### Cleanup

```sh
xcrun simctl terminate "$SIM" com.example.morsebeacon
xcrun simctl shutdown "$SIM"
```

This loop is reliable enough for layout iteration. It is **not** a
substitute for interactive testing of gestures, animations, or the
flash-timing tests (PRD AC-1, AC-3) — those need a real device.

### 5. Commit

The project has a strict policy against committing root `.md` files
without explicit instruction. Stage carefully:
```sh
git add MorseBeacon MorseBeaconTests scripts ...    # never `git add -A`
```

## CI mirror

`.github/workflows/ci.yml` runs the same scripts in the same order on
`macos-15`. If `./scripts/check-all.sh` (with `RUN_IOS_TESTS=1`) passes
locally, CI will pass.

## When to actually open Xcode

There are a few things the headless flow cannot do:

- **Storyboard editing** — we don't have any.
- **Asset catalog editing** with the visual editor — current assets are
  trivial JSON manifests, edited as text.
- **Interactive debugging** with the visual debugger / view hierarchy
  inspector. `lldb` from CLI works for everything else.
- **Instruments** profiling for FR-12's <10 ms jitter measurement on a
  real device. That's a one-shot task, not a daily loop.

Otherwise, everything in this project — including writing UI, verifying
layouts, running tests, measuring coverage, formatting, linting, and
simulating end-to-end app launches — happens from the command line.
