import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/track_layout_dto.dart';

void main() {
  group('TrackLayoutsCatalogResponse', () {
    test('parses wrapped catalog payload with track and layout names', () {
      final response = TrackLayoutsCatalogResponse.fromJson({
        'data': {
          'catalog': {
            'tracks': [
              {
                'trackId': 'gt7_watkins_glen_international',
                'trackName': 'Watkins Glen International',
                'layouts': [
                  {
                    'layoutId': 'full_course',
                    'layoutName': 'Full Course',
                  },
                ],
              },
            ],
          },
        },
      });

      expect(response.tracks, hasLength(1));
      expect(response.trackFor('gt7_watkins_glen_international')?.displayName,
          'Watkins Glen International');
      expect(
        response.trackFor('gt7_watkins_glen_international')
            ?.layoutFor('full_course')
            ?.displayName,
        'Full Course',
      );
    });

    test('throws on malformed catalog payload', () {
      expect(
        () => TrackLayoutsCatalogResponse.fromJson({'tracks': 'not-a-list'}),
        throwsA(isA<TrackLayoutContractException>()),
      );
    });
  });

  group('UpdateSessionTrackLayoutResponse', () {
    test('parses wrapped data.session response and provenance ids', () {
      final response = UpdateSessionTrackLayoutResponse.fromJson({
        'data': {
          'session': {
            'sessionId': 'session_abc123',
            'trackId': 'gt7_watkins_glen_international',
            'layoutId': 'full_course',
            'detectedTrackId': 'detected_track',
            'detectedLayoutId': 'detected_layout',
          },
        },
      });

      expect(response.sessionId, 'session_abc123');
      expect(response.trackId, 'gt7_watkins_glen_international');
      expect(response.layoutId, 'full_course');
      expect(response.detectedTrackId, 'detected_track');
      expect(response.detectedLayoutId, 'detected_layout');
    });

    test('parses direct session response', () {
      final response = UpdateSessionTrackLayoutResponse.fromJson({
        'session': {
          'sessionId': 'session_def456',
          'trackId': 'gt7_suzuka_circuit',
          'layoutId': 'full_course',
        },
      });

      expect(response.sessionId, 'session_def456');
      expect(response.trackId, 'gt7_suzuka_circuit');
      expect(response.layoutId, 'full_course');
      expect(response.detectedTrackId, isNull);
      expect(response.detectedLayoutId, isNull);
    });

    test('throws when required ids are missing', () {
      expect(
        () => UpdateSessionTrackLayoutResponse.fromJson({'sessionId': 'x'}),
        throwsA(isA<TrackLayoutContractException>()),
      );
    });
  });
}
