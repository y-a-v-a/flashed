/// A minimal abstraction over the device-screen state we manipulate during
/// transmission: display brightness and the idle-timer-disabled flag.
///
/// The protocol is the seam that keeps `ScreenController` testable on macOS
/// (where UIKit is unavailable) and on iOS without instantiating real
/// `UIScreen` / `UIApplication` singletons.
///
/// The only production conformer is `UIKitScreenProxy`. Tests use a fake.
public protocol ScreenProxy: AnyObject {
  /// Screen brightness in `0.0...1.0`.
  var brightness: Double { get set }

  /// Whether the system idle timer is disabled (true = screen stays awake).
  var isIdleTimerDisabled: Bool { get set }
}
