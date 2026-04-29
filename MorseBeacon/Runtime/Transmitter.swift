import Combine
import Core

/// The single source of truth for transmission playback state.
///
/// `Transmitter` is channel-agnostic (CLAUDE.md architecture rule, PRD R1):
/// it publishes `ScheduleTick`s and the optical / haptic / audio emitters
/// each interpret `tick.isOn` in their own modality. The Transmitter does
/// not know about the screen.
///
/// Timing comes from an injected `Clock`. Production code uses `DispatchClock`
/// on the main queue; tests use a fake clock that advances virtual time
/// synchronously.
///
/// Threading: all public methods and all clock callbacks must run on the
/// queue the clock fires on (typically main). The implementation does no
/// internal locking.
public final class Transmitter: ObservableObject {

    // MARK: - Public state

    @Published public private(set) var state: TransmitterState = .idle

    /// Convenience: the currently-firing tick if the Transmitter is in the
    /// `.transmitting` state, else nil. For UI binding ergonomics.
    public var currentTick: ScheduleTick? {
        if case let .transmitting(tick) = state { return tick }
        return nil
    }

    // MARK: - Init

    public init(clock: Clock) {
        self.clock = clock
    }

    // MARK: - API

    /// Begin a transmission with the given schedule, optionally preceded by
    /// a countdown. No-op if the transmitter is already running (currently
    /// in `.countdown` or `.transmitting`). To restart, abort first.
    ///
    /// - Parameters:
    ///   - schedule: the tick stream from `TransmissionSchedule.build`.
    ///     May be empty (transitions straight to `.finished`).
    ///   - countdownSeconds: number of countdown seconds before transmission
    ///     starts. Defaults to 5 per PRD §3. Use 0 to skip the countdown
    ///     (only used in tests; production always shows the countdown
    ///     per R3).
    public func start(_ schedule: [ScheduleTick], countdownSeconds: Int = 5) {
        guard isStartable else { return }
        cancelAllSubscriptions()

        // Bump the generation so any callbacks still in flight from a
        // previous run (rare but possible on the dispatch queue) become
        // no-ops when they finally execute.
        generation += 1
        let gen = generation

        let t0 = clock.nowMs
        let txStart = t0 + countdownSeconds * 1000

        // Seed the initial visible state synchronously. This is an
        // intentional fresh-start, so it overrides any prior terminal
        // state (.finished / .aborted) without going through the
        // generation check.
        if countdownSeconds > 0 {
            state = .countdown(secondsLeft: countdownSeconds)
        } else if schedule.isEmpty {
            // Will fall through to the finish callback below.
            state = .countdown(secondsLeft: 0)
        } else {
            // First scheduled tick at offset 0 fires on the first clock
            // advancement; until then, treat as countdown(0).
            state = .countdown(secondsLeft: 0)
        }

        // Countdown tick-down callbacks. Guard against countdownSeconds == 0
        // (stride 1..<0 traps).
        for elapsedSeconds in 1..<max(countdownSeconds, 1) {
            let secondsLeft = countdownSeconds - elapsedSeconds
            let target = t0 + elapsedSeconds * 1000
            let sub = clock.schedule(at: target) { [weak self] in
                self?.applyIfCurrent(generation: gen) {
                    $0.state = .countdown(secondsLeft: secondsLeft)
                }
            }
            subscriptions.append(sub)
        }

        // Each tick at its absolute time.
        for tick in schedule {
            let target = txStart + tick.absoluteOffsetMs
            let sub = clock.schedule(at: target) { [weak self] in
                self?.applyIfCurrent(generation: gen) {
                    $0.state = .transmitting(currentTick: tick)
                }
            }
            subscriptions.append(sub)
        }

        // .finished transition at txStart + totalDuration.
        let totalMs = TransmissionSchedule.totalDurationMs(schedule)
        let finishTarget = txStart + totalMs
        let finishSub = clock.schedule(at: finishTarget) { [weak self] in
            self?.applyIfCurrent(generation: gen) {
                $0.state = .finished
                $0.cancelAllSubscriptions()
            }
        }
        subscriptions.append(finishSub)
    }

    /// Cancel any in-flight transmission and transition to `.aborted`.
    /// No-op when not running.
    public func abort() {
        switch state {
        case .aborted, .finished, .idle:
            return
        case .countdown, .transmitting:
            cancelAllSubscriptions()
            generation += 1   // invalidate any in-flight callbacks
            state = .aborted
        }
    }

    // MARK: - Internal

    private let clock: Clock
    private var subscriptions: [ClockSubscription] = []

    /// Monotonic counter incremented on every `start()` and `abort()`.
    /// Scheduled callbacks capture the generation at scheduling time and
    /// refuse to mutate state if it has changed since (i.e., a new run has
    /// started or the current run was aborted while the callback was in
    /// flight on the clock's queue).
    private var generation: Int = 0

    private var isStartable: Bool {
        switch state {
        case .idle, .finished, .aborted: return true
        case .countdown, .transmitting: return false
        }
    }

    /// Run `apply` only if the captured generation still matches the
    /// current generation. This is the race-safety primitive used by all
    /// scheduled callbacks.
    private func applyIfCurrent(generation captured: Int, _ apply: (Transmitter) -> Void) {
        guard generation == captured else { return }
        apply(self)
    }

    private func cancelAllSubscriptions() {
        for sub in subscriptions { sub.cancel() }
        subscriptions.removeAll()
    }

    deinit {
        cancelAllSubscriptions()
    }
}

// MARK: - Backgrounding observer (iOS only)

#if canImport(UIKit)
import UIKit

public extension Transmitter {
    /// Install an observer that aborts the transmission when the app enters
    /// background (PRD AC-5). Returns an opaque token that the caller must
    /// retain; releasing it removes the observer.
    func observeBackgrounding() -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.abort()
        }
    }
}
#endif
