import SwiftUI

/// App credits and version info. Reachable via a row in `SettingsView`.
///
/// All values are static or read from the bundle; no network, no telemetry,
/// no user data displayed (NFR-2).
struct AboutView: View {

  var body: some View {
    Form {
      titleSection
      descriptionSection
      contactSection
      standardsSection
    }
    .navigationTitle("About")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Sections

  private var titleSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 4) {
        Text("Morse Beacon")
          .font(.title2)
          .fontWeight(.semibold)
          .fontDesign(.monospaced)
        Text("Version \(versionString) (build \(buildString))")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      .padding(.vertical, 4)
    }
  }

  private var descriptionSection: some View {
    Section("What this is") {
      Text(
        "A transmit-only optical Morse beacon for line-of-sight signaling. "
          + "Type a message; the screen flashes it in International Morse Code "
          + "at full brightness."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
    }
  }

  private var contactSection: some View {
    Section("Author") {
      LabeledContent("Name", value: "Vincent Bruijn")
      if let mailURL = URL(string: "mailto:info@vincentbruijn.nl") {
        Link(destination: mailURL) {
          LabeledContent("Email") {
            Text("info@vincentbruijn.nl")
              .foregroundStyle(.tint)
          }
        }
        .accessibilityHint("Opens Mail to contact the author.")
      }
    }
  }

  private var standardsSection: some View {
    Section("Standards") {
      Text(
        "Morse encoding follows ITU-R M.1677-1. "
          + "Timing uses the PARIS standard (1 WPM = ‘PARIS ’ per minute) and "
          + "Bloom’s Farnsworth method for slow-character / fast-element transmission."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - Bundle reads

  private var versionString: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
  }

  private var buildString: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
  }
}

#Preview {
  NavigationStack { AboutView() }
}
