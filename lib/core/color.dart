import 'dart:ui';

/// Moves a colour toward white (positive `amount`) or black (negative), 0-1.
///
/// Used to derive a gradient's second stop from a single stored colour, so a theme still defines
/// each artwork tile as one value rather than as a hand-tuned pair.
Color shade(Color color, double amount) {
  final target = amount >= 0 ? 1.0 : 0.0;
  final ratio = amount.abs();

  double channel(double from) => from + (target - from) * ratio;

  return Color.from(
    alpha: 1,
    red: channel(color.r),
    green: channel(color.g),
    blue: channel(color.b),
  );
}
