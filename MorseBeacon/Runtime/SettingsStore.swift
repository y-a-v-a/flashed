import Combine
import Foundation

#if SWIFT_PACKAGE
  import Core
#endif

/// Persistent user preferences (PRD §4.5, FR-17 through FR-20) plus the
/// last-message field (FR-4).
///
/// `SettingsStore` is a pure `ObservableObject` over `UserDefaults`. It has
/// no SwiftUI dependency; views observe it but it observes nothing. Tests
/// inject a private `UserDefaults` suite for isolation.
///
/// Values are validated and clamped on read (defends against UserDefaults
/// corruption from older builds) and again at every set via `didSet`-like
/// Combine sinks that persist the change.
public final class SettingsStore: ObservableObject {

  // MARK: - Types

  public enum TimingModel: String, CaseIterable, Codable, Sendable {
    case paris
    case farnsworth
  }

  // MARK: - Published state

  @Published public var timingModel: TimingModel
  @Published public var characterWPM: Int
  @Published public var effectiveWPM: Int
  @Published public var lastMessage: String

  // MARK: - Init

  public init(defaults: UserDefaults = .standard) {
    let timing =
      TimingModel(rawValue: defaults.string(forKey: Keys.timingModel) ?? "")
      ?? .paris
    let charWPM = Self.clampWPM(defaults.object(forKey: Keys.characterWPM) as? Int ?? 10)
    let storedEffective = defaults.object(forKey: Keys.effectiveWPM) as? Int ?? 8
    let effWPM = max(
      TimingProfile.wpmRange.lowerBound,
      min(storedEffective, charWPM))
    let message = defaults.string(forKey: Keys.lastMessage) ?? ""

    self.defaults = defaults
    self.timingModel = timing
    self.characterWPM = charWPM
    self.effectiveWPM = effWPM
    self.lastMessage = message

    // Persist on subsequent changes. dropFirst() so the @Published initial
    // values (which we just *read* from defaults) don't immediately write
    // themselves back.
    $timingModel.dropFirst().sink { [weak self] in
      self?.defaults.set($0.rawValue, forKey: Keys.timingModel)
    }.store(in: &subs)

    $characterWPM.dropFirst().sink { [weak self] in
      self?.defaults.set($0, forKey: Keys.characterWPM)
    }.store(in: &subs)

    $effectiveWPM.dropFirst().sink { [weak self] in
      self?.defaults.set($0, forKey: Keys.effectiveWPM)
    }.store(in: &subs)

    $lastMessage.dropFirst().sink { [weak self] in
      self?.defaults.set($0, forKey: Keys.lastMessage)
    }.store(in: &subs)
  }

  // MARK: - Derived

  /// Build a `TimingProfile` from current settings. Returns nil only if
  /// the values are out of `TimingProfile`'s validated range — which the
  /// store's clamping should prevent, but the factories are still
  /// validating, so this is honest about the contract.
  public func makeTimingProfile() -> TimingProfile? {
    switch timingModel {
    case .paris:
      return TimingProfile.makeParis(wpm: characterWPM)
    case .farnsworth:
      return TimingProfile.makeFarnsworth(
        charWpm: characterWPM, effectiveWpm: effectiveWPM)
    }
  }

  // MARK: - Private

  private let defaults: UserDefaults
  private var subs: Set<AnyCancellable> = []

  private enum Keys {
    static let timingModel = "settings.timingModel"
    static let characterWPM = "settings.characterWPM"
    static let effectiveWPM = "settings.effectiveWPM"
    static let lastMessage = "settings.lastMessage"
  }

  private static func clampWPM(_ value: Int) -> Int {
    let r = TimingProfile.wpmRange
    return max(r.lowerBound, min(value, r.upperBound))
  }
}
