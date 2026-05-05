import XCTest

@testable import Runtime

/// Smoke tests for `DispatchClock`. The production clock is hard to test
/// deterministically (it touches the real wall clock), so these tests use
/// generous tolerances and serve mainly to verify that the API wires up
/// correctly. Deterministic timing tests for `Transmitter` use a fake
/// clock instead.
final class DispatchClockTests: XCTestCase {

  func test_nowMs_isMonotonicNonDecreasing() {
    let clock = DispatchClock()
    let a = clock.nowMs
    // Spin briefly so a small amount of time elapses.
    for _ in 0..<10_000 { _ = clock.nowMs }
    let b = clock.nowMs
    XCTAssertGreaterThanOrEqual(b, a)
  }

  func test_schedule_firesNearTargetTime() {
    let clock = DispatchClock(queue: .global())
    let expectation = expectation(description: "timer fires")

    let target = clock.nowMs + 100  // 100 ms in the future
    var actualFireTime: Int = 0
    let sub = clock.schedule(at: target) {
      actualFireTime = clock.nowMs
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
    sub.cancel()  // belt-and-braces

    // CI runners and macOS can be jittery; allow generous slack.
    // The Transmitter's stricter <10 ms jitter requirement (FR-12)
    // is for on-device measurement, not this unit test.
    let drift = abs(actualFireTime - target)
    XCTAssertLessThan(drift, 100, "fired at \(actualFireTime), target \(target), drift \(drift)ms")
  }

  func test_cancel_preventsWorkFromFiring() {
    let clock = DispatchClock(queue: .global())
    var fired = false

    let sub = clock.schedule(at: clock.nowMs + 50) {
      fired = true
    }
    sub.cancel()

    // Wait past the deadline; if cancel didn't take effect, `fired`
    // would be true by now.
    Thread.sleep(forTimeInterval: 0.15)
    XCTAssertFalse(fired)
  }

  func test_doubleCancel_isSafe() {
    let clock = DispatchClock(queue: .global())
    let sub = clock.schedule(at: clock.nowMs + 1000) {}
    sub.cancel()
    sub.cancel()  // must not crash or assert
  }
}
