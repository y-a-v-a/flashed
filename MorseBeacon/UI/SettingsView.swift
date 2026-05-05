import SwiftUI

/// Settings screen — PRD §4.5, FR-17 through FR-20.
///
/// Reads/writes through `SettingsStore`. Reduce Motion (FR-22) caps the
/// character WPM at 10; this view enforces that visually (slider range)
/// and clamps the stored value on appear if a previous session left it
/// higher.
struct SettingsView: View {

  @ObservedObject var store: SettingsStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("safetyAcknowledgedV1") private var safetyAcknowledged: Bool = false

  var body: some View {
    Form {
      timingModelSection
      characterWPMSection
      if store.timingModel == .farnsworth {
        effectiveWPMSection
      }
      maintenanceSection
    }
    .navigationTitle("Settings")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink {
          AboutView()
        } label: {
          Image(systemName: "info.circle")
            .accessibilityLabel("About Morse Beacon")
        }
      }
    }
    .onAppear {
      enforceCaps()
    }
    .onChange(of: reduceMotion) { _, _ in
      enforceCaps()
    }
    .onChange(of: store.characterWPM) { _, newCharWPM in
      // Effective WPM cannot exceed character WPM (FR-19, Farnsworth defn).
      if store.effectiveWPM > newCharWPM {
        store.effectiveWPM = newCharWPM
      }
    }
  }

  // MARK: - Sections

  private var timingModelSection: some View {
    Section("Timing model") {
      Picker("Model", selection: $store.timingModel) {
        Text("PARIS").tag(SettingsStore.TimingModel.paris)
        Text("Farnsworth").tag(SettingsStore.TimingModel.farnsworth)
      }
      .pickerStyle(.segmented)
    }
  }

  private var characterWPMSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Character WPM").bold()
          Spacer()
          Text("\(store.characterWPM)")
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        Slider(
          value: doubleBinding(for: $store.characterWPM),
          in: 5.0...Double(maxCharacterWPM),
          step: 1
        )
        .accessibilityValue("\(store.characterWPM) words per minute")
        if reduceMotion {
          Text("Capped at 10 WPM because Reduce Motion is on.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    } footer: {
      Text("Speed of dits and dahs. Higher is faster.")
    }
  }

  private var effectiveWPMSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Effective WPM").bold()
          Spacer()
          Text("\(store.effectiveWPM)")
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        Slider(
          value: doubleBinding(for: $store.effectiveWPM),
          in: 5.0...Double(max(5, store.characterWPM)),
          step: 1
        )
        .accessibilityValue("\(store.effectiveWPM) words per minute")
      }
    } header: {
      Text("Farnsworth")
    } footer: {
      Text(
        "Stretches gaps between characters and words so the overall rate matches "
          + "the slower target while individual characters stay crisp.")
    }
  }

  private var maintenanceSection: some View {
    Section {
      Button("Show safety warning again") {
        safetyAcknowledged = false
      }
      Button("Reset last message", role: .destructive) {
        store.lastMessage = ""
      }
      .disabled(store.lastMessage.isEmpty)
    }
  }

  // MARK: - Helpers

  private var maxCharacterWPM: Int {
    reduceMotion ? 10 : 20
  }

  private func enforceCaps() {
    if store.characterWPM > maxCharacterWPM {
      store.characterWPM = maxCharacterWPM
    }
    if store.effectiveWPM > store.characterWPM {
      store.effectiveWPM = store.characterWPM
    }
  }

  private func doubleBinding(for source: Binding<Int>) -> Binding<Double> {
    Binding(
      get: { Double(source.wrappedValue) },
      set: { source.wrappedValue = Int($0.rounded()) }
    )
  }
}

#Preview("PARIS") {
  let store = SettingsStore(defaults: previewDefaults(timingModel: "paris"))
  return NavigationStack { SettingsView(store: store) }
}

#Preview("Farnsworth") {
  let store = SettingsStore(defaults: previewDefaults(timingModel: "farnsworth"))
  return NavigationStack { SettingsView(store: store) }
}

private func previewDefaults(timingModel: String) -> UserDefaults {
  let suite = "preview-\(UUID().uuidString)"
  let d = UserDefaults(suiteName: suite)!
  d.set(timingModel, forKey: "settings.timingModel")
  d.set(15, forKey: "settings.characterWPM")
  d.set(8, forKey: "settings.effectiveWPM")
  return d
}
