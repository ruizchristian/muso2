import 'package:flutter/painting.dart';

/// Selectable colour themes.
///
/// Every theme supplies the same token set, and every surface reads colours through
/// `context.palette`, so a theme is defined exactly once and a runtime switch reaches everything.
enum ThemeId { monochrome, spotify, midnight, ember, violet, ocean, cyberpunk }

class Palette {
  const Palette({
    required this.base,
    required this.surface,
    required this.elevated,
    required this.pressed,
    required this.line,
    required this.accent,
    required this.accentPress,
    required this.accentDeep,
    required this.glow,
    required this.content,
    required this.muted,
    required this.faint,
    required this.danger,
    required this.onAccent,
  });

  final Color base;
  final Color surface;
  final Color elevated;
  final Color pressed;
  final Color line;
  final Color accent;
  final Color accentPress;
  final Color accentDeep;

  /// Colour of neon rims, glows and gradient washes. Most themes point this at `accent` — it only
  /// diverges where a theme is built on a two-colour neon pairing rather than a single accent.
  final Color glow;
  final Color content;
  final Color muted;
  final Color faint;
  final Color danger;

  /// Text colour that sits on an `accent`-filled surface.
  final Color onAccent;
}

class MusoTheme {
  const MusoTheme({
    required this.id,
    required this.label,
    required this.description,
    required this.palette,
    required this.artwork,
  });

  final ThemeId id;
  final String label;
  final String description;
  final Palette palette;

  /// Deterministic tile colours for artwork placeholders.
  final List<Color> artwork;
}

const _monochrome = MusoTheme(
  id: ThemeId.monochrome,
  label: 'Monochrome',
  description: 'Black and white. Hierarchy from contrast, not colour.',
  palette: Palette(
    base: Color(0xFF000000),
    surface: Color(0xFF0E0E0E),
    elevated: Color(0xFF1A1A1A),
    pressed: Color(0xFF262626),
    line: Color(0xFF333333),
    accent: Color(0xFFFFFFFF),
    accentPress: Color(0xFFE0E0E0),
    accentDeep: Color(0xFF3D3D3D),
    glow: Color(0xFFFFFFFF),
    content: Color(0xFFFFFFFF),
    muted: Color(0xFFA3A3A3),
    faint: Color(0xFF6B6B6B),
    danger: Color(0xFFE5484D),
    onAccent: Color(0xFF000000),
  ),
  // Spaced widely enough to separate adjacent albums, capped light enough for a white glyph.
  artwork: [
    Color(0xFF2B2B2B), Color(0xFF3C3C3C), Color(0xFF4D4D4D), Color(0xFF5E5E5E), //
    Color(0xFF343434), Color(0xFF454545), Color(0xFF565656), Color(0xFF676767),
  ],
);

const _spotify = MusoTheme(
  id: ThemeId.spotify,
  label: 'Green',
  description: 'The original dark green palette.',
  palette: Palette(
    base: Color(0xFF121212),
    surface: Color(0xFF181818),
    elevated: Color(0xFF242424),
    pressed: Color(0xFF2A2A2A),
    line: Color(0xFF2F2F2F),
    accent: Color(0xFF1DB954),
    accentPress: Color(0xFF1ED760),
    accentDeep: Color(0xFF0E6B32),
    glow: Color(0xFF1DB954),
    content: Color(0xFFFFFFFF),
    muted: Color(0xFFB3B3B3),
    faint: Color(0xFF727272),
    danger: Color(0xFFE22134),
    // Brand green is light; black text is the readable pairing on a filled button.
    onAccent: Color(0xFF000000),
  ),
  artwork: [
    Color(0xFF1E6F43), Color(0xFF2B4A9B), Color(0xFF7A3A6E), Color(0xFF9A5B22), //
    Color(0xFF1F6E77), Color(0xFF5A3A9E), Color(0xFF8E3448), Color(0xFF4A6B24),
  ],
);

const _midnight = MusoTheme(
  id: ThemeId.midnight,
  label: 'Midnight',
  description: 'Deep navy with a bright blue accent.',
  palette: Palette(
    base: Color(0xFF0B1020),
    surface: Color(0xFF121829),
    elevated: Color(0xFF1B2237),
    pressed: Color(0xFF252D45),
    line: Color(0xFF2E3651),
    accent: Color(0xFF4C8DFF),
    accentPress: Color(0xFF6BA1FF),
    accentDeep: Color(0xFF1E3A6B),
    glow: Color(0xFF4C8DFF),
    content: Color(0xFFF2F5FF),
    muted: Color(0xFF9BA6C4),
    faint: Color(0xFF64708F),
    danger: Color(0xFFFF6B6B),
    onAccent: Color(0xFF08101F),
  ),
  artwork: [
    Color(0xFF1E3A6B), Color(0xFF25497F), Color(0xFF2C5793), Color(0xFF1A3159), //
    Color(0xFF33629F), Color(0xFF22406F), Color(0xFF2A5187), Color(0xFF173058),
  ],
);

