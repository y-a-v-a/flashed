import SwiftUI

#if SWIFT_PACKAGE
  import Core
  import Runtime
#endif

/// Message-entry screen (PRD §3 step 1, FR-1 through FR-4).
///
/// Text-editor body, live character counter, validation feedback, and a
/// Transmit button. The current message is bound to `settings.lastMessage`
/// so it persists across launches via `SettingsStore`'s UserDefaults sink
/// (FR-4).
///
/// Validation goes through `ValidatedMessage` (R2) — the single source of
/// truth for "is this a transmittable message". The Transmit button is
/// disabled whenever validation fails or the message is empty.
struct InputView: View {

  @ObservedObject var settings: SettingsStore
  @ObservedObject var transmitter: Transmitter

  @State private var presentingTransmission = false
  @FocusState private var editorFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      editor
      footer
      Spacer()
      transmitButton
    }
    .padding()
    .navigationTitle("Morse Beacon")
    .navigationBarTitleDisplayMode(.inline)
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
    .fullScreenCover(isPresented: $presentingTransmission) {
      TransmissionContainerView(
        transmitter: transmitter,
        onRestart: { startTransmission() }
      )
    }
    .onChange(of: settings.lastMessage) { _, newValue in
      // Hard-cap at 160 chars at the typing layer (FR-3). ValidatedMessage
      // would also reject longer input, but cutting at the editor is a
      // better UX than a red error label.
      if newValue.count > ValidatedMessage.maxLength {
        settings.lastMessage = String(newValue.prefix(ValidatedMessage.maxLength))
      }
    }
  }

  // MARK: - Sections

  private var header: some View {
    HStack {
      Text("Message").font(.headline)
      Spacer()
      Text("\(settings.lastMessage.count) / \(ValidatedMessage.maxLength)")
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .accessibilityLabel(
          "\(settings.lastMessage.count) of \(ValidatedMessage.maxLength) characters used")
    }
  }

  private var editor: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $settings.lastMessage)
        .focused($editorFocused)
        .frame(minHeight: 180)
        .padding(8)
        .scrollContentBackground(.hidden)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .font(.body.monospaced())
        .accessibilityLabel("Message to transmit")

      if settings.lastMessage.isEmpty {
        Text("Type your message…")
          .foregroundStyle(.tertiary)
          .padding(.top, 16)
          .padding(.leading, 14)
          .allowsHitTesting(false)
      }
    }
  }

  @ViewBuilder
  private var footer: some View {
    if let error = validationError {
      Text(message(for: error))
        .font(.callout)
        .foregroundStyle(.red)
        .accessibilityLabel("Validation error: \(message(for: error))")
    }
  }

  private var transmitButton: some View {
    Button {
      startTransmission()
    } label: {
      Text("Transmit")
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
    .buttonStyle(.borderedProminent)
    .disabled(!canTransmit)
    .accessibilityLabel("Transmit message")
    .accessibilityHint(
      canTransmit
        ? "Starts a 5-second countdown then transmits" : "Disabled — message is invalid or empty")
  }

  // MARK: - Logic

  private var validationError: ValidatedMessage.ValidationError? {
    let raw = settings.lastMessage
    guard !raw.isEmpty else { return nil }
    do {
      _ = try ValidatedMessage(raw)
      return nil
    } catch let e as ValidatedMessage.ValidationError {
      return e
    } catch {
      return nil
    }
  }

  private var canTransmit: Bool {
    !settings.lastMessage.isEmpty && validationError == nil
  }

  private func message(for error: ValidatedMessage.ValidationError) -> String {
    switch error {
    case .unsupportedCharacter(let c, let i):
      return "Character ‘\(c)’ at position \(i + 1) is not supported"
    case .tooLong(let count, let max):
      return "Too long: \(count) of \(max) characters"
    }
  }

  private func startTransmission() {
    guard let validated = try? ValidatedMessage(settings.lastMessage),
      let profile = settings.makeTimingProfile()
    else { return }

    let elements = MorseEncoder.encode(validated)
    let schedule = TransmissionSchedule.build(elements: elements, profile: profile)

    editorFocused = false
    transmitter.start(schedule)
    presentingTransmission = true
  }
}

#Preview("Empty") {
  let s = previewSettings(message: "")
  let tx = Transmitter(clock: DispatchClock())
  return NavigationStack { InputView(settings: s, transmitter: tx) }
}

#Preview("Valid SOS") {
  let s = previewSettings(message: "SOS")
  let tx = Transmitter(clock: DispatchClock())
  return NavigationStack { InputView(settings: s, transmitter: tx) }
}

#Preview("Invalid character") {
  let s = previewSettings(message: "HELL#O")
  let tx = Transmitter(clock: DispatchClock())
  return NavigationStack { InputView(settings: s, transmitter: tx) }
}

private func previewSettings(message: String) -> SettingsStore {
  let suite = "preview-\(UUID().uuidString)"
  let d = UserDefaults(suiteName: suite)!
  d.set(message, forKey: "settings.lastMessage")
  return SettingsStore(defaults: d)
}
