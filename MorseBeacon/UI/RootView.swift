import SwiftUI

/// Top-level coordinator. First-launch users see the photosensitivity
/// warning (PRD FR-21); thereafter, straight to the input flow.
///
/// Owns the shared `SettingsStore` for the post-ack flow. Other shared
/// services (`Transmitter`, `ScreenController`) will be injected here once
/// `InputView` (3.3) and `BeaconView` (3.6) need them.
struct RootView: View {
  @AppStorage("safetyAcknowledgedV1") private var safetyAcknowledged: Bool = false
  @StateObject private var settings = SettingsStore()

  var body: some View {
    if safetyAcknowledged {
      NavigationStack {
        InputPlaceholderView(settings: settings)
      }
    } else {
      SafetyWarningView()
    }
  }
}

/// Placeholder shown after the safety acknowledgement, until `InputView`
/// (TASKS §3.3) replaces it. Wires a temporary nav link to `SettingsView`
/// so the settings UI is reachable end-to-end for verification.
private struct InputPlaceholderView: View {
  @ObservedObject var settings: SettingsStore

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
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink {
          SettingsView(store: settings)
        } label: {
          Image(systemName: "gearshape")
            .accessibilityLabel("Settings")
        }
      }
    }
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
