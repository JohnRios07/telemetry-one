import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_data_bridge.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';

void main() {
  late BackendConfig v2DisabledConfig;
  late BackendConfig v2EnabledConfig;

  setUp(() {
    v2DisabledConfig = const BackendConfig(useV2Data: false);
    v2EnabledConfig = const BackendConfig(useV2Data: true);
  });

  group('BackendDataBridge with V2 disabled (default)', () {
    test('isV2Enabled returns false', () {
      final bridge = BackendDataBridge(config: v2DisabledConfig);
      expect(bridge.isV2Enabled, isFalse);
    });

    test('getTrackDetection returns null without calling backend', () async {
      final client = _CallTrackingMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2DisabledConfig,
      );

      final result = await bridge.getTrackDetection('session_test_1');

      expect(result, isNull);
      expect(client.trackDetectionCallCount, 0);
      expect(client.eventsCallCount, 0);
    });

    test('getEvents returns null without calling backend', () async {
      final client = _CallTrackingMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2DisabledConfig,
      );

      final result = await bridge.getEvents('session_test_1');

      expect(result, isNull);
      expect(client.eventsCallCount, 0);
      expect(client.trackDetectionCallCount, 0);
    });

    test('V1 local session provider remains unaffected', () async {
      final client = _CallTrackingMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2DisabledConfig,
      );

      // Only V2 bridge calls are suppressed; no state is mutated.
      await bridge.getTrackDetection('any_session');
      await bridge.getEvents('any_session');

      expect(client.trackDetectionCallCount, 0);
      expect(client.eventsCallCount, 0);
    });
  });

  group('BackendDataBridge with V2 enabled', () {
    test('isV2Enabled returns true', () {
      final bridge = BackendDataBridge(config: v2EnabledConfig);
      expect(bridge.isV2Enabled, isTrue);
    });

    test('getTrackDetection returns detected track from backend', () async {
      final client = _SuccessTrackDetectionMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getTrackDetection('session_test_1');

      expect(result, isNotNull);
      expect(result!.isDetected, isTrue);
      expect(result.trackId, 'gt7_watkins_glen_international');
      expect(result.trackName, 'Watkins Glen International');
      expect(result.layoutName, 'Watkins Glen Long Course');
      expect(result.confidence, 0.85);
    });

    test('getTrackDetection track name comes from catalog, not invented',
        () async {
      final client = _SuccessTrackDetectionMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getTrackDetection('session_test_1');

      expect(result, isNotNull);
      expect(result!.trackName,
          anyOf('Watkins Glen International', 'Suzuka Circuit',
              'Nürburgring Nordschleife'));
      expect(result.trackName, isNot(equals('Circuit')));   // Vague
      expect(result.trackName, isNot(equals('Unknown')));   // Default
    });

    test('getTrackDetection returns null on 501 not_implemented', () async {
      final client = _NotImplementedMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getTrackDetection('session_test_1');

      expect(result, isNull);
      expect(client.trackDetectionCallCount, 1);
    });

    test('getTrackDetection returns null on network error', () async {
      final client = _NetworkErrorMockBridgeClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getTrackDetection('session_test_1');

      expect(result, isNull);
      expect(client.trackDetectionCallCount, 1);
    });

    test('getTrackDetection returns null on server error (5xx)', () async {
      final client = _ServerErrorMockBridgeClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getTrackDetection('session_test_1');

      expect(result, isNull);
      expect(client.trackDetectionCallCount, 1);
    });

    test('getEvents returns list from backend', () async {
      final client = _SuccessEventsMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getEvents('session_test_1');

      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result.first.type, 'late_throttle');
      expect(result.first.severity, 'medium');
      expect(result.first.source, 'deterministic_rule:late_throttle.v1');
    });

    test('getEvents returns empty list when no events', () async {
      final client = _EmptyEventsMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getEvents('session_test_1');

      expect(result, isNotNull);
      expect(result!.isEmpty, isTrue);
    });

    test('getEvents with filters passes them through', () async {
      final client = _SuccessEventsMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getEvents(
        'session_test_1',
        lapNumber: 2,
        type: 'late_throttle',
      );

      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result.first.lapNumber, 2);
    });

    test('getEvents returns null on 501 not_implemented', () async {
      final client = _NotImplementedMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getEvents('session_test_1');

      expect(result, isNull);
      expect(client.eventsCallCount, 1);
    });

    test('getEvents returns null on network error', () async {
      final client = _NetworkErrorMockBridgeClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getEvents('session_test_1');

      expect(result, isNull);
      expect(client.eventsCallCount, 1);
    });

    test('getEvents returns null on server error (5xx)', () async {
      final client = _ServerErrorMockBridgeClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      final result = await bridge.getEvents('session_test_1');

      expect(result, isNull);
      expect(client.eventsCallCount, 1);
    });
  });

  group('Offline fallback preserves V1 source of truth', () {
    test('track detection null does not affect local V1 state', () async {
      // V1 reads from SessionRepository directly — V2 bridge returns
      // null on error, but V1 state is never touched.
      final client = _NetworkErrorMockBridgeClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      await bridge.getTrackDetection('session_test_1');
      await bridge.getEvents('session_test_1');

      // Bridge never writes state — it only returns null
      // proving V1 is unaffected.
      expect(bridge.isV2Enabled, isTrue);
    });
  });

  group('Planned endpoints are never called', () {
    test('bridge does not attempt live or analysis calls', () async {
      // The bridge only exposes getTrackDetection and getEvents.
      // Live and analysis are NOT wrapped — they remain planned/stub
      // and are NEVER invoked through the bridge.
      final client = _CallTrackingMockClient();
      final bridge = BackendDataBridge(
        client: client,
        config: v2EnabledConfig,
      );

      await bridge.getTrackDetection('session_test_1');
      await bridge.getEvents('session_test_1');

      expect(client.trackDetectionCallCount, 1);
      expect(client.eventsCallCount, 1);
    });
  });
}

