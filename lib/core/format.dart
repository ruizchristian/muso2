/// Formats milliseconds as `m:ss`, or `h:mm:ss` past an hour. Negative input renders `0:00`.
String formatDuration(num ms) {
  if (!ms.isFinite || ms <= 0) return '0:00';

  final totalSeconds = ms ~/ 1000;
  final seconds = totalSeconds % 60;
  final minutes = (totalSeconds ~/ 60) % 60;
  final hours = totalSeconds ~/ 3600;

  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
  return '$minutes:$paddedSeconds';
}

/// `1 song` / `12 songs`.
String pluralize(int count, String singular, [String? plural]) =>
    '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';

/// Time-of-day greeting used on the home header.
String greeting(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// `5000` -> `5,000`.
String formatCount(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i += 1) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}

/// Download sizes: "51 MB", or one decimal under 10 MB where the difference is meaningful.
String formatMegabytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb < 10 ? mb.toStringAsFixed(1) : mb.round()} MB';
}
