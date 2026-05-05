import SwiftUI

/// First-launch photosensitivity warning. Required by PRD FR-21.
///
/// Shown full-screen on first launch (and never again, gated by the
/// `safetyAcknowledgedV1` `@AppStorage` key). Dismissible only via the
/// explicit "I understand" button — no swipe-to-dismiss, no tap-outside.
struct SafetyWarningView: View {
  @AppStorage("safetyAcknowledgedV1") private var acknowledged: Bool = false

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      VStack(spacing: 28) {
        Spacer()

        Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
          .font(.system(size: 64))
          .foregroundStyle(.yellow)
          .accessibilityHidden(true)

        Text("Photosensitivity warning")
          .font(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)

        Text(
          """
          This app produces rapid flashing light that may trigger seizures in \
          people with photosensitive epilepsy.

          Do not use if you or anyone nearby is affected.
          """
        )
        .font(.body)
        .multilineTextAlignment(.center)

        Spacer()

        Button {
          acknowledged = true
        } label: {
          Text("I understand")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.yellow)
        .foregroundStyle(.black)
        .accessibilityHint("Dismisses this warning and proceeds to the app.")
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 32)
      .padding(.bottom, 24)
    }
  }
}

#Preview {
  SafetyWarningView()
}
