import XCTest

@testable import Core
@testable import Runtime

/// Each test gets its own isolated UserDefaults suite so writes don't
/// pollute the shared `.standard`.
private func freshDefaults(function: String = #function) -> UserDefaults {
  let suite = "test-\(function)-\(UUID().uuidString)"
  let d = UserDefaults(suiteName: suite)!
  d.removePersistentDomain(forName: suite)
  return d
}

final class SettingsStoreTests: XCTestCase {

  // MARK: - Defaults

  func test_defaultValues_whenStorageIsEmpty() {
    let store = SettingsStore(defaults: freshDefaults())
    XCTAssertEqual(store.timingModel, .paris)
    XCTAssertEqual(store.characterWPM, 10)
    XCTAssertEqual(store.effectiveWPM, 8)
    XCTAssertEqual(store.lastMessage, "")
  }

  // MARK: - Reading stored values

  func test_readsPreviouslyStoredValues() {
    let d = freshDefaults()
    d.set("farnsworth", forKey: "settings.timingModel")
    d.set(15, forKey: "settings.characterWPM")
    d.set(7, forKey: "settings.effectiveWPM")
    d.set("HELLO WORLD", forKey: "settings.lastMessage")

    let store = SettingsStore(defaults: d)
    XCTAssertEqual(store.timingModel, .farnsworth)
    XCTAssertEqual(store.characterWPM, 15)
    XCTAssertEqual(store.effectiveWPM, 7)
    XCTAssertEqual(store.lastMessage, "HELLO WORLD")
  }

  // MARK: - Defensive clamping on read

  func test_outOfRangeStoredCharacterWPM_isClampedOnRead() {
    let d = freshDefaults()
    d.set(99, forKey: "settings.characterWPM")
    let store = SettingsStore(defaults: d)
    XCTAssertEqual(store.characterWPM, TimingProfile.wpmRange.upperBound)
  }

  func test_outOfRangeStoredEffectiveWPM_isClampedToCharacterWPM() {
    let d = freshDefaults()
    d.set(10, forKey: "settings.characterWPM")
    d.set(99, forKey: "settings.effectiveWPM")  // higher than character
    let store = SettingsStore(defaults: d)
    XCTAssertLessThanOrEqual(store.effectiveWPM, store.characterWPM)
  }

  func test_unknownTimingModelString_fallsBackToParis() {
    let d = freshDefaults()
    d.set("garbage", forKey: "settings.timingModel")
    let store = SettingsStore(defaults: d)
    XCTAssertEqual(store.timingModel, .paris)
  }

  // MARK: - Persisting on change

  func test_changingTimingModel_persists() {
    let d = freshDefaults()
    let store = SettingsStore(defaults: d)
    store.timingModel = .farnsworth

    XCTAssertEqual(d.string(forKey: "settings.timingModel"), "farnsworth")

    // A fresh store reading the same defaults sees the new value.
    XCTAssertEqual(SettingsStore(defaults: d).timingModel, .farnsworth)
  }

  func test_changingCharacterWPM_persists() {
    let d = freshDefaults()
    let store = SettingsStore(defaults: d)
    store.characterWPM = 17
    XCTAssertEqual(SettingsStore(defaults: d).characterWPM, 17)
  }

  func test_changingLastMessage_persists() {
    let d = freshDefaults()
    let store = SettingsStore(defaults: d)
    store.lastMessage = "SOS"
    XCTAssertEqual(SettingsStore(defaults: d).lastMessage, "SOS")
  }

  // MARK: - Derived: makeTimingProfile

  func test_makeTimingProfile_PARIS() {
    let store = SettingsStore(defaults: freshDefaults())
    store.timingModel = .paris
    store.characterWPM = 12

    let profile = store.makeTimingProfile()
    XCTAssertEqual(profile, .paris(wpm: 12))
  }

  func test_makeTimingProfile_Farnsworth() {
    let store = SettingsStore(defaults: freshDefaults())
    store.timingModel = .farnsworth
    store.characterWPM = 15
    store.effectiveWPM = 7

    let profile = store.makeTimingProfile()
    XCTAssertEqual(profile, .farnsworth(charWpm: 15, effectiveWpm: 7))
  }
}
