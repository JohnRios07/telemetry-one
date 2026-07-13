import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/session_id_provider.dart';

void main() {
  group('generateLocalSessionId', () {
    test('starts with local_ prefix', () {
      final id = generateLocalSessionId();
      expect(id.startsWith('local_'), isTrue);
    });

    test('contains timestamp', () {
      final id = generateLocalSessionId();
      expect(id.startsWith('local_'), isTrue);
      expect(id.length, greaterThan(14));
    });

    test('generates different suffixes for consecutive calls', () {
      final a = generateLocalSessionId();
      final b = generateLocalSessionId();
      expect(a, isNot(equals(b)));
    });
  });

  group('isLocalSessionId', () {
    test('returns true for local session IDs', () {
      expect(isLocalSessionId('local_12345_abc'), isTrue);
    });

    test('returns false for backend session IDs', () {
      expect(isLocalSessionId('session_01j2example'), isFalse);
    });

    test('returns false for empty string', () {
      expect(isLocalSessionId(''), isFalse);
    });
  });
}
