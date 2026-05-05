import SwiftUI

#if SWIFT_PACKAGE
  import Runtime
#endif

/// Top-level coordinator. First-launch users see the photosensitivity
/// warning (PRD FR-21); thereafter, the input flow.
///
/// Owns the shared `SettingsStore` and `Transmitter`. ScreenController is
/// added later when `BeaconView` lands (3.6).
struct RootView: View {
  @AppStorage("safetyAcknowledgedV1") private var safetyAcknowledged: Bool = false
  @StateObject private var settings = SettingsStore()
  @StateObject private var transmitter = Transmitter(clock: DispatchClock())

  var body: some View {
    if safetyAcknowledged {
      NavigationStack {
        InputView(settings: settings, transmitter: transmitter)
      }
    } else {
      SafetyWarningView()
    }
  }
}

#Preview("Safety not acknowledged") {
  UserDefaults.standard.removeObject(forKey: "safetyAcknowledgedV1")
  return RootView()
}

#Preview("Safety acknowledged") {
  UserDefaults.standard.set(true, forKey: "safetyAcknowledgedV1")
  return RootView()
}
