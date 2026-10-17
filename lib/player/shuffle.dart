import 'dart:math';

final _random = Random();

/// Fisher-Yates, on a copy.
List<T> _shuffled<T>(List<T> items, Random random) {
  final result = [...items];

  for (var i = result.length - 1; i > 0; i -= 1) {
    final j = random.nextInt(i + 1);
    final swap = result[i];
    result[i] = result[j];
    result[j] = swap;
  }

  return result;
}

/// Builds a shuffled play order that keeps the currently playing item first, so turning shuffle
/// on never interrupts what the user is listening to.
List<T> shuffleKeepingCurrent<T>(List<T> items, int currentIndex, {Random? random}) {
  final rng = random ?? _random;
  if (currentIndex < 0 || currentIndex >= items.length) return _shuffled(items, rng);

  final current = items[currentIndex];
  final rest = [
    for (var i = 0; i < items.length; i += 1)
      if (i != currentIndex) items[i],
  ];
  return [current, ..._shuffled(rest, rng)];
}
