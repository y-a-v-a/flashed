import Combine
import XCTest

@testable import Core
@testable import Runtime

// MARK: - FakeClock (test helper)

/// Deterministic virtual-time clock. `advance(to:)` fires all due callbacks
/// in order of target time, synchronously, on the calling thread.
private final class FakeClock: Clock {

  private(set) var nowMsValue: Int = 0
  private var pending: [PendingItem] = []

  var nowMs: Int { nowMsValue }

  @discardableResult
  func schedule(at targetMs: Int, _ work: @escaping () -> Void) -> ClockSubscription {
    let item = PendingItem(targetMs: targetMs, work: work)
    pending.append(item)
    return item
  }

  /// Move virtual time forward and fire all due, non-cancelled callbacks
  /// in order. Re-checks after each fire so callbacks that schedule new
  /// work or cancel siblings are handled correctly.
  func advance(to ms: Int) {
    precondition(ms >= nowMsValue, "FakeClock cannot move backwards")
    nowMsValue = ms
    while true {
      let due =
        pending
        .filter { !$0.cancelled && $0.targetMs <= ms }
        .sorted { $0.targetMs < $1.targetMs }
      guard let next = due.first else { return }
      pending.removeAll { $0 === next }
      next.work()
    }
  }

  /// Number of currently-pending (not yet fired, not cancelled) items.
  /// Used to assert "abort cancelled everything" invariants.
  var liveSubscriptionCount: Int {
    pending.filter { !$0.cancelled }.count
  }

  private final class PendingItem: ClockSubscription {
    let targetMs: Int
    let work: () -> Void
    var cancelled = false
    init(targetMs: Int, work: @escaping () -> Void) {
      self.targetMs = targetMs
      self.work = work
    }
    func cancel() { cancelled = true }
  }
}

// MARK: - Tests

final class TransmitterTests: XCTestCase {

  private func sosSchedule() -> [ScheduleTick] {
    let elements = MorseEncoder.encode(try! ValidatedMessage("E"))
    return TransmissionSchedule.build(elements: elements, profile: .paris(wpm: 20))
  }

  // MARK: - State machine basics.