const _ember = MusoTheme(
  id: ThemeId.ember,
  label: 'Ember',
  description: 'Warm charcoal with an amber accent.',
  palette: Palette(
    base: Color(0xFF14100C),
    surface: Color(0xFF1C1712),
    elevated: Color(0xFF262019),
    pressed: Color(0xFF322A21),
    line: Color(0xFF3D3428),
    accent: Color(0xFFFFB020),
    accentPress: Color(0xFFFFC24D),
    accentDeep: Color(0xFF6B4410),
    glow: Color(0xFFFFB020),
    content: Color(0xFFFFF6EA),
    muted: Color(0xFFC0AF9A),
    faint: Color(0xFF8A7B68),
    danger: Color(0xFFFF5C5C),
    onAccent: Color(0xFF1A1206),
  ),
  artwork: [
    Color(0xFF6B4410), Color(0xFF7D5115), Color(0xFF8F5E1A), Color(0xFF5B380C), //
    Color(0xFFA16B1F), Color(0xFF734A12), Color(0xFF875717), Color(0xFF4E300A),
  ],
);

const _violet = MusoTheme(
  id: ThemeId.violet,
  label: 'Violet',
  description: 'Ink purple with a soft lilac accent.',
  palette: Palette(
    base: Color(0xFF0F0B16),
    surface: Color(0xFF16111F),
    elevated: Color(0xFF1F1829),
    pressed: Color(0xFF2A2136),
    line: Color(0xFF362B45),
    accent: Color(0xFFA97BFF),
    accentPress: Color(0xFFBE97FF),
    accentDeep: Color(0xFF432A75),
    glow: Color(0xFFA97BFF),
    content: Color(0xFFF5F0FF),
    muted: Color(0xFFADA1C2),
    faint: Color(0xFF786C8C),
    danger: Color(0xFFFF6B81),
    onAccent: Color(0xFF120B1E),
  ),
  artwork: [
    Color(0xFF432A75), Color(0xFF4E3286), Color(0xFF593A97), Color(0xFF392364), //
    Color(0xFF654299), Color(0xFF4A2E80), Color(0xFF553691), Color(0xFF311E58),
  ],
);

const _ocean = MusoTheme(
  id: ThemeId.ocean,
  label: 'Ocean',
  description: 'Cold slate with a teal accent.',
  palette: Palette(
    base: Color(0xFF081314),
    surface: Color(0xFF0E1C1E),
    elevated: Color(0xFF152729),
    pressed: Color(0xFF1D3335),
    line: Color(0xFF264143),
    accent: Color(0xFF2DD4BF),
    accentPress: Color(0xFF5BE3D2),
    accentDeep: Color(0xFF0F5E55),
    glow: Color(0xFF2DD4BF),
    content: Color(0xFFEAFBF9),
    muted: Color(0xFF93B3B0),
    faint: Color(0xFF5F7D7A),
    danger: Color(0xFFFF6B6B),
    onAccent: Color(0xFF04201C),
  ),
  artwork: [
    Color(0xFF0F5E55), Color(0xFF136C62), Color(0xFF177A6F), Color(0xFF0C5049), //
    Color(0xFF1B887C), Color(0xFF116359), Color(0xFF157166), Color(0xFF0A453F),
  ],
);

/// The one theme with a two-colour identity: hot magenta against electric cyan, on a near-black
/// that carries a blue cast rather than being neutral. `glow` diverges from `accent` here — the
/// neon rims and gradient washes read as cyan so they stay distinct from the magenta CTAs.
const _cyberpunk = MusoTheme(
  id: ThemeId.cyberpunk,
  label: 'Cyberpunk',
  description: 'Magenta and cyan neon over blue-black glass.',
  palette: Palette(
    base: Color(0xFF07060D),
    surface: Color(0xFF0D0B16),
    elevated: Color(0xFF15121F),
    pressed: Color(0xFF1E1A2C),
    line: Color(0xFF2A2340),
    accent: Color(0xFFFF2E97),
    accentPress: Color(0xFFFF5CAE),
    accentDeep: Color(0xFF7A0E48),
    glow: Color(0xFF22E8FF),
    content: Color(0xFFECE9FF),
    muted: Color(0xFFA79EC9),
    faint: Color(0xFF6B6390),
    danger: Color(0xFFFF4D6D),
    onAccent: Color(0xFF0A0612),
  ),
  // Saturated neon inks rather than muted jewel tones, dark enough that the white glyph still
  // clears 4.5:1 once the gradient lightens the top-left corner.
  artwork: [
    Color(0xFF8A0E63), Color(0xFF0E4F6B), Color(0xFF4A0E7A), Color(0xFF0E6B5A), //
    Color(0xFFA31247), Color(0xFF123C7A), Color(0xFF6B0E7A), Color(0xFF0E6B7A),
  ],
);

const themes = {
  ThemeId.monochrome: _monochrome,
  ThemeId.spotify: _spotify,
  ThemeId.midnight: _midnight,
  ThemeId.ember: _ember,
  ThemeId.violet: _violet,
  ThemeId.ocean: _ocean,
  ThemeId.cyberpunk: _cyberpunk,
};

const themeList = [_monochrome, _spotify, _midnight, _ember, _violet, _ocean, _cyberpunk];

const defaultThemeId = ThemeId.monochrome;
