import SwiftUI

#if SWIFT_PACKAGE
  import Runtime
#endif

/// Top-level coordinator. First-launch users see the photosensitivity
/// warning (PRD FR-21); thereafter, the input flow.
///
/// The shared `SettingsStore` and `Transmitter` are owned by
/// `MorseBeaconApp` and passed in — there is exactly one `Transmitter`,
/// so the app-level backgrounding observer (AC-5) aborts the same
/// instance the UI drives. Held as plain `let`s: this view reads no
/// published state itself; `InputView` observes them.
struct RootView: View {
  @AppStorage("safetyAcknowledgedV1") private var safetyAcknowledged: Bool = false
  let settings: SettingsStore
  let transmitter: Transmitter

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
  return RootView(settings: SettingsStore(), transmitter: Transmitter(clock: DispatchClock()))
}

#Preview("Safety acknowledged") {
  UserDefaults.standard.set(true, forKey: "safetyAcknowledgedV1")
  return RootView(settings: SettingsStore(), transmitter: Transmitter(clock: DispatchClock()))
}
