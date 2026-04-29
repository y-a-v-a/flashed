/// Snapshot of the OS accessibility settings that affect this app.
///
/// Per FR-22, when Reduce Motion is on we cap the maximum character WPM at
/// 10 (instead of the usual 20) so the flashing is slower and less likely
/// to provoke a photosensitive reaction.
///
/// This is a value type, not a service: callers snapshot the current state
/// (via `AccessibilityFlags.current()`) when they need it, then read derived
/// values from the snapshot. Tests construct snapshots directly.
public struct AccessibilityFlags: Equatable, Hashable, Sendable {

    public let isReduceMotionEnabled: Bool

    public init(isReduceMotionEnabled: Bool) {
        self.isReduceMotionEnabled = isReduceMotionEnabled
    }

    /// The maximum character WPM the user is allowed to select (FR-8 + FR-22).
    /// Capped at 10 when Reduce Motion is on, otherwise the full 20.
    public var maxCharacterWPM: Int {
        isReduceMotionEnabled ? 10 : 20
    }
}

#if canImport(UIKit)
import UIKit

public extension AccessibilityFlags {
    /// Reads the current system accessibility state.
    /// Must be called from the main thread (UIAccessibility constraint).
    static func current() -> AccessibilityFlags {
        AccessibilityFlags(isReduceMotionEnabled: UIAccessibility.isReduceMotionEnabled)
    }
}
#endif
