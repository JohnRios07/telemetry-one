import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/shared/format_utils.dart';

void main() {
  group('formatDateTime', () {
    test('formats date and time with leading zero padding', () {
      final result = formatDateTime(DateTime(2026, 1, 2, 3, 4));

      expect(result, '02/01/2026 · 03:04');
    });

    test('formats double digit values without altering them', () {
      final result = formatDateTime(DateTime(2035, 12, 31, 23, 59));

      expect(result, '31/12/2035 · 23:59');
    });
  });

  group('formatDuration', () {
    test('returns N/D when duration is null', () {
      expect(formatDuration(null), 'N/D');
    });

    test('formats zero duration with zeroed seconds and milliseconds', () {
      expect(formatDuration(Duration.zero), '0:00.000');
    });

    test('formats positive duration with minutes seconds and milliseconds', () {
      final result = formatDuration(
        const Duration(minutes: 1, seconds: 2, milliseconds: 345),
      );

      expect(result, '1:02.345');
    });

    test('formats negative duration using its absolute value', () {
      final result = formatDuration(
        const Duration(minutes: -1, seconds: -2, milliseconds: -345),
      );

      expect(result, '1:02.345');
    });

    test('formats large durations using total elapsed minutes', () {
      final result = formatDuration(
        const Duration(hours: 2, minutes: 3, seconds: 4, milliseconds: 5),
      );

      expect(result, '123:04.005');
    });

    test('formats sub-second durations with padded milliseconds', () {
      final result = formatDuration(const Duration(milliseconds: 7));

      expect(result, '0:00.007');
    });
  });

  group('formatSignedDuration', () {
    test('prefixes positive durations with a plus sign', () {
      final result = formatSignedDuration(
        const Duration(seconds: 1, milliseconds: 250),
      );

      expect(result, '+0:01.250');
    });

    test('prefixes negative durations with a minus sign', () {
      final result = formatSignedDuration(
        const Duration(seconds: -1, milliseconds: -250),
      );

      expect(result, '-0:01.250');
    });

    test('prefixes zero duration with plus-minus sign', () {
      expect(formatSignedDuration(Duration.zero), '±0:00.000');
    });

    test('formats large signed durations while preserving the sign', () {
      final result = formatSignedDuration(
        const Duration(hours: 1, minutes: 30, seconds: 5, milliseconds: 9),
      );

      expect(result, '+90:05.009');
    });
  });
}
