import SwiftUI

@main
struct MorseBeaconApp: App {
  @StateObject private var settings = SettingsStore()

  var body: some Scene {
    WindowGroup {
      rootView
    }
  }

  /// Allows headless screenshot tooling to launch directly into a specific
  /// view, bypassing the safety-warning gate and any navigation. Set the
  /// `MB_LAUNCH_TO` environment variable when launching via simctl, e.g.:
  ///
  ///     xcrun simctl launch <udid> com.example.morsebeacon \
  ///         --console-pty \
  ///         MB_LAUNCH_TO=settings
  ///
  /// Debug builds only. See `docs/dev-workflow.md`.
  @ViewBuilder
  private var rootView: some View {
    #if DEBUG
      switch ProcessInfo.processInfo.environment["MB_LAUNCH_TO"] {
      case "settings":
        NavigationStack { SettingsView(store: settings) }
      default:
        RootView()
      }
    #else
      RootView()
    #endif
  }
}
