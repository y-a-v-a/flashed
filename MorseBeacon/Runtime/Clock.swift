import Dispatch

/// Monotonic clock with absolute-deadline scheduling.
///
/// This is the timing seam between `Transmitter` and the real wall clock.
/// Production code uses `DispatchClock`, which wraps `DispatchSourceTimer`
/// with the `.strict` flag and absolute deadlines (PRD FR-12). Tests use
/// a fake clock that lets them advance virtual time deterministically.
///
/// All times are integer milliseconds from an arbitrary, monotonic origin.
/// The origin is stable for the lifetime of the clock instance but is not
/// comparable across instances.
public protocol Clock: AnyObject {

    /// Current monotonic time in milliseconds.
    var nowMs: Int { get }

    /// Schedule `work` to run when monotonic time reaches `targetMs`.
    /// The work runs on a clock-internal queue (callers that need a
    /// specific queue should hop themselves).
    ///
    /// Returns a handle that the caller MUST keep alive until either the
    /// work fires or the handle is cancelled. Releasing the handle without
    /// cancelling does not prevent the work from firing.
    @discardableResult
    func schedule(at targetMs: Int, _ work: @escaping () -> Void) -> ClockSubscription
}

/// A pending or fired clock callback. Cancelling is safe to call from
/// any thread and idempotent: cancelling an already-fired or already-
/// cancelled subscription is a no-op.
public protocol ClockSubscription: AnyObject {
    func cancel()
}

// MARK: - DispatchClock (production)

/// `Clock` backed by `DispatchSourceTimer` with the `.strict` flag.
///
/// Each `schedule(at:)` call creates its own timer with an absolute deadline,
/// matching PRD FR-12's "compute t0 + cumulativeUnits × unitDuration for each
/// flip" requirement. Absolute deadlines avoid the cumulative drift that
/// incremental sleeps would produce.
public final class DispatchClock: Clock {

    private let queue: DispatchQueue
    /// Origin-of-time for this clock, captured once at init. All `nowMs`
    /// readings and scheduled deadlines are relative to this anchor.
    private let referenceTime: DispatchTime

    public init(queue: DispatchQueue = .main) {
        self.queue = queue
        self.referenceTime = DispatchTime.now()
    }

    public var nowMs: Int {
        let elapsedNs = DispatchTime.now().uptimeNanoseconds &- referenceTime.uptimeNanoseconds
        return Int(elapsedNs / 1_000_000)
    }

    @discardableResult
    public func schedule(at targetMs: Int, _ work: @escaping () -> Void) -> ClockSubscription {
        let timer = DispatchSource.makeTimerSource(flags: [.strict], queue: queue)
        let deadline = referenceTime + .milliseconds(targetMs)
        timer.schedule(deadline: deadline, leeway: .nanoseconds(0))
        let subscription = DispatchClockSubscription(timer: timer)
        timer.setEventHandler { [weak subscription] in
            work()
            subscription?.cancel()
        }
        timer.resume()
        return subscription
    }
}

private final class DispatchClockSubscription: ClockSubscription {
    private let lock = DispatchQueue(label: "DispatchClockSubscription")
    private var timer: DispatchSourceTimer?

    init(timer: DispatchSourceTimer) {
        self.timer = timer
    }

    func cancel() {
        lock.sync {
            timer?.cancel()
            timer = nil
        }
    }

    deinit {
        // If the caller dropped the handle without cancelling, leave the
        // timer to fire its event handler one last time and then go away
        // on its own (DispatchSourceTimer is reference-counted by the
        // event handler closure capture).
    }
}
