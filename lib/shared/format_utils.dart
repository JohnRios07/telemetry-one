/// Formatting utilities for durations and timestamps.
///
/// Extracted into a single source of truth to avoid
/// duplicate implementations across screens.
library;

/// Formats a [DateTime] as `DD/MM/YYYY · HH:MM`.
String formatDateTime(DateTime value) {
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String year = value.year.toString();
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year · $hour:$minute';
}

/// Formats a nullable [Duration] as `M:SS.mmm`.
///
/// Returns `'N/D'` when [value] is `null`.
String formatDuration(Duration? value) {
  if (value == null) {
    return 'N/D';
  }

  final int totalMs = value.inMilliseconds.abs();
  final int minutes = totalMs ~/ 60000;
  final int seconds = (totalMs % 60000) ~/ 1000;
  final int millis = totalMs % 1000;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
}

/// Formats a [Duration] with an explicit sign prefix.
///
/// Uses `+` for positive, `-` for negative, `±` for zero.
String formatSignedDuration(Duration value) {
  final String sign = value.inMilliseconds > 0
      ? '+'
      : value.inMilliseconds < 0
      ? '-'
      : '\u00B1';
  return '$sign${formatDuration(value.abs())}';
}
