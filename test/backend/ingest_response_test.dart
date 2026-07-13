import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';

void main() {
  group('IngestResponse', () {
    test('parses successful 202 response', () {
      final json = {
        'sessionId': 'session_01j2example',
        'receivedFrames': 10,
        'acceptedFrames': 10,
        'rejectedFrames': 0,
        'acceptedFromUnixMs': 1720656000100,
        'acceptedToUnixMs': 1720656000200,
        'status': 'accepted',
      };

      final response = IngestResponse.fromJson(json);

      expect(response.sessionId, 'session_01j2example');
      expect(response.receivedFrames, 10);
      expect(response.acceptedFrames, 10);
      expect(response.rejectedFrames, 0);
      expect(response.acceptedFromUnixMs, 1720656000100);
      expect(response.acceptedToUnixMs, 1720656000200);
      expect(response.status, 'accepted');
      expect(response.isAccepted, isTrue);
    });

    test('parses response with rejected frames', () {
      final json = {
        'sessionId': 'session_01j2example',
        'receivedFrames': 50,
        'acceptedFrames': 49,
        'rejectedFrames': 1,
        'acceptedFromUnixMs': 1720656000100,
        'acceptedToUnixMs': 1720656000500,
        'status': 'partial',
      };

      final response = IngestResponse.fromJson(json);

      expect(response.receivedFrames, 50);
      expect(response.acceptedFrames, 49);
      expect(response.rejectedFrames, 1);
      expect(response.isAccepted, isFalse);
      expect(response.rejectionSummary, isNull);
      expect(response.topRejectionCode, isNull);
    });

    test('parses response with rejection summary', () {
      final json = {
        'sessionId': 'session_01j2example',
        'receivedFrames': 50,
        'acceptedFrames': 48,
        'rejectedFrames': 2,
        'acceptedFromUnixMs': 1720656000100,
        'acceptedToUnixMs': 1720656000500,
        'status': 'partial',
        'rejectionSummary': {
          'reasons': [
            {'code': 'invalid_throttle', 'count': 1},
            {'code': 'invalid_speed', 'count': 1},
          ],
        },
      };

      final response = IngestResponse.fromJson(json);

      expect(response.rejectedFrames, 2);
      expect(response.hasRejections, isTrue);
      expect(response.topRejectionCode, 'invalid_throttle');
      expect(response.rejectionSummary!.reasons.length, 2);
      expect(response.rejectionSummary!.reasons[0].code, 'invalid_throttle');
      expect(response.rejectionSummary!.reasons[0].count, 1);
      expect(response.rejectionSummary!.reasons[1].code, 'invalid_speed');
      expect(response.rejectionSummary!.reasons[1].count, 1);
    });

    test('parses response with empty rejection summary gracefully', () {
      final json = {
        'sessionId': 'session_01j2example',
        'receivedFrames': 10,
        'acceptedFrames': 10,
        'rejectedFrames': 0,
        'acceptedFromUnixMs': 1720656000100,
        'acceptedToUnixMs': 1720656000200,
        'status': 'accepted',
        'rejectionSummary': null,
      };

      final response = IngestResponse.fromJson(json);

      expect(response.rejectionSummary, isNull);
      expect(response.topRejectionCode, isNull);
      expect(response.hasRejections, isFalse);
    });
  });

  group('BackendError', () {
    test('parses batch-level error with rejection details', () {
      final json = {
        'error': {
          'code': 'bad_request',
          'message': 'frames[0]: throttle must be between 0 and 1',
          'details': {
            'rejectionCode': 'invalid_throttle',
            'category': 'frame',
            'field': 'throttle',
            'frameIndex': 0,
          },
        },
      };

      final error = BackendError.fromJson(json);

      expect(error.code, 'bad_request');
      expect(error.message, 'frames[0]: throttle must be between 0 and 1');
      expect(error.isBadRequest, isTrue);
      expect(error.isRetryable, isFalse);
      expect(error.isNotImplemented, isFalse);

      expect(error.details, isNotNull);
      expect(error.details!.rejectionCode, 'invalid_throttle');
      expect(error.details!.category, 'frame');
      expect(error.details!.field, 'throttle');
      expect(error.details!.frameIndex, 0);
      expect(error.details!.isFrameCategory, isTrue);
      expect(error.details!.isBatchCategory, isFalse);
      expect(error.details!.isRetryable, isFalse);
    });

    test('parses not_implemented error without details', () {
      final json = {
        'error': {
          'code': 'not_implemented',
          'message': 'session persistence is not implemented',
        },
      };

      final error = BackendError.fromJson(json);

      expect(error.code, 'not_implemented');
      expect(error.isNotImplemented, isTrue);
      expect(error.isRetryable, isFalse);
      expect(error.details, isNull);
    });

    test('parses internal_error as retryable', () {
      final error = BackendError(
        code: 'internal_error',
        message: 'internal server error',
      );

      expect(error.isInternalError, isTrue);
      expect(error.isRetryable, isTrue);
    });

    test('parses from raw JSON string', () {
      final body = '{"error":{"code":"bad_request","message":"frames empty",'
          '"details":{"rejectionCode":"frames_empty","category":"batch"}}}';

      final error = BackendError.parse(body);

      expect(error.code, 'bad_request');
      expect(error.details, isNotNull);
      expect(error.details!.rejectionCode, 'frames_empty');
      expect(error.details!.category, 'batch');
      expect(error.details!.isBatchCategory, isTrue);
      expect(error.details!.isRetryable, isTrue);
    });

    test('handles unparseable body gracefully', () {
      final error = BackendError.parse('not json');
      expect(error.code, 'parse_error');
    });

    test('batch retryable rejection codes', () {
      const batchTooLarge = IngestRejection(
        rejectionCode: 'batch_too_large',
        category: 'batch',
      );
      expect(batchTooLarge.isRetryable, isTrue);

      const framesEmpty = IngestRejection(
        rejectionCode: 'frames_empty',
        category: 'batch',
      );
      expect(framesEmpty.isRetryable, isTrue);
    });

    test('frame rejections are not retryable', () {
      const invalidThrottle = IngestRejection(
        rejectionCode: 'invalid_throttle',
        category: 'frame',
        field: 'throttle',
        frameIndex: 0,
      );
      expect(invalidThrottle.isRetryable, isFalse);
      expect(invalidThrottle.isFrameCategory, isTrue);
    });

    test('consistency rejections are not retryable', () {
      const nonMonotonic = IngestRejection(
        rejectionCode: 'non_monotonic_timestamp',
        category: 'consistency',
      );
      expect(nonMonotonic.isRetryable, isFalse);
      expect(nonMonotonic.isConsistencyCategory, isTrue);
    });
  });

  group('TrackDetectionResponse', () {
    test('parses detected response', () {
      final json = {
        'status': 'detected',
        'trackId': 'gt7_watkins_glen_international',
        'layoutId': 'gt7_watkins_glen_long_course',
        'trackName': 'Watkins Glen International',
        'layoutName': 'Watkins Glen Long Course',
        'confidence': 0.85,
        'reasons': ['length_match'],
        'nextAction': 'use_detected_catalog_layout',
      };

      final response = TrackDetectionResponse.fromJson(json);

      expect(response.isDetected, isTrue);
      expect(response.trackId, 'gt7_watkins_glen_international');
      expect(response.trackName, 'Watkins Glen International');
      expect(response.confidence, 0.85);
    });

    test('parses pending response', () {
      final json = {
        'status': 'pending',
        'trackId': null,
        'layoutId': null,
        'trackName': null,
        'layoutName': null,
        'confidence': 0,
        'reasons': ['insufficient_data'],
        'nextAction': 'collect_more_frames',
      };

      final response = TrackDetectionResponse.fromJson(json);

      expect(response.isPending, isTrue);
      expect(response.isDetected, isFalse);
      expect(response.trackId, isNull);
    });
  });

  group('EngineerEvent', () {
    test('parses event from JSON', () {
      final json = {
        'eventId': 'event_01j2example',
        'sessionId': 'session_01j2example',
        'version': 'telemetry-one.engineer-event.v1',
        'type': 'late_throttle',
        'severity': 'medium',
        'confidence': 0.82,
        'timestampUnixMs': 1720656012345,
        'timeRange': {
          'startUnixMs': 1720656012000,
          'endUnixMs': 1720656012345,
        },
        'lapNumber': 2,
        'track': {
          'id': 'gt7_watkins_glen_international',
          'name': 'Watkins Glen International',
          'displayStrategy': 'catalog_name',
        },
        'layout': {
          'id': 'gt7_watkins_glen_long_course',
          'name': 'Watkins Glen Long Course',
          'displayStrategy': 'catalog_name',
        },
        'corner': null,
        'metrics': [
          {
            'name': 'throttleReapplicationDeltaMs',
            'value': 320,
            'unit': 'ms',
            'status': 'available',
            'role': 'delta',
          },
        ],
        'source': {
          'kind': 'deterministic_rule',
          'ruleId': 'late_throttle.v1',
          'ruleVersion': 'v1',
        },
      };

      final event = EngineerEvent.fromJson(json);

      expect(event.eventId, 'event_01j2example');
      expect(event.type, 'late_throttle');
      expect(event.severity, 'medium');
      expect(event.lapNumber, 2);
      expect(event.source, 'deterministic_rule:late_throttle.v1');
    });
  });

  group('TelemetryFrameDto toJson', () {
    test('serializes required fields only', () {
      final frame = TelemetryFrameDto(
        timestampUnixMs: 1720656000123,
        speedMps: 58.33,
        rpm: 7100,
        gear: 4,
        throttle: 0.82,
        brake: 0,
        steeringAngle: -0.12,
        fuelLiters: 38.4,
        positionX: 123.4,
        positionY: 5.6,
        positionZ: 789.1,
        lapNumber: 2,
        currentLapMs: 81234,
      );

      final json = frame.toJson();

      expect(json['timestampUnixMs'], 1720656000123);
      expect(json['speedMps'], 58.33);
      expect(json.containsKey('lastLapMs'), false);
      expect(json.containsKey('yawRadians'), false);
    });

    test('includes optional fields only when non-null', () {
      final frame = TelemetryFrameDto(
        timestampUnixMs: 1,
        speedMps: 10,
        rpm: 1000,
        gear: 1,
        throttle: 0.5,
        brake: 0,
        steeringAngle: 0,
        fuelLiters: 10,
        positionX: 0,
        positionY: 0,
        positionZ: 0,
        lapNumber: 1,
        currentLapMs: 0,
        yawRadians: 1.57,
        wheelSpeedFL: 58.1,
      );

      final json = frame.toJson();

      expect(json['yawRadians'], 1.57);
      expect(json['wheelSpeedFL'], 58.1);
      expect(json.containsKey('yawRate'), false);
      expect(json.containsKey('wheelSpeedFR'), false);
    });
  });
}
