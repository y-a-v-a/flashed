import SwiftUI

/// Top-level coordinator. First-launch users see the photosensitivity
/// warning (PRD FR-21); thereafter, straight to the input flow.
///
/// Environment injection (Transmitter, SettingsStore, ScreenController) will
/// land here as those types' consumer views are implemented.
struct RootView: View {
  @AppStorage("safetyAcknowledgedV1") private var safetyAcknowledged: Bool = false

  var body: some View {
    if safetyAcknowledged {
      InputPlaceholderView()
    } else {
      SafetyWarningView()
    }
  }
}

/// Placeholder shown after the safety acknowledgement, until `InputView`
/// (TASKS §3.3) replaces it.
private struct InputPlaceholderView: View {
  var body: some View {
    VStack(spacing: 16) {
      Text("Morse Beacon")
        .font(.largeTitle)
        .fontDesign(.monospaced)
      Text("Input view pending — TASKS §3.3")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding()
  }
}

#Preview("Safety not acknowledged") {
  // Wipe the @AppStorage flag so previews always show the warning first
  // until acknowledged within the preview session.
  UserDefaults.standard.removeObject(forKey: "safetyAcknowledgedV1")
  return RootView()
}

#Preview("Safety acknowledged") {
  UserDefaults.standard.set(true, forKey: "safetyAcknowledgedV1")
  return RootView()
}
