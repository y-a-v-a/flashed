/// Save / set / restore the device's brightness and idle-timer state for the
/// duration of a transmission (PRD FR-10, FR-11).
///
/// The controller delegates platform calls to a `ScreenProxy`, which is the
/// only point in the codebase that touches `UIScreen` /
/// `UIApplication.isIdleTimerDisabled` (CLAUDE.md architecture rule, enforced
/// by `scripts/check-screen-isolation.sh`).
///
/// Lifecycle:
/// - `acquire()` snapshots current brightness + idle-timer state, then sets
///   brightness to 1.0 and disables the idle timer. Idempotent: a second
///   `acquire()` while already acquired is a no-op (does not re-snapshot,
///   which would otherwise capture our own freshly-set 1.0 as the
///   "previous" value — a known bug class).
/// - `release()` restores the snapshotted values. No-op if not acquired.
///
/// The controller is thread-confined to whichever queue the caller uses;
/// it does no internal locking. Callers should drive it from the main
/// queue (it touches the UI screen).
public final class ScreenController {

    private let proxy: ScreenProxy
    private var snapshot: Snapshot?

    private struct Snapshot {
        let brightness: Double
        let isIdleTimerDisabled: Bool
    }

    public init(proxy: ScreenProxy) {
        self.proxy = proxy
    }

    /// True between `acquire()` and `release()`.
    public var isAcquired: Bool { snapshot != nil }

    /// Snapshot, then set brightness to 1.0 and disable the idle timer.
    /// Idempotent: a second call while already acquired does nothing.
    public func acquire() {
        guard snapshot == nil else { return }
        snapshot = Snapshot(
            brightness: proxy.brightness,
            isIdleTimerDisabled: proxy.isIdleTimerDisabled
        )
        proxy.brightness = 1.0
        proxy.isIdleTimerDisabled = true
    }

    /// Restore the snapshotted brightness and idle-timer state. No-op if
    /// not acquired.
    public func release() {
        guard let s = snapshot else { return }
        proxy.brightness = s.brightness
        proxy.isIdleTimerDisabled = s.isIdleTimerDisabled
        snapshot = nil
    }
}