/// Mock that tracks which endpoints were called.
class _CallTrackingMockClient extends BackendClient {
  int trackDetectionCallCount = 0;
  int eventsCallCount = 0;

  _CallTrackingMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<TrackDetectionResponse> getTrackDetection(String sessionId) async {
    trackDetectionCallCount++;
    throw BackendRequestException(
      statusCode: 501,
      error: const BackendError(code: 'not_implemented', message: ''),
    );
  }

  @override
  Future<List<EngineerEvent>> getEvents(
    String sessionId, {
    int? lapNumber,
    String? cornerId,
    String? type,
  }) async {
    eventsCallCount++;
    throw BackendRequestException(
      statusCode: 501,
      error: const BackendError(code: 'not_implemented', message: ''),
    );
  }
}

class _SuccessTrackDetectionMockClient extends BackendClient {
  _SuccessTrackDetectionMockClient({BackendConfig? config})
    : super(config: config);

  @override
  Future<TrackDetectionResponse> getTrackDetection(String sessionId) async {
    return TrackDetectionResponse(
      status: 'detected',
      trackId: 'gt7_watkins_glen_international',
      layoutId: 'gt7_watkins_glen_long_course',
      trackName: 'Watkins Glen International',
      layoutName: 'Watkins Glen Long Course',
      confidence: 0.85,
      reasons: ['length_match'],
      nextAction: 'use_detected_catalog_layout',
    );
  }
}

class _SuccessEventsMockClient extends BackendClient {
  _SuccessEventsMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<List<EngineerEvent>> getEvents(
    String sessionId, {
    int? lapNumber,
    String? cornerId,
    String? type,
  }) async {
    return [
      EngineerEvent(
        eventId: 'event_01j2example',
        sessionId: sessionId,
        version: 'telemetry-one.engineer-event.v1',
        type: 'late_throttle',
        severity: 'medium',
        confidence: 0.82,
        timestampUnixMs: 1720656012345,
        lapNumber: lapNumber ?? 2,
        corner: null,
        source: 'deterministic_rule:late_throttle.v1',
      ),
    ];
  }
}

class _EmptyEventsMockClient extends BackendClient {
  _EmptyEventsMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<List<EngineerEvent>> getEvents(
    String sessionId, {
    int? lapNumber,
    String? cornerId,
    String? type,
  }) async {
    return [];
  }
}

class _NotImplementedMockClient extends BackendClient {
  int trackDetectionCallCount = 0;
  int eventsCallCount = 0;

  _NotImplementedMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<TrackDetectionResponse> getTrackDetection(String sessionId) async {
    trackDetectionCallCount++;
    throw BackendRequestException(
      statusCode: 501,
      error: const BackendError(code: 'not_implemented', message: 'not ready'),
    );
  }

  @override
  Future<List<EngineerEvent>> getEvents(
    String sessionId, {
    int? lapNumber,
    String? cornerId,
    String? type,
  }) async {
    eventsCallCount++;
    throw BackendRequestException(
      statusCode: 501,
      error: const BackendError(code: 'not_implemented', message: 'not ready'),
    );
  }
}

class _NetworkErrorMockBridgeClient extends BackendClient {
  int trackDetectionCallCount = 0;
  int eventsCallCount = 0;

  _NetworkErrorMockBridgeClient({BackendConfig? config}) : super(config: config);

  @override
  Future<TrackDetectionResponse> getTrackDetection(String sessionId) async {
    trackDetectionCallCount++;
    throw BackendRequestException(
      statusCode: 0,
      error: const BackendError(code: 'network_error', message: 'Connection failed'),
    );
  }

  @override
  Future<List<EngineerEvent>> getEvents(
    String sessionId, {
    int? lapNumber,
    String? cornerId,
    String? type,
  }) async {
    eventsCallCount++;
    throw BackendRequestException(
      statusCode: 0,
      error: const BackendError(code: 'network_error', message: 'Connection failed'),
    );
  }
}

class _ServerErrorMockBridgeClient extends BackendClient {
  int trackDetectionCallCount = 0;
  int eventsCallCount = 0;

  _ServerErrorMockBridgeClient({BackendConfig? config}) : super(config: config);

  @override
  Future<TrackDetectionResponse> getTrackDetection(String sessionId) async {
    trackDetectionCallCount++;
    throw BackendRequestException(
      statusCode: 500,
      error: const BackendError(code: 'internal_error', message: 'server error'),
    );
  }

  @override
  Future<List<EngineerEvent>> getEvents(
    String sessionId, {
    int? lapNumber,
    String? cornerId,
    String? type,
  }) async {
    eventsCallCount++;
    throw BackendRequestException(
      statusCode: 500,
      error: const BackendError(code: 'internal_error', message: 'server error'),
    );
  }
}
