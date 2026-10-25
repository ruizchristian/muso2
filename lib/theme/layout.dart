/// Layout tokens.
///
/// Colours deliberately do NOT live here — they are per-theme and come from `themes.dart` via
/// `context.palette`, so a runtime theme switch reaches every surface.
abstract final class Layout {
  /// Height of the tab bar's own content, before the device's bottom safe-area inset is added.
  static const tabBarBaseHeight = 56.0;

  /// Height of the mini player, used to pad scroll content so nothing hides behind it.
  static const miniPlayerHeight = 60.0;

  /// The tab bar's top border. The mini player sits over it so no line shows between the two.
  static const tabBarBorder = 0.5;

  /// Trailing space after the last row of a scroll list.
  static const scrollTailSpace = 12.0;

  static const maxContentWidth = 800.0;
}

/// Corner radii, matching the RN app's Tailwind scale.
abstract final class Radii {
  static const sm = 4.0;
  static const card = 8.0;
  static const lg = 16.0;
  static const pill = 500.0;
}
