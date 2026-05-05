import SwiftUI

#if SWIFT_PACKAGE
  import Runtime
#endif

/// 5-second countdown before transmission (PRD §3 step 2, FR per user flow).
///
/// Renders whichever `secondsLeft` value the `Transmitter` is currently
/// publishing — the view is a thin observer; the timer is the Transmitter's
/// `DispatchClock`. "Tap anywhere to cancel" is enforced by
/// `TransmissionContainerView`'s outer tap gesture, so this view itself
/// just renders.
struct CountdownView: View {
  let secondsLeft: Int

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      Text("\(max(secondsLeft, 0))")
        .font(.system(size: 220, weight: .bold, design: .monospaced))
        .foregroundStyle(.white)
        .contentTransition(.numericText(countsDown: true))
        .accessibilityLabel("\(secondsLeft) seconds remaining")
      Text("Aim your phone")
        .font(.title3)
        .foregroundStyle(.white.opacity(0.7))
      Spacer()
      Text("Tap anywhere to cancel")
        .font(.callout)
        .foregroundStyle(.white.opacity(0.5))
        .padding(.bottom, 32)
    }
  }
}

/// Switches between countdown / beacon / finished views based on the
/// `Transmitter`'s state. Owns the "tap anywhere to abort" gesture and the
/// auto-dismiss-on-aborted behavior. Presented as `fullScreenCover` from
/// `InputView`.
struct TransmissionContainerView: View {
  @ObservedObject var transmitter: Transmitter
  let session: TransmissionSession
  let onRestart: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      switch transmitter.state {
      case .idle, .aborted:
        // Empty until either the parent advances state or the
        // .aborted onChange fires the dismiss below.
        Color.clear
      case .countdown(let n):
        CountdownView(secondsLeft: n)
      case .transmitting(let tick):
        BeaconView(session: session, tick: tick)
      case .finished:
        FinishedView(onDone: { dismiss() }, onAgain: onRestart)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      switch transmitter.state {
      case .countdown, .transmitting:
        transmitter.abort()
      case .idle, .finished, .aborted:
        break  // .finished has its own buttons; let them handle the tap.
      }
    }
    .onChange(of: transmitter.state) { _, newState in
      if case .aborted = newState {
        dismiss()
      }
    }
  }
}

/// Post-transmission summary: "Done" / "Transmit again" buttons (PRD §3.4).
private struct FinishedView: View {
  let onDone: () -> Void
  let onAgain: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 80))
        .foregroundStyle(.green)
        .accessibilityHidden(true)
      Text("Transmission complete")
        .font(.title2)
        .foregroundStyle(.white)
      Spacer()
      VStack(spacing: 12) {
        Button(action: onAgain) {
          Text("Transmit again")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .foregroundStyle(.black)

        Button(action: onDone) {
          Text("Done")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .tint(.white)
        .foregroundStyle(.white)
      }
      .padding(.horizontal, 32)
      .padding(.bottom, 32)
    }
  }
}

#Preview("Countdown 5") {
  ZStack {
    Color.black.ignoresSafeArea()
    CountdownView(secondsLeft: 5)
  }
}

#Preview("Countdown 1") {
  ZStack {
    Color.black.ignoresSafeArea()
    CountdownView(secondsLeft: 1)
  }
}
