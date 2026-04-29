#if canImport(UIKit)
import UIKit

/// The production `ScreenProxy` implementation, backed by `UIScreen` and
/// `UIApplication.shared.isIdleTimerDisabled`.
///
/// **This is the only file in the codebase permitted to reference `UIScreen`
/// or `isIdleTimerDisabled`.** Enforced by `scripts/check-screen-isolation.sh`.
///
/// Must be used from the main thread (UIKit constraint).
public final class UIKitScreenProxy: ScreenProxy {

    public init() {}

    public var brightness: Double {
        get { Double(UIScreen.main.brightness) }
        set { UIScreen.main.brightness = CGFloat(newValue) }
    }

    public var isIdleTimerDisabled: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
}
#endif
