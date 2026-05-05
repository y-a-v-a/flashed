import SwiftUI

#if SWIFT_PACKAGE
  import Core
#endif

/// **Placeholder** for the full Beacon view (TASKS §3.6). The complete
/// implementation will:
/// - Acquire screen brightness (1.0) + idle-timer disable on appear.
/// - Lock orientation via `OrientationLockHost`.
/// - Render the 88pt HUD strip + 4pt separator + flash area bound to
///   `tick.isOn`.
/// - Tap-to-abort over the whole screen.
///
/// For now: black background while transmitting plus a small text reading
/// the current tick's index. Enough for `TransmissionContainerView` to
/// route end-to-end and for sanity-checking the state machine in the
/// simulator.
struct BeaconView: View {
  let tick: ScheduleTick

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(spacing: 12) {
        Text("Beacon view pending")
          .font(.title2)
          .foregroundStyle(.white)
        Text("TASKS §3.6")
          .font(.callout)
          .foregroundStyle(.white.opacity(0.5))
        Text(
          "current tick: idx=\(tick.elementIndexInMessage) on=\(tick.isOn ? "yes" : "no") off=\(tick.absoluteOffsetMs)ms"
        )
        .font(.caption.monospaced())
        .foregroundStyle(.white.opacity(0.4))
        .padding(.top, 16)
      }
    }
  }
}
