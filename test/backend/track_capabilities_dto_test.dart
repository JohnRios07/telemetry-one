import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/core/backend/track_capabilities_dto.dart';
import 'package:telemetry_one/core/backend/track_layout_dto.dart';

void main() {
  group('TrackCapabilitiesDto parsing', () {
    test('parses available payload with reason', () {
      final dto = parseTrackCapabilities({
        'state': 'available',
        'reason': 'All layout capabilities resolved.',
      });

      expect(dto?.state, TrackCapabilityState.available);
      expect(dto?.reason, 'All layout capabilities resolved.');
    });

    test('parses partial payload with fallback reason key', () {
      final dto = parseTrackCapabilities({
        'status': 'partial',
        'message': 'Only track-level capability is known.',
      });

      expect(dto?.state, TrackCapabilityState.partial);
      expect(dto?.reason, 'Only track-level capability is known.');
    });

    test('parses unavailable payload and trims empty reason', () {
      final dto = parseTrackCapabilities({
        'state': 'unavailable',
        'reason': '   ',
      });

      expect(dto?.state, TrackCapabilityState.unavailable);
      expect(dto?.reason, isNull);
    });

    test('returns null for absent or invalid payloads', () {
      expect(parseTrackCapabilities(null), isNull);
      expect(parseTrackCapabilities({'reason': 'missing state'}), isNull);
      expect(parseTrackCapabilities(42), isNull);
    });
  });

  group('response DTO capability parsing', () {
    test('parses detection capabilities from wrapped payload', () {
      final response = TrackDetectionResponse.fromJson({
        'data': {
          'status': 'detected',
          'capabilities': {
            'state': 'partial',
            'reason': 'Manual override still pending.',
          },
        },
      });

      expect(response.capabilities?.state, TrackCapabilityState.partial);
      expect(response.capabilities?.reason, 'Manual override still pending.');
    });

    test('parses session trackCapabilities from nested session payload', () {
      final response = UpdateSessionTrackLayoutResponse.fromJson({
        'data': {
          'session': {
            'sessionId': 'session_abc123',
            'trackId': 'gt7_watkins_glen_international',
            'layoutId': 'full_course',
            'trackCapabilities': {
              'state': 'available',
              'reason': 'Layout is fully supported.',
            },
          },
        },
      });

      expect(response.capabilities?.state, TrackCapabilityState.available);
      expect(response.capabilities?.reason, 'Layout is fully supported.');
    });
  });
}
