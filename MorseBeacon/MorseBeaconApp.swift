import SwiftUI

#if SWIFT_PACKAGE
  import Runtime
#endif

@main
struct MorseBeaconApp: App {
  @StateObject private var settings = SettingsStore()
  @StateObject private var transmitter = Transmitter(clock: DispatchClock())

  var body: some Scene {
    WindowGroup {
      rootView
    }
  }

  /// Allows headless screenshot tooling to launch directly into a specific
  /// view, bypassing the safety-warning gate and any navigation. Set the
  /// `MB_LAUNCH_TO` environment variable when launching via simctl, e.g.:
  ///
  ///     SIMCTL_CHILD_MB_LAUNCH_TO=settings xcrun simctl launch <udid> com.example.morsebeacon
  ///
  /// Debug builds only. See `docs/dev-workflow.md`.
  @ViewBuilder
  private var rootView: some View {
    #if DEBUG
      switch ProcessInfo.processInfo.environment["MB_LAUNCH_TO"] {
      case "settings":
        NavigationStack { SettingsView(store: settings) }
      case "input":
        NavigationStack { InputView(settings: settings, transmitter: transmitter) }
      case "countdown":
        TransmissionContainerView(
          transmitter: previewTransmitter(state: .countdown(secondsLeft: 5)),
          onRestart: {}
        )
      case "finished":
        TransmissionContainerView(
          transmitter: previewTransmitter(state: .finished),
          onRestart: {}
        )
      default:
        RootView()
      }
    #else
      RootView()
    #endif
  }

  #if DEBUG
    /// Builds a `Transmitter` parked at a given state for visual previews.
    /// The clock is real, but we never call `start()` so no callbacks fire.
    private func previewTransmitter(state: TransmitterState) -> Transmitter {
      let tx = Transmitter(clock: DispatchClock())
      // State is private(set); reach in via reflection won't work. Instead
      // we drive the transmitter through start() and override clock to a
      // fake. For the small set of preview states we need, a simpler trick:
      // start with an empty schedule and rely on the natural transitions.
      switch state {
      case .countdown(let n):
        // Start a 5-sec countdown; the cover renders whichever count it's
        // currently at. For a static preview we want a specific number;
        // simplest: start with countdownSeconds = n, then the initial
        // state is .countdown(n).
        tx.start([], countdownSeconds: n)
      case .finished:
        tx.start([], countdownSeconds: 0)  // empty schedule transitions straight to .finished
      default:
        break
      }
      return tx
    }
  #endif
}
