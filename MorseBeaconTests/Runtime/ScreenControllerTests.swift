import XCTest
@testable import Runtime

/// In-memory `ScreenProxy` for verifying `ScreenController` semantics
/// without UIKit. Records the full call history so order-of-operations
/// invariants can be asserted.
private final class FakeScreenProxy: ScreenProxy {

    enum Event: Equatable {
        case readBrightness
        case writeBrightness(Double)
        case readIdleTimer
        case writeIdleTimer(Bool)
    }

    var brightnessStorage: Double
    var idleTimerStorage: Bool
    private(set) var events: [Event] = []

    init(brightness: Double = 0.4, idleTimerDisabled: Bool = false) {
        self.brightnessStorage = brightness
        self.idleTimerStorage = idleTimerDisabled
    }

    var brightness: Double {
        get {
            events.append(.readBrightness)
            return brightnessStorage
        }
        set {
            events.append(.writeBrightness(newValue))
            brightnessStorage = newValue
        }
    }

    var isIdleTimerDisabled: Bool {
        get {
            events.append(.readIdleTimer)
            return idleTimerStorage
        }
        set {
            events.append(.writeIdleTimer(newValue))
            idleTimerStorage = newValue
        }
    }
}

final class ScreenControllerTests: XCTestCase {

    // MARK: - TASKS 2.1.2: acquire/release round-trips correctly.

    func test_acquire_savesAndOverridesBrightnessAndIdleTimer() {
        let fake = FakeScreenProxy(brightness: 0.42, idleTimerDisabled: false)
        let controller = ScreenController(proxy: fake)

        controller.acquire()

        XCTAssertEqual(fake.brightnessStorage, 1.0)
        XCTAssertTrue(fake.idleTimerStorage)
        XCTAssertTrue(controller.isAcquired)
    }

    func test_release_restoresPreviouslySavedValues() {
        let fake = FakeScreenProxy(brightness: 0.42, idleTimerDisabled: false)
        let controller = ScreenController(proxy: fake)

        controller.acquire()
        controller.release()

        XCTAssertEqual(fake.brightnessStorage, 0.42)
        XCTAssertFalse(fake.idleTimerStorage)
        XCTAssertFalse(controller.isAcquired)
    }

    func test_release_restoresIdleTimerDisabledIfItWasAlreadyTrue() {
        // If something else had already disabled the idle timer before we
        // acquired, releasing must keep it disabled (not reset to false).
        let fake = FakeScreenProxy(brightness: 0.7, idleTimerDisabled: true)
        let controller = ScreenController(proxy: fake)

        controller.acquire()
        controller.release()

        XCTAssertEqual(fake.brightnessStorage, 0.7)
        XCTAssertTrue(fake.idleTimerStorage, "must restore the captured-true state, not reset to false")
    }

    // MARK: - TASKS 2.1.2: idempotency.

    func test_doubleAcquire_isANoOp_doesNotReSnapshot() {
        // The bug class this guards against: a naive impl re-snapshots on
        // second acquire and captures its own freshly-set 1.0 as the
        // "previous" value, so release() restores to 1.0 instead of 0.42.
        let fake = FakeScreenProxy(brightness: 0.42, idleTimerDisabled: false)
        let controller = ScreenController(proxy: fake)

        controller.acquire()
        controller.acquire()
        controller.release()

        XCTAssertEqual(fake.brightnessStorage, 0.42, "second acquire must not overwrite snapshot")
        XCTAssertFalse(fake.idleTimerStorage)
    }

    func test_releaseWithoutAcquire_isANoOp() {
        let fake = FakeScreenProxy(brightness: 0.5, idleTimerDisabled: false)
        let controller = ScreenController(proxy: fake)

        controller.release()

        XCTAssertEqual(fake.brightnessStorage, 0.5)
        XCTAssertFalse(fake.idleTimerStorage)
        XCTAssertFalse(controller.isAcquired)
        // Critically: nothing was even read or written on the proxy.
        XCTAssertTrue(fake.events.isEmpty, "release() without acquire() must not touch the proxy")
    }

    func test_doubleRelease_isANoOp() {
        let fake = FakeScreenProxy(brightness: 0.5, idleTimerDisabled: false)
        let controller = ScreenController(proxy: fake)

        controller.acquire()
        controller.release()
        controller.release()

        XCTAssertEqual(fake.brightnessStorage, 0.5)
        XCTAssertFalse(controller.isAcquired)
    }

    // MARK: - Order of operations on acquire.

    func test_acquire_readsBeforeWriting() {
        // Snapshot must read the current values before the writes — otherwise
        // the snapshot captures our own writes.
        let fake = FakeScreenProxy(brightness: 0.42, idleTimerDisabled: false)
        let controller = ScreenController(proxy: fake)

        controller.acquire()

        // First two events must be the reads (in either order).
        let firstTwo = Array(fake.events.prefix(2))
        XCTAssertTrue(firstTwo.contains(.readBrightness), "must read brightness before writing")
        XCTAssertTrue(firstTwo.contains(.readIdleTimer), "must read idle-timer state before writing")

        // Subsequent events must include the writes.
        XCTAssertTrue(fake.events.contains(.writeBrightness(1.0)))
        XCTAssertTrue(fake.events.contains(.writeIdleTimer(true)))
    }

    // MARK: - Cycle support (acquire → release → acquire again).

    func test_canBeReacquiredAfterRelease() {
        let fake = FakeScreenProxy(brightness: 0.3, idleTimerDisabled: false)
        let controller = ScreenController(proxy: fake)

        controller.acquire()
        controller.release()

        // User changes brightness in between (e.g., via Control Center).
        fake.brightnessStorage = 0.9

        controller.acquire()
        XCTAssertEqual(fake.brightnessStorage, 1.0)
        controller.release()
        XCTAssertEqual(fake.brightnessStorage, 0.9, "second cycle must capture the new previous value")
    }
}
