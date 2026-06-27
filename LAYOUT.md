# LAYOUT — Morse Beacon directory structure

Canonical on-disk tree for v1. `TASKS.md` references this file by path;
`PRD.md` §6 is the architectural sketch, this file is the implementation.

Rules the layout mechanically enforces (see `scripts/`):

1. `MorseBeacon/Core/` has no `import UIKit`, `import SwiftUI`,
   `Foundation.Timer`, `Timer(`, `NSTimer`, `DispatchQueue`, or
   `CFAbsoluteTime`. Pure Swift, `Int` milliseconds only.
2. Only `MorseBeacon/Runtime/UIKitScreenProxy.swift` references `UIScreen.`
   or `UIApplication.shared.isIdleTimerDisabled`. (Sharpened from the
   original "only ScreenController" rule during TASKS 2.1: the controller
   is now pure logic delegating to a `ScreenProxy` protocol; all UIKit
   screen-twiddling lives behind the proxy in one file.)
3. Dependency direction: `Core/` → `Runtime/` → `UI/`. Never the reverse.
4. Xcode groups mirror folders 1:1. No "group without folder" tricks.

## Tree

```
flashed/                                    (repo root)
├── README.md
├── PRD.md
├── CLAUDE.md
├── TASKS.md
├── LAYOUT.md                               (this file)
├── .gitignore
├── .swift-format
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── MorseBeacon.xcodeproj/
│
├── MorseBeacon/                            (app target sources)
│   ├── MorseBeaconApp.swift                (@main)
│   ├── Info.plist                          (explicit, not generated)
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/
│   │   └── AccentColor.colorset/
│   ├── PreviewContent/
│   │   └── Preview Assets.xcassets/        (preview-only; excluded from release)
│   │
│   ├── Core/                               (PURE SWIFT)
│   │   ├── MorseSymbol.swift
│   │   ├── MorseTable.swift                (table + supports(_:))
│   │   ├── ValidatedMessage.swift          (R2)
│   │   ├── ElementKind.swift
│   │   ├── TimedElement.swift
│   │   ├── MorseEncoder.swift              (total: ValidatedMessage → [TimedElement])
│   │   ├── TimingProfile.swift             (.paris / .farnsworth)
│   │   ├── ScheduleTick.swift              (offset + durationMs + isOn + indices — R1)
│   │   ├── TransmissionSchedule.swift      (build + totalDurationMs)
│   │   └── MorseRenderer.swift             (HUD string + element→column map)
│   │
│   ├── Runtime/                            (device bindings)
│   │   ├── ScreenProxy.swift               (protocol, pure Swift)
│   │   ├── ScreenController.swift          (save/set/restore logic, pure Swift)
│   │   ├── UIKitScreenProxy.swift          (SOLE owner of UIScreen / UIApplication.shared.isIdleTimerDisabled)
│   │   ├── Transmitter.swift               (ObservableObject, DispatchSourceTimer)
│   │   ├── TransmitterState.swift
│   │   ├── Clock.swift                     (protocol + DispatchClock impl)
│   │   ├── AccessibilityFlags.swift        (Reduce Motion cap — FR-22)
│   │   └── SettingsStore.swift             (ObservableObject over UserDefaults)
│   │
│   └── UI/                                 (SwiftUI)
│       ├── RootView.swift                  (SafetyWarning → Input coordinator; env injection)
│       ├── SafetyWarningView.swift
│       ├── InputView.swift
│       ├── SettingsView.swift
│       ├── CountdownView.swift
│       ├── BeaconView.swift
│       ├── HUDStripView.swift
│       ├── FlashAreaView.swift
│       ├── OrientationLockHost.swift       (UIViewControllerRepresentable)
│       └── Theme.swift                     (#FFA500 amber, fonts, spacings)
│
├── MorseBeaconTests/
│   ├── Core/
│   │   ├── MorseTableTests.swift
│   │   ├── ValidatedMessageTests.swift
│   │   ├── MorseEncoderTests.swift
│   │   ├── TimingProfileTests.swift
│   │   ├── TransmissionScheduleTests.swift
│   │   └── MorseRendererTests.swift
│   ├── Runtime/
│   │   ├── ScreenControllerTests.swift     (uses ScreenProxy fake)
│   │   └── TransmitterTests.swift          (uses fake Clock + fake timer)
│   └── Fixtures/
│       └── KnownMorse.swift                (SOS, PARIS, etc. — shared golden values)
│
├── MorseBeaconUITests/                     (stub target; no tests until an AC demands one)
│   └── .gitkeep
│
├── scripts/
│   ├── check-core-purity.sh
│   └── check-screen-isolation.sh
│
└── docs/
    ├── timing.md
    └── ac1-measurement.md
```

## File placement decisions (locked)

- **`OrientationLockHost` in `UI/`, not `Runtime/`.** It's a UIKit bridge
  whose purpose is purely presentational. `Runtime/` is for device-state
  side effects.
- **`SettingsStore` in `Runtime/`, not `UI/` or `Core/`.** Earlier draft
  placed it in `UI/` reasoning that persistence is a UI concern. On
  reflection, `SettingsStore` is a pure `ObservableObject` over `UserDefaults`
  with no SwiftUI dependency — the views observe it but it doesn't import
  SwiftUI. Putting it in `Runtime/` lets `swift test` cover it without
  pulling SwiftUI into the SwiftPM build, and matches the rule that
  `Runtime/` owns platform I/O (which `UserDefaults` is).
- **Test fixtures in `MorseBeaconTests/Fixtures/`, named concretely**
  (`KnownMorse.swift`), never `TestHelpers.swift`.
- **Previews inline** in each view's `.swift` file via `#Preview`. No
  separate `Previews/` folder. `PreviewContent/` is only for preview-only
  asset catalogs, per Xcode convention.
- **Project at repo root**, not in an `App/` subdir. If `Core/` is later
  extracted as SwiftPM (TASKS 0.7), it goes at `Core-Package/` and
  `MorseBeacon/Core/` is deleted at that point.

## Not present in v1 (add only when justified)

- `Core-Package/` — deferred per TASKS 0.7.
- `Runtime/Emitters/HapticEmitter.swift`, `Runtime/Emitters/AudioEmitter.swift`
  — Phase 2/3.
- `Resources/`, `Localizable.strings` — no localization in v1.
- Fastlane, Mint, SwiftLint, or any other tooling. Per CLAUDE.md: no
  dependencies.

## When this file changes

Any addition of a new top-level folder, or movement of a file across
`Core`/`Runtime`/`UI`, is a design change and requires updating this file
in the same commit. CLAUDE.md's "Things to ask before doing" rule applies:
ask before adding a file outside the sketched directories.
