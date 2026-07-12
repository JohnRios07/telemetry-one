import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';

void main() {
  group('BackendClient', () {
    late HttpServer _server;
    late int _port;
    late BackendClient _client;
    late List<Map<String, dynamic>> _receivedRequests;

    setUp(() async {
      _receivedRequests = [];
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server.port;
      _client = BackendClient(
        config: BackendConfig(
          baseUrl: 'http://127.0.0.1:$_port',
          maxRetries: 0,
          requestTimeout: const Duration(seconds: 5),
        ),
      );

      _server.listen((HttpRequest request) async {
        final body = await utf8.decodeStream(request);
        _receivedRequests.add({
          'method': request.method,
          'uri': request.uri.toString(),
          'body': body,
        });

        final path = request.uri.path;

        if (path.endsWith('/frames') && request.method == 'POST') {
          request.response.statusCode = 202;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'sessionId': 'session_test_1',
            'receivedFrames': 2,
            'acceptedFrames': 2,
            'rejectedFrames': 0,
            'acceptedFromUnixMs': 1720656000123,
            'acceptedToUnixMs': 1720656000456,
            'status': 'accepted',
          }));
          request.response.close();
        } else if (path.endsWith('/track') && request.method == 'GET') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'status': 'detected',
            'trackId': 'gt7_watkins_glen_international',
            'confidence': 0.85,
            'reasons': ['length_match'],
            'nextAction': 'use_detected_catalog_layout',
          }));
          request.response.close();
        } else if (path.endsWith('/events') && request.method == 'GET') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'sessionId': 'session_test_1',
            'events': [
              {
                'eventId': 'event_01j2example',
                'sessionId': 'session_test_1',
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
                'source': {
                  'kind': 'deterministic_rule',
                  'ruleId': 'late_throttle.v1',
                  'ruleVersion': 'v1',
                },
              },
            ],
          }));
          request.response.close();
        } else {
          request.response.statusCode = 404;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'error': {'code': 'not_found', 'message': 'not found'},
          }));
          request.response.close();
        }
      });
    });

    tearDown(() async {
      _client.dispose();
      await _server.close(force: true);
    });

    test('postFrameBatch returns accepted response', () async {
      final response = await _client.postFrameBatch('session_test_1', [
        {
          'timestampUnixMs': 1720656000123,
          'speedMps': 58.33,
          'rpm': 7100,
          'gear': 4,
          'throttle': 0.82,
          'brake': 0,
          'steeringAngle': -0.12,
          'fuelLiters': 38.4,
          'positionX': 123.4,
          'positionY': 5.6,
          'positionZ': 789.1,
          'lapNumber': 2,
          'currentLapMs': 81234,
          'isOnTrack': true,
        },
      ]);

      expect(response.isAccepted, isTrue);
      expect(response.receivedFrames, 2);
      expect(response.acceptedFrames, 2);
      expect(_receivedRequests, hasLength(1));
    });

    test('getTrackDetection returns parsed response', () async {
      final response = await _client.getTrackDetection('session_test_1');

      expect(response.isDetected, isTrue);
      expect(response.trackId, 'gt7_watkins_glen_international');
      expect(response.confidence, 0.85);
    });

    test('getEvents returns list of events', () async {
      final events = await _client.getEvents('session_test_1');

      expect(events, hasLength(1));
      expect(events.first.type, 'late_throttle');
    });

    test('getEvents with filters', () async {
      final events = await _client.getEvents(
        'session_test_1',
        lapNumber: 2,
        type: 'late_throttle',
      );

      expect(events, hasLength(1));
      expect(events.first.lapNumber, 2);
    });

    test('throws on server error with typed rejection details', () async {
      final server2 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port2 = server2.port;

      server2.listen((HttpRequest request) {
        request.response.statusCode = 422;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'error': {
            'code': 'bad_request',
            'message': 'frames[0]: invalid data',
            'details': {
              'rejectionCode': 'invalid_throttle',
              'category': 'frame',
              'field': 'throttle',
              'frameIndex': 0,
            },
          },
        }));
        request.response.close();
      });

      final client = BackendClient(
        config: BackendConfig(
          baseUrl: 'http://127.0.0.1:$port2',
        ),
      );

      try {
        await client.postFrameBatch('session_test_1', [
          {'bad': true},
        ]);
        fail('Expected BackendRequestException');
      } on BackendRequestException catch (e) {
        expect(e.error.code, 'bad_request');
        expect(e.error.details, isNotNull);
        expect(e.error.details!.rejectionCode, 'invalid_throttle');
        expect(e.error.details!.frameIndex, 0);
      } finally {
        client.dispose();
        await server2.close(force: true);
      }
    });

    test('retries on network error then succeeds', () async {
      final client = BackendClient(
        config: BackendConfig(
          baseUrl: 'http://127.0.0.1:1',
          maxRetries: 1,
          retryBaseDelay: const Duration(milliseconds: 10),
        ),
      );

      try {
        await client.postFrameBatch('session_test_1', [
          {'test': true},
        ]);
        fail('Expected exception');
      } on BackendRequestException catch (e) {
        expect(e.error.code, 'network_error');
      } finally {
        client.dispose();
      }
    });

    test('does not retry on 4xx bad_request', () async {
      final server2 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port2 = server2.port;

      var callCount = 0;
      server2.listen((HttpRequest request) {
        callCount++;
        request.response.statusCode = 400;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'error': {
            'code': 'bad_request',
            'message': 'invalid data',
            'details': {
              'rejectionCode': 'invalid_throttle',
              'category': 'frame',
              'field': 'throttle',
              'frameIndex': 0,
            },
          },
        }));
        request.response.close();
      });

      final client = BackendClient(
        config: BackendConfig(
          baseUrl: 'http://127.0.0.1:$port2',
          maxRetries: 2,
          retryBaseDelay: const Duration(milliseconds: 5),
        ),
      );

      try {
        await client.postFrameBatch('session_test_1', [
          {'bad': true},
        ]);
        fail('Expected exception');
      } on BackendRequestException catch (e) {
        expect(e.error.code, 'bad_request');
        expect(e.error.details, isNotNull);
        expect(e.error.details!.rejectionCode, 'invalid_throttle');
      } finally {
        client.dispose();
        await server2.close(force: true);
      }

      expect(callCount, 1);
    });
  });
}
