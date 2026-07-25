import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/core/models/telemetry_data.dart';
import 'package:telemetry_one/core/recording/complete_lap_recorder.dart';
import 'package:telemetry_one/features/dashboard/providers/recording_backend_session_coordinator.dart';
import 'package:telemetry_one/features/dashboard/providers/session_provider.dart';

void main() {
  group('RecordingBackendSessionCoordinator', () {
    test('creates backend session only when local recording auto-starts', () async {
      final client = _SessionCreateMockClient();
      final recorder = SessionRecorder(lapRecorder: CompleteLapRecorder());
      final sync = BackendSyncNotifier(
        client: client,
        config: const BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        ),
      );
      final coordinator = RecordingBackendSessionCoordinator(
        sessionRecorder: recorder,
        backendSync: sync,
        useV2Data: true,
      );

      expect(client.createCallCount, 0);

      coordinator.handleTelemetry(_startPacket());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(recorder.state.isRecording, isTrue);
      expect(sync.state.enabled, isTrue);
      expect(client.createCallCount, 1);
      expect(sync.state.alignmentStatus, SessionAlignmentStatus.created);
      expect(sync.state.backendSessionId, 'session_backend_test_1');
      expect(client.lastBatchSessionId, 'session_backend_test_1');
    });

    test('repeated lap-1 packets do not create duplicate backend sessions', () async {
      final client = _SessionCreateMockClient();
      final recorder = SessionRecorder(lapRecorder: CompleteLapRecorder());
      final sync = BackendSyncNotifier(
        client: client,
        config: const BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        ),
      );
      final coordinator = RecordingBackendSessionCoordinator(
        sessionRecorder: recorder,
        backendSync: sync,
        useV2Data: true,
      );

      coordinator.handleTelemetry(_startPacket(packetId: 10));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      coordinator.handleTelemetry(_startPacket(packetId: 11));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(client.createCallCount, 1);
      expect(sync.state.backendSessionId, 'session_backend_test_1');
    });

    test('session creation failure keeps buffering and never posts with local ID', () async {
      final client = _SessionCreateFailMockClient();
      final recorder = SessionRecorder(lapRecorder: CompleteLapRecorder());
      final sync = BackendSyncNotifier(
        client: client,
        config: const BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        ),
      );
      final coordinator = RecordingBackendSessionCoordinator(
        sessionRecorder: recorder,
        backendSync: sync,
        useV2Data: true,
      );

      coordinator.handleTelemetry(_startPacket(packetId: 21));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(client.createCallCount, 1);
      expect(sync.state.enabled, isTrue);
      expect(sync.state.alignmentStatus, SessionAlignmentStatus.failed);
      expect(sync.state.backendSessionId, isNull);
      expect(client.batchCallCount, 0);
      expect(client.lastBatchSessionId, isNull);

      coordinator.handleTelemetry(_startPacket(packetId: 22));
      await Future<void>.delayed(Duration.zero);

      expect(client.createCallCount, 1);
      expect(client.batchCallCount, 0);
    });
  });
}

TelemetryData _startPacket({
  int packetId = 1,
  int currentLap = 1,
}) {
  return TelemetryData(
    timestamp: DateTime(2026),
    packetId: packetId,
    currentLap: currentLap,
    currentLapTime: const Duration(milliseconds: 500),
    speedKmh: 120,
    gear: 3,
    rpm: 7000,
    throttle: 0.3,
    brake: 0,
  );
}

class _SessionCreateMockClient extends BackendClient {
  int createCallCount = 0;
  int batchCallCount = 0;
  String? lastBatchSessionId;

  _SessionCreateMockClient() : super(config: const BackendConfig());

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    return CreateSessionResponse(sessionId: 'session_backend_test_1');
  }

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    batchCallCount++;
    lastBatchSessionId = sessionId;
    return IngestResponse(
      sessionId: sessionId,
      receivedFrames: frames.length,
      acceptedFrames: frames.length,
      rejectedFrames: 0,
      acceptedFromUnixMs: 1,
      acceptedToUnixMs: 100,
      status: 'accepted',
    );
  }
}

class _SessionCreateFailMockClient extends BackendClient {
  int createCallCount = 0;
  int batchCallCount = 0;
  String? lastBatchSessionId;

  _SessionCreateFailMockClient() : super(config: const BackendConfig());

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    throw BackendRequestException(
      statusCode: 0,
      error: BackendError(
        code: 'network_error',
        message: 'Connection failed',
      ),
    );
  }

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    batchCallCount++;
    lastBatchSessionId = sessionId;
    return IngestResponse(
      sessionId: sessionId,
      receivedFrames: frames.length,
      acceptedFrames: frames.length,
      rejectedFrames: 0,
      acceptedFromUnixMs: 1,
      acceptedToUnixMs: 100,
      status: 'accepted',
    );
  }
}
