import SwiftUI

/// App-wide visual constants. Centralised here so the BeaconView HUD, any
/// future styled buttons, and unit/snapshot tests all reference the same
/// values.
enum Theme {

  /// HUD highlight colour per FR-14: amber `#FFA500` background with black
  /// foreground text. Chosen for legibility under low-light / dark-adapted
  /// conditions.
  static let hudHighlightBackground = Color(red: 1.0, green: 0.647, blue: 0.0)
  static let hudHighlightForeground = Color.black

  /// HUD strip background per FR-9: 40% white. Constant brightness — never
  /// flashes (FR-16).
  static let hudStripBackground = Color(white: 0.4)

  /// HUD non-highlighted text colour. White on the 40%-white strip is the
  /// most legible contrast we can achieve while staying constrained to the
  /// strip's brightness.
  static let hudText = Color.white

  /// HUD strip height per FR-14 (fits Dynamic Island / notch safely).
  static let hudStripHeight: CGFloat = 88

  /// Black separator between the HUD and the flash area per FR-9.
  static let hudSeparatorHeight: CGFloat = 4
}