  func test_initialState_isIdle() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)
    XCTAssertEqual(tx.state, .idle)
    XCTAssertNil(tx.currentTick)
  }

  // MARK: - TASKS 2.2.3: countdown ticks down each second.

  func test_countdown_tickdownEachSecond() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)

    tx.start([], countdownSeconds: 5)
    XCTAssertEqual(tx.state, .countdown(secondsLeft: 5))

    clock.advance(to: 1000)
    XCTAssertEqual(tx.state, .countdown(secondsLeft: 4))

    clock.advance(to: 2000)
    XCTAssertEqual(tx.state, .countdown(secondsLeft: 3))

    clock.advance(to: 4000)
    XCTAssertEqual(tx.state, .countdown(secondsLeft: 1))

    // At t=5000, countdown ends; with empty schedule, transitions to .finished.
    clock.advance(to: 5000)
    XCTAssertEqual(tx.state, .finished)
  }

  // MARK: - TASKS 2.2.7: ticks fire at correct offsets.

  func test_singleTickSchedule_firesAtCountdownPlusOffset() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)
    let schedule = sosSchedule()  // single dit at offset 0, duration 60
    XCTAssertEqual(schedule.count, 1)

    tx.start(schedule, countdownSeconds: 5)
    XCTAssertEqual(tx.state, .countdown(secondsLeft: 5))

    // Just before transmission start.
    clock.advance(to: 4999)
    XCTAssertEqual(tx.state, .countdown(secondsLeft: 1))

    // Exactly at transmission start: the tick fires.
    clock.advance(to: 5000)
    if case .transmitting(let tick) = tx.state {
      XCTAssertEqual(tick.absoluteOffsetMs, 0)
      XCTAssertTrue(tick.isOn)
    } else {
      XCTFail("expected .transmitting, got \(tx.state)")
    }

    // 60 ms later (end of dit), should be finished.
    clock.advance(to: 5060)
    XCTAssertEqual(tx.state, .finished)
  }

  func test_multiTickSchedule_visitsAllTicksInOrder() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)
    // "AN" = dit, intraGap, dah, charGap, dah, intraGap, dit at 20 WPM.
    let elements = MorseEncoder.encode(try! ValidatedMessage("AN"))
    let schedule = TransmissionSchedule.build(elements: elements, profile: .paris(wpm: 20))

    var observedTickIndices: [Int] = []
    let cancellable = tx.$state.sink { state in
      if case .transmitting(let tick) = state {
        observedTickIndices.append(tick.elementIndexInMessage)
      }
    }

    tx.start(schedule, countdownSeconds: 0)
    // Drive all the way through the schedule.
    let total = TransmissionSchedule.totalDurationMs(schedule)
    clock.advance(to: total + 1)

    XCTAssertEqual(observedTickIndices, [0, 1, 2, 3, 4, 5, 6])
    XCTAssertEqual(tx.state, .finished)

    _ = cancellable
  }

  // MARK: - TASKS 2.2.5 / 2.2.8: abort during transmission.

  func test_abortDuringCountdown_setsAbortedAndCancelsPending() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)

    tx.start([], countdownSeconds: 5)
    clock.advance(to: 2000)
    XCTAssertEqual(tx.state, .countdown(secondsLeft: 3))

    tx.abort()
    XCTAssertEqual(tx.state, .aborted)
    XCTAssertEqual(clock.liveSubscriptionCount, 0, "abort must cancel all pending callbacks")

    // Further clock advancement must not change state.
    clock.advance(to: 10_000)
    XCTAssertEqual(tx.state, .aborted)
  }

  func test_abortDuringTransmission_stopsRemainingTicks() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)
    let elements = MorseEncoder.encode(try! ValidatedMessage("HELLO"))
    let schedule = TransmissionSchedule.build(elements: elements, profile: .paris(wpm: 20))

    tx.start(schedule, countdownSeconds: 0)
    // Advance into the middle of the transmission.
    clock.advance(to: 200)
    XCTAssertTrue(tx.currentTick != nil, "should be mid-transmission")

    let observedDuringAbort = tx.state
    tx.abort()
    XCTAssertEqual(tx.state, .aborted)
    XCTAssertNotEqual(tx.state, observedDuringAbort)

    // Drive past the schedule's natural end; .finished must NOT replace .aborted.
    clock.advance(to: 10_000)
    XCTAssertEqual(tx.state, .aborted)
  }

  func test_abortFromIdle_isNoOp() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)

    tx.abort()
    XCTAssertEqual(tx.state, .idle, "abort from idle must not transition")
  }

  func test_abortFromFinished_isNoOp() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)
    tx.start([], countdownSeconds: 0)
    clock.advance(to: 1)
    XCTAssertEqual(tx.state, .finished)

    tx.abort()
    XCTAssertEqual(tx.state, .finished, "abort from finished must not flip to aborted")
  }

  // MARK: - TASKS 2.2.9: .finished published exactly once.

  func test_finishedPublishedExactlyOnce() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)
    let schedule = sosSchedule()

    var finishedCount = 0
    let cancellable = tx.$state.sink { state in
      if state == .finished { finishedCount += 1 }
    }

    tx.start(schedule, countdownSeconds: 0)
    clock.advance(to: 1000)
    XCTAssertEqual(finishedCount, 1)

    // Driving the clock further must not re-publish .finished.
    clock.advance(to: 5000)
    XCTAssertEqual(finishedCount, 1)

    _ = cancellable
  }

  // MARK: - Restart semantics.

  func test_startWhileRunning_isNoOp() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)
    let schedule = sosSchedule()

    tx.start(schedule, countdownSeconds: 5)
    clock.advance(to: 1000)
    XCTAssertEqual(tx.state, .countdown(secondsLeft: 4))

    // Try to start again while running. Should be ignored.
    tx.start(schedule, countdownSeconds: 5)
    XCTAssertEqual(
      tx.state, .countdown(secondsLeft: 4),
      "second start while running must not reset countdown")
  }

  func test_restartAfterFinished_works() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)
    let schedule = sosSchedule()

    tx.start(schedule, countdownSeconds: 0)
    clock.advance(to: 100)
    XCTAssertEqual(tx.state, .finished)

    // "Transmit again" — second start from .finished is allowed.
    tx.start(schedule, countdownSeconds: 0)
    XCTAssertNotEqual(tx.state, .finished)
    clock.advance(to: 200)
    XCTAssertEqual(tx.state, .finished)
  }

  func test_restartAfterAborted_works() {
    let clock = FakeClock()
    let tx = Transmitter(clock: clock)
    let schedule = sosSchedule()

    tx.start(schedule, countdownSeconds: 5)
    clock.advance(to: 1000)
    tx.abort()
    XCTAssertEqual(tx.state, .aborted)

    tx.start(schedule, countdownSeconds: 0)
    XCTAssertEqual(tx.state, .countdown(secondsLeft: 0))  // bug? Let's see.
    // With countdownSeconds: 0, no countdown is set; first observable
    // state change comes from the first tick at offset 0 firing.
    clock.advance(to: clock.nowMs + 1)  // fire offset-0 tick
    if case .transmitting = tx.state {
    } else {
      // Or if schedule is empty, .finished. But sosSchedule isn't empty.
      XCTFail("expected .transmitting after restart, got \(tx.state)")
    }
  }
}
