import SwiftUI

#if SWIFT_PACKAGE
  import Core
  import Runtime
#endif

@main
struct MorseBeaconApp: App {
  /// Single app-wide instances, passed down to `RootView`. The
  /// backgrounding observer below aborts `transmitter`, so the UI must
  /// drive this same instance for AC-5 to hold.
  @StateObject private var settings = SettingsStore()
  @StateObject private var transmitter = Transmitter(clock: DispatchClock())

  /// The single `ScreenController` for the whole app. iOS-only, backed by
  /// `UIKitScreenProxy`. Held as a stored property (not @StateObject) since
  /// it isn't observable; reference identity is stable across renders.
  private let screenController = ScreenController(proxy: UIKitScreenProxy())

  /// Token retaining the backgrounding observer for the lifetime of the
  /// app. Releasing it removes the observer; we never do.
  @State private var backgroundingToken: NSObjectProtocol?

  var body: some Scene {
    WindowGroup {
      rootView
        .environment(\.screenController, screenController)
        .onAppear {
          if backgroundingToken == nil {
            backgroundingToken = transmitter.observeBackgrounding()
          }
        }
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
      case "about":
        NavigationStack { AboutView() }
      case "input":
        NavigationStack { InputView(settings: settings, transmitter: transmitter) }
      case "countdown":
        TransmissionContainerView(
          transmitter: previewTransmitter(state: .countdown(secondsLeft: 5)),
          session: previewSession(message: "SOS"),
          onRestart: {}
        )
      case "beacon":
        let session = previewSession(message: "SOS PARIS")
        TransmissionContainerView(
          transmitter: beaconPreviewTransmitter(session: session),
          session: session,
          onRestart: {}
        )
      case "finished":
        TransmissionContainerView(
          transmitter: previewTransmitter(state: .finished),
          session: previewSession(message: "SOS"),
          onRestart: {}
        )
      default:
        RootView(settings: settings, transmitter: transmitter)
      }
    #else
      RootView(settings: settings, transmitter: transmitter)
    #endif
  }

  #if DEBUG
    /// Starts a real transmission with the given session at countdown=0
    /// so it begins transmitting immediately. The slow PARIS@5 schedule
    /// keeps it in `.transmitting` long enough to screenshot.
    private func beaconPreviewTransmitter(session: TransmissionSession) -> Transmitter {
      let tx = Transmitter(clock: DispatchClock())
      tx.start(session.schedule, countdownSeconds: 0)
      return tx
    }

    /// Builds a `Transmitter` parked at a given state for visual previews.
    private func previewTransmitter(state: TransmitterState) -> Transmitter {
      let tx = Transmitter(clock: DispatchClock())
      switch state {
      case .countdown(let n):
        tx.start([], countdownSeconds: n)
      case .finished:
        tx.start([], countdownSeconds: 0)
      default:
        break
      }
      return tx
    }

    /// Builds a TransmissionSession with the given message text. Used by
    /// MB_LAUNCH_TO routes that need a session to thread through the
    /// container. Uses 5 WPM so the transmission lasts long enough to
    /// screenshot mid-flight (PARIS "SOS" at 5 WPM ≈ 6.5 s).
    private func previewSession(message: String) -> TransmissionSession {
      guard let validated = try? ValidatedMessage(message) else {
        return TransmissionSession(message: "", elements: [], schedule: [])
      }
      let elements = MorseEncoder.encode(validated)
      let schedule = TransmissionSchedule.build(elements: elements, profile: .paris(wpm: 5))
      return TransmissionSession(
        message: validated.asString, elements: elements, schedule: schedule)
    }
  #endif
}
