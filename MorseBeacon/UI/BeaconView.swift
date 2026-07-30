import SwiftUI

#if SWIFT_PACKAGE
  import Core
  import Runtime
#endif

/// Full-screen optical Morse output (PRD §3 step 3, FR-9 through FR-16).
///
/// Layout (top to bottom):
///   - 88pt HUD strip at 40% white, never flashes (FR-9, FR-16)
///   - 4pt black separator (FR-9)
///   - flash area filling the remainder, toggling pure black ↔ pure white
///     on each `tick.isOn` (FR-9)
///
/// Lifecycle:
///   - On appear: `ScreenController.acquire()` snapshots brightness +
///     idle-timer state and sets brightness=1.0 / idle-disabled (FR-10).
///   - On disappear: `ScreenController.release()` restores both (FR-11).
///   - Orientation locked to whatever was active at appear via
///     `OrientationLockHost` (FR-10).
///
/// Tap-to-abort is handled by the parent `TransmissionContainerView`'s
/// outer gesture; this view does not need its own. The full-screen tap
/// target is the entire view (FR-13).
struct BeaconView: View {

  let session: TransmissionSession
  let tick: ScheduleTick

  @Environment(\.screenController) private var screenController

  var body: some View {
    OrientationLockHost {
      VStack(spacing: 0) {
        HUDStripView(
          message: session.message,
          line2: session.line2,
          currentTick: tick
        )

        Color.black
          .frame(height: Theme.hudSeparatorHeight)

        FlashAreaView(isOn: tick.isOn)
      }
      .ignoresSafeArea(.container, edges: .bottom)
    }
    .ignoresSafeArea()
    .onAppear {
      screenController?.acquire()
    }
    .onDisappear {
      screenController?.release()
    }
  }
}

/// The flash area itself: a full-bleed rectangle that's pure white when the
/// channel is on and pure black when off. No animation between states —
/// the whole point is sharp on/off transitions for downstream Morse
/// decoding.
private struct FlashAreaView: View {
  let isOn: Bool

  var body: some View {
    (isOn ? Color.white : Color.black)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Environment plumbing for ScreenController

/// Environment key for the shared `ScreenController`. Provided by
/// `MorseBeaconApp` at the scene root; consumed by `BeaconView` on
/// appear/disappear.
///
/// Default value is nil so non-iOS contexts (previews, future macOS
/// builds) safely no-op without a `UIKitScreenProxy`.
private struct ScreenControllerKey: EnvironmentKey {
  static let defaultValue: ScreenController? = nil
}

extension EnvironmentValues {
  var screenController: ScreenController? {
    get { self[ScreenControllerKey.self] }
    set { self[ScreenControllerKey.self] = newValue }
  }
}
