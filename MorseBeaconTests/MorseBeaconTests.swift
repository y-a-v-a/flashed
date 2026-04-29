import XCTest

/// Stub Xcode-side test target.
///
/// All Core + Runtime unit tests run via SwiftPM (`swift test`). They live
/// in `MorseBeaconTests/Core/` and `MorseBeaconTests/Runtime/` and are not
/// part of this Xcode target — they would need different `@testable import`
/// names since the Xcode app uses a single `MorseBeacon` module while the
/// SwiftPM build splits Core and Runtime into their own modules.
///
/// This file exists so the Xcode unit-test target has at least one source
/// file. iOS-only tests that genuinely need the simulator (UI snapshots,
/// on-device timing measurements per task 2.2.10, accessibility audits)
/// will go in this target as they appear.
final class MorseBeaconAppLaunchTests: XCTestCase {

    func test_appModuleImports() {
        // Smoke test: confirms the Xcode app target compiles and is
        // testable from this bundle. Replaced once real iOS-only tests
        // arrive.
        XCTAssertTrue(true)
    }
}
