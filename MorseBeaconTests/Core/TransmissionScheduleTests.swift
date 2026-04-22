import XCTest
@testable import Core

final class TransmissionScheduleTests: XCTestCase {

    private func schedule(_ raw: String, _ profile: TimingProfile) throws -> [ScheduleTick] {
        let elements = MorseEncoder.encode(try ValidatedMessage(raw))
        return TransmissionSchedule.build(elements: elements, profile: profile)
    }

    // MARK: - TASKS 1.5.1: single element, span model, no sentinel.

    func test_singleE_atTwentyWPM_producesOneSpan_ofSixtyMs() throws {
        let ticks = try schedule("E", .paris(wpm: 20))
        XCTAssertEqual(ticks.count, 1)
        XCTAssertEqual(ticks[0].absoluteOffsetMs, 0)
        XCTAssertEqual(ticks[0].durationMs, 60)
        XCTAssertTrue(ticks[0].isOn)
        XCTAssertEqual(TransmissionSchedule.totalDurationMs(ticks), 60)
    }

    func test_emptyMessage_producesEmptySchedule_withZeroTotalDuration() throws {
        let ticks = try schedule("", .paris(wpm: 20))
        XCTAssertEqual(ticks, [])
        XCTAssertEqual(TransmissionSchedule.totalDurationMs(ticks), 0)
    }

    // MARK: - TASKS 1.5.2 / AC-4: the PARIS 50-unit invariant.

    func test_parisInvariantIs50Units() throws {
        // "PARIS " at 20 WPM must take exactly 3000 ms (50 dit-units × 60 ms).
        // This is the load-bearing test for the whole timing system.
        let ticks = try schedule("PARIS ", .paris(wpm: 20))
        XCTAssertEqual(TransmissionSchedule.totalDurationMs(ticks), 3000)
    }

    func test_parisInvariant_scalesWithWPM() {
        // 1 WPM PARIS = "PARIS " per minute = 60000/wpm ms per word.
        // At WPMs where 1200/wpm divides cleanly, this must be exact.
        for wpm in [5, 10, 15, 20] {
            let ticks = (try? schedule("PARIS ", .paris(wpm: wpm))) ?? []
            XCTAssertEqual(
                TransmissionSchedule.totalDurationMs(ticks),
                60_000 / wpm,
                "PARIS invariant broken at \(wpm) WPM"
            )
        }
    }

    // MARK: - TASKS 1.5.3: isOn matches element kind.

    func test_isOn_followsElementKind() throws {
        let ticks = try schedule("AN EE", .paris(wpm: 10))
        for t in ticks {
            // dit/dah ticks are on; gap ticks are off.
            // The source of truth is ElementKind.isOn, which we can't read
            // directly from a tick — but every on-tick must have duration
            // equal to dit or dah, and every off-tick to a gap.
            let dit = 120
            let onDurations: Set<Int> = [dit, 3 * dit]               // dit, dah
            let offDurations: Set<Int> = [dit, 3 * dit, 7 * dit]     // intraGap, charGap, wordGap
            if t.isOn {
                XCTAssertTrue(onDurations.contains(t.durationMs),
                              "on-tick has unexpected duration \(t.durationMs)")
            } else {
                XCTAssertTrue(offDurations.contains(t.durationMs),
                              "off-tick has unexpected duration \(t.durationMs)")
            }
        }
    }

    // MARK: - TASKS 1.5.4: monotonic offsets, durations match profile.

    func test_offsetIsCumulativeSumOfDurations() throws {
        let ticks = try schedule("HELLO WORLD", .paris(wpm: 12))
        XCTAssertEqual(ticks.first?.absoluteOffsetMs, 0)
        for i in 1..<ticks.count {
            XCTAssertEqual(
                ticks[i].absoluteOffsetMs,
                ticks[i - 1].absoluteOffsetMs + ticks[i - 1].durationMs,
                "offset break at index \(i)"
            )
        }
    }

    func test_offsetsStrictlyMonotonic() throws {
        let ticks = try schedule("HELLO", .paris(wpm: 10))
        for i in 1..<ticks.count {
            XCTAssertGreaterThan(ticks[i].absoluteOffsetMs, ticks[i - 1].absoluteOffsetMs)
        }
    }

    // MARK: - TASKS 1.5.5: provenance (char index + element index) propagates.

    func test_sourceCharIndexAndElementIndex_propagate() throws {
        let rawElements = MorseEncoder.encode(try ValidatedMessage("AN"))
        let ticks = TransmissionSchedule.build(elements: rawElements, profile: .paris(wpm: 20))
        XCTAssertEqual(ticks.count, rawElements.count)
        for (tick, element) in zip(ticks, rawElements) {
            XCTAssertEqual(tick.sourceCharIndex, element.sourceCharIndex)
            XCTAssertEqual(tick.elementIndexInMessage, element.elementIndexInMessage)
        }
    }

    // MARK: - TASKS 1.5.6: SOS at 10 WPM (AC-1 at schedule layer).

    func test_SOS_atTenWPM_totalDuration() throws {
        // S O S with charGaps between the three letters.
        //   S  = dit, intraGap, dit, intraGap, dit        = 1+1+1+1+1 = 5 units
        //   charGap                                        = 3 units
        //   O  = dah, intraGap, dah, intraGap, dah        = 3+1+3+1+3 = 11 units
        //   charGap                                        = 3 units
        //   S                                              = 5 units
        //   total = 5 + 3 + 11 + 3 + 5 = 27 dit-units
        // At 10 WPM, dit = 120 ms → 27 × 120 = 3240 ms.
        let ticks = try schedule("SOS", .paris(wpm: 10))
        XCTAssertEqual(TransmissionSchedule.totalDurationMs(ticks), 3240)
    }

    // MARK: - Structural invariants.

    func test_noTerminalSentinelTick_R1() throws {
        // Per R1: ticks are 1:1 with elements; no terminal sentinel. The
        // encoder emits N elements; the scheduler emits exactly N ticks.
        let raw = "SOS PARIS"
        let elements = MorseEncoder.encode(try ValidatedMessage(raw))
        let ticks = TransmissionSchedule.build(elements: elements, profile: .paris(wpm: 15))
        XCTAssertEqual(ticks.count, elements.count)
    }

    func test_allDurationsArePositive() throws {
        let ticks = try schedule("HELLO WORLD", .farnsworth(charWpm: 15, effectiveWpm: 8))
        for t in ticks {
            XCTAssertGreaterThan(t.durationMs, 0, "tick at \(t.absoluteOffsetMs) has non-positive duration")
        }
    }
}
