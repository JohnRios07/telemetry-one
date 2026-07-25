import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';

void main() {
  group('TelemetryFrameDto.toJson', () {
    TelemetryFrameDto _baseFrame() {
      return const TelemetryFrameDto(
        timestampUnixMs: 1720656000123,
        speedMps: 58.33,
        rpm: 7100,
        gear: 4,
        throttle: 0.82,
        brake: 0.0,
        steeringAngle: -0.12,
        fuelLiters: 38.4,
        positionX: 123.4,
        positionY: 5.6,
        positionZ: 789.1,
        lapNumber: 2,
        currentLapMs: 81234,
        lastLapMs: 91345,
        bestLapMs: 90210,
        isOnTrack: true,
      );
    }

    test('uses steering key (not steeringAngle) matching backend contract', () {
      final json = _baseFrame().toJson();

      expect(json.containsKey('steering'), isTrue);
      expect(json.containsKey('steeringAngle'), isFalse);
      expect(json['steering'], -0.12);
    });

    test('steering key has correct value', () {
      final frame = _baseFrame();
      expect(frame.steeringAngle, -0.12);

      final json = frame.toJson();
      expect(json['steering'], frame.steeringAngle);
    });

    test('steeringAngle field exists in class but NOT in JSON output', () {
      final frame = _baseFrame();
      expect(frame.steeringAngle, -0.12);

      final json = frame.toJson();
      expect(
        json.keys.contains('steeringAngle'),
        isFalse,
        reason: 'backend DisallowUnknownFields rejects steeringAngle key',
      );
      expect(json['steering'], -0.12);
    });

    test('all required keys present in JSON output', () {
      final json = _baseFrame().toJson();

      final required = [
        'timestampUnixMs',
        'speedMps',
        'rpm',
        'gear',
        'throttle',
        'brake',
        'steering',
        'fuelLiters',
        'positionX',
        'positionY',
        'positionZ',
        'lapNumber',
        'currentLapMs',
        'isOnTrack',
      ];
      for (final key in required) {
        expect(
          json.containsKey(key),
          isTrue,
          reason: 'Required key $key missing from toJson()',
        );
      }
    });

    test('optional fields omitted when null', () {
      final frame = TelemetryFrameDto(
        timestampUnixMs: 1720656000123,
        speedMps: 58.33,
        rpm: 7100,
        gear: 4,
        throttle: 0.82,
        brake: 0.0,
        steeringAngle: -0.12,
        fuelLiters: 38.4,
        positionX: 123.4,
        positionY: 5.6,
        positionZ: 789.1,
        lapNumber: 2,
        currentLapMs: 81234,
        isOnTrack: true,
      );

      final json = frame.toJson();
      expect(json.containsKey('lastLapMs'), isFalse);
      expect(json.containsKey('bestLapMs'), isFalse);
      expect(json.containsKey('yawRadians'), isFalse);
      expect(json.containsKey('yawRate'), isFalse);
      expect(json.containsKey('wheelSpeedFL'), isFalse);
    });

    test('no unknown keys that backend might reject', () {
      final json = _baseFrame().toJson();

      final knownKeys = {
        'timestampUnixMs',
        'speedMps',
        'rpm',
        'gear',
        'throttle',
        'brake',
        'steering',
        'fuelLiters',
        'positionX',
        'positionY',
        'positionZ',
        'lapNumber',
        'currentLapMs',
        'isOnTrack',
        'lastLapMs',
        'bestLapMs',
        'yawRadians',
        'yawRate',
        'wheelSpeedFL',
        'wheelSpeedFR',
        'wheelSpeedRL',
        'wheelSpeedRR',
      };

      for (final key in json.keys) {
        expect(
          knownKeys.contains(key),
          isTrue,
          reason:
              'Unknown key $key in toJson() — '
              'backend DisallowUnknownFields would reject',
        );
      }
    });
  });

  group('FrameBatchRequest.toJson', () {
    test('includes steering in frame JSON within batch', () {
      final frame = TelemetryFrameDto(
        timestampUnixMs: 1,
        speedMps: 10,
        rpm: 2000,
        gear: 2,
        throttle: 0.5,
        brake: 0.0,
        steeringAngle: -0.05,
        fuelLiters: 50,
        positionX: 0,
        positionY: 0,
        positionZ: 0,
        lapNumber: 1,
        currentLapMs: 30000,
        isOnTrack: true,
      );

      final batch = FrameBatchRequest(
        sessionId: 'session_test',
        frames: [frame],
      );
      final json = batch.toJson();
      final frameJson = (json['frames'] as List)[0] as Map<String, dynamic>;

      expect(frameJson.containsKey('steering'), isTrue);
      expect(frameJson.containsKey('steeringAngle'), isFalse);
      expect(frameJson['steering'], -0.05);
    });
  });

  group('backend response DTO parsing', () {
    const apiVersion = 'telemetry-one.api.v2';

    Map<String, dynamic> ingestPayload() => {
      'sessionId': 'session_test',
      'receivedFrames': 2,
      'acceptedFrames': 2,
      'rejectedFrames': 0,
      'acceptedFromUnixMs': 1720656000000,
      'acceptedToUnixMs': 1720656000123,
      'status': 'accepted',
    };

    Map<String, dynamic> trackPayload() => {
      'status': 'detected',
      'trackId': 'gt7_watkins_glen_international',
      'layoutId': 'gt7_layout_1240',
      'trackName': 'Watkins Glen International',
      'layoutName': 'Long Course',
      'confidence': 0.85,
      'reasons': ['length_match'],
      'nextAction': 'use_detected_catalog_layout',
    };

    Map<String, dynamic> advicePayload() => {
      'sessionId': 'session_test',
      'status': 'success',
      'message': 'Brake earlier.',
      'referencedEvents': ['event_1'],
      'window': {'sinceUnixMs': null, 'maxEvents': 5},
      'generatedAtUnixMs': 1720656001000,
    };

    Map<String, dynamic> eventsPayload() => {
      'events': [
        {
          'eventId': 'event_1',
          'sessionId': 'session_test',
          'version': 'telemetry-one.engineer-event.v1',
          'type': 'late_throttle',
          'severity': 'medium',
          'confidence': 0.82,
          'timestampUnixMs': 1720656012345,
          'lapNumber': 2,
          'corner': null,
          'source': {
            'kind': 'deterministic_rule',
            'ruleId': 'late_throttle.v1',
          },
        },
      ],
    };

    test('accepts legacy payloads without apiVersion', () {
      final ingest = IngestResponse.fromJson(ingestPayload());
      final track = TrackDetectionResponse.fromJson(trackPayload());
      final advice = RaceEngineerAdviceResponse.fromJson(advicePayload());
      final events = EngineerEvent.listFromResponseJson(eventsPayload());

      expect(ingest.sessionId, 'session_test');
      expect(track.isDetected, isTrue);
      expect(advice.referencedEvents, ['event_1']);
      expect(events.single.source, 'deterministic_rule:late_throttle.v1');
    });

    test('ignores top-level apiVersion on marked payloads', () {
      final ingest = IngestResponse.fromJson({
        'apiVersion': apiVersion,
        ...ingestPayload(),
      });
      final track = TrackDetectionResponse.fromJson({
        'apiVersion': apiVersion,
        ...trackPayload(),
      });
      final advice = RaceEngineerAdviceResponse.fromJson({
        'apiVersion': apiVersion,
        ...advicePayload(),
      });
      final events = EngineerEvent.listFromResponseJson({
        'apiVersion': apiVersion,
        ...eventsPayload(),
      });

      expect(ingest.acceptedFrames, 2);
      expect(track.trackId, 'gt7_watkins_glen_international');
      expect(advice.status, 'success');
      expect(events.single.eventId, 'event_1');
    });

    test('unwraps optional future data envelopes', () {
      final ingest = IngestResponse.fromJson({
        'apiVersion': apiVersion,
        'data': ingestPayload(),
      });
      final track = TrackDetectionResponse.fromJson({
        'apiVersion': apiVersion,
        'data': trackPayload(),
      });
      final create = CreateSessionResponse.fromJson({
        'apiVersion': apiVersion,
        'data': {
          'session': {'id': 'session_created'},
        },
      });
      final finish = FinishSessionResponse.fromJson({
        'apiVersion': apiVersion,
        'data': {'status': 'finished'},
      });
      final events = EngineerEvent.listFromResponseJson({
        'apiVersion': apiVersion,
        'data': eventsPayload(),
      });

      expect(ingest.status, 'accepted');
      expect(track.nextAction, 'use_detected_catalog_layout');
      expect(create.sessionId, 'session_created');
      expect(finish.status, 'finished');
      expect(events.single.lapNumber, 2);
    });

    test('parses race engineer signals from kind-only payloads', () {
      final advice = RaceEngineerAdviceResponse.fromJson({
        'sessionId': 'session_test',
        'status': 'success',
        'message': 'Brake earlier.',
        'signals': [
          {
            'kind': 'off_track_stint_warning',
            'severity': 'warning',
            'summary': 'You spent too long off track.',
          },
        ],
      });

      final signal = advice.visibleSignals.single;

      expect(signal.type, 'off_track_stint_warning');
      expect(signal.isUserFacing, isTrue);
      expect(signal.displayLabel, 'Off Track Stint Warning');
      expect(signal.displayMessage, 'You spent too long off track.');
    });

    test('keeps legacy type and signalType compatibility', () {
      final typeSignal = RaceEngineerSignal.fromJson({
        'type': 'telemetry_gap_warning',
        'message': 'Missing telemetry.',
      });
      final signalTypeSignal = RaceEngineerSignal.fromJson({
        'signalType': 'lap_pace_regression',
        'message': 'Lap pace is slipping.',
      });

      expect(typeSignal.type, 'telemetry_gap_warning');
      expect(typeSignal.isUserFacing, isTrue);
      expect(signalTypeSignal.type, 'lap_pace_regression');
      expect(signalTypeSignal.isUserFacing, isTrue);
    });
  });
}
