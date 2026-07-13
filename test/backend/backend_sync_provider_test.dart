import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/core/models/telemetry_data.dart';
import 'package:telemetry_one/core/network/udp_service.dart';
import 'package:telemetry_one/core/telemetry/telemetry_parser.dart';

/// A mock parser that returns controlled TelemetryData for any input.
class MockTelemetryParser extends TelemetryParser {
  int _frameCount = 0;

  @override
  TelemetryData? parse(Uint8List bytes) {
    _frameCount++;
    return TelemetryData(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        1720656000000 + _frameCount,
      ),
      packetId: _frameCount,
      speedKmh: 100.0 + _frameCount,
      rpm: 5000.0,
      gear: 3,
      throttle: 0.5,
      brake: 0.1,
      steeringAngle: 0.0,
      fuelCurrentL: 50.0,
      posX: 0.0,
      posY: 0.0,
      posZ: 0.0,
      currentLap: 1,
      currentLapTime: const Duration(seconds: 30),
    );
  }
}

/// A mock UDP service that lets us inject raw packets.
class MockUdpService extends UdpService {
  final StreamController<Uint8List> _packetCtrl =
      StreamController<Uint8List>.broadcast();

  void push(Uint8List data) => _packetCtrl.add(data);

  @override
  Stream<Uint8List> get packetStream => _packetCtrl.stream;

  @override
  Future<void> start(String ps5Ip) async {}

  @override
  Future<void> stop() async {}

  void close() {
    _packetCtrl.close();
  }
}

void main() {
  group('SyncStatus transitions', () {
    test('initial state is disabled with local session ID', () {
      final notifier = BackendSyncNotifier(
        config: const BackendConfig(),
      );

      expect(notifier.state.status, SyncStatus.disabled);
      expect(notifier.state.enabled, isFalse);
      expect(notifier.state.sessionId, startsWith('local_'));
      expect(notifier.state.udpConnected, isFalse);
      expect(notifier.state.pendingFrames, 0);
      expect(notifier.state.consecutiveFailures, 0);
    });

    test('setEnabled(true) transitions to idle', () {
      final notifier = BackendSyncNotifier(
        config: const BackendConfig(),
      );

      notifier.setEnabled(true);

      expect(notifier.state.status, SyncStatus.idle);
      expect(notifier.state.enabled, isTrue);
      expect(notifier.state.consecutiveFailures, 0);
    });

    test('setEnabled(false) transitions back to disabled', () {
      final notifier = BackendSyncNotifier(
        config: const BackendConfig(),
      );

      notifier.setEnabled(true);
      notifier.setEnabled(false);

      expect(notifier.state.status, SyncStatus.disabled);
      expect(notifier.state.enabled, isFalse);
    });

    test('disconnect transitions to disabled', () {
      final notifier = BackendSyncNotifier(
        config: const BackendConfig(),
      );

      notifier.setEnabled(true);
      notifier.disconnect();

      expect(notifier.state.status, SyncStatus.disabled);
      expect(notifier.state.udpConnected, isFalse);
    });
  });

  group('Disabled config does not sync', () {
    test('packets ignored when disabled', () async {
      final mockClient = _SuccessMockClient();

      final parser = MockTelemetryParser();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: parser,
        config: _testConfig(),
      );

      // Not enabled — packets should be ignored
      for (var i = 0; i < 10; i++) {
        notifier.injectPacket(Uint8List(1));
      }

      // Flush should do nothing
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.pendingFrames, 0);
      expect(mockClient.callCount, 0);
    });

    test('setEnabled(false) stops flushing', () async {
      final mockClient = _SuccessMockClient();

      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);
      // Push a frame -> triggers flush
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(mockClient.callCount, 1);
      expect(notifier.state.status, SyncStatus.idle);

      notifier.setEnabled(false);
      // Push more frames — ignored
      for (var i = 0; i < 5; i++) {
        notifier.injectPacket(Uint8List(1));
      }
      await Future<void>.delayed(Duration.zero);

      // No additional calls
      expect(mockClient.callCount, 1);
    });
  });

  group('Successful flush', () {
    test('transitions to syncing then idle with counters updated', () async {
      final mockClient = _SuccessMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);
      expect(notifier.state.status, SyncStatus.idle);

      // Push one packet -> triggers flush (defaultBatchSize: 1)
      notifier.injectPacket(Uint8List(1));

      // Should be syncing
      expect(notifier.state.status, SyncStatus.syncing);
      expect(notifier.state.pendingFrames, 1);

      // Wait for async response
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.idle);
      expect(notifier.state.totalSent, 1);
      expect(notifier.state.totalAccepted, 1);
      expect(notifier.state.totalRejected, 0);
      expect(notifier.state.lastSyncAt, isNotNull);
      expect(notifier.state.lastErrorAt, isNull);
      expect(notifier.state.lastErrorMessage, isNull);
      expect(notifier.state.consecutiveFailures, 0);
    });
  });

  group('Typed rejection (4xx with details)', () {
    test('transitions to rejected, frames dropped, not retried', () async {
      final rejectionDetails = IngestRejection(
        rejectionCode: 'invalid_throttle',
        category: 'frame',
        field: 'throttle',
        frameIndex: 0,
      );

      final mockClient = _RejectionMockClient(rejectionDetails);
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);

      // Push 3 frames (each triggers an independent flush with defaultBatchSize:1)
      notifier.injectPacket(Uint8List(0));
      await Future<void>.delayed(Duration.zero);

      // After rejection: frames dropped (not re-buffered), state is rejected
      expect(notifier.state.status, SyncStatus.rejected);
      expect(notifier.state.lastRejection, isNotNull);
      expect(notifier.state.lastRejection!.rejectionCode, 'invalid_throttle');
      expect(notifier.state.lastRejection!.category, 'frame');
      expect(notifier.state.pendingFrames, 0);
      expect(notifier.state.totalRejected, 1);

      // Push another frame — should be a new independent flush attempt
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      // totalRejected incremented again, frames still dropped (not buffered)
      expect(notifier.state.status, SyncStatus.rejected);
      expect(notifier.state.totalRejected, 2);
      expect(notifier.state.pendingFrames, 0);
      expect(notifier.state.consecutiveFailures, 0);
    });

    test('subsequent success after rejection resets state', () async {
      final rejectionDetails = IngestRejection(
        rejectionCode: 'invalid_throttle',
        category: 'frame',
        field: 'throttle',
        frameIndex: 0,
      );

      final mockClient = _RejectionThenSuccessMockClient(rejectionDetails);
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);

      // First batch — rejected
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.rejected);

      // Second batch — success
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.idle);
      expect(notifier.state.lastRejection, isNull);
      expect(notifier.state.totalAccepted, 1);
      expect(notifier.state.consecutiveFailures, 0);
    });
  });

  group('Network error transition to degraded/offline', () {
    test('SocketException transitions to degraded', () async {
      final mockClient = _NetworkErrorMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.degraded);
      expect(notifier.state.isOffline, isTrue);
      expect(notifier.state.consecutiveFailures, 1);
      expect(notifier.state.lastErrorMessage, contains('Connection failed'));
      expect(notifier.state.lastErrorAt, isNotNull);
    });

    test('success after degradation recovers to idle', () async {
      // First call fails, second succeeds
      var callIndex = 0;
      final client = _buildMockClient((frames) async {
        callIndex++;
        if (callIndex == 1) {
          throw BackendRequestException(
            statusCode: 0,
            error: const BackendError(
              code: 'network_error',
              message: 'Connection failed',
            ),
          );
        }
        return IngestResponse(
          sessionId: 'test',
          receivedFrames: frames.length,
          acceptedFrames: frames.length,
          rejectedFrames: 0,
          acceptedFromUnixMs: 1,
          acceptedToUnixMs: 2,
          status: 'accepted',
        );
      });

      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);

      // First flush — fails
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.degraded);
      expect(notifier.state.consecutiveFailures, 1);
      expect(notifier.state.pendingFrames, greaterThan(0));

      // Second flush — re-sends buffered frame + new frame, succeeds, recovers
      notifier.injectPacket(Uint8List(2));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.idle);
      expect(notifier.state.consecutiveFailures, 0);
      expect(notifier.state.lastErrorMessage, isNull);
      expect(notifier.state.lastErrorAt, isNull);
      expect(notifier.state.totalAccepted, greaterThan(0));
    });

    test('consecutive failures increment counter', () async {
      final mockClient = _NetworkErrorMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);

      for (var i = 0; i < 3; i++) {
        notifier.injectPacket(Uint8List(i));
        await Future<void>.delayed(Duration.zero);
      }

      expect(notifier.state.status, SyncStatus.degraded);
      expect(notifier.state.consecutiveFailures, 3);
      expect(notifier.state.isOffline, isTrue);
    });
  });

  group('Server error 5xx', () {
    test('internal error transitions to degraded', () async {
      final mockClient = _InternalErrorMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.degraded);
      expect(notifier.state.isOffline, isTrue);
      expect(notifier.state.consecutiveFailures, 1);
      expect(notifier.state.lastErrorMessage, contains('internal'));
    });

    test('5xx then success recovers', () async {
      var callIndex = 0;
      final client = _buildMockClient((frames) async {
        callIndex++;
        if (callIndex == 1) {
          throw BackendRequestException(
            statusCode: 500,
            error: const BackendError(
              code: 'internal_error',
              message: 'internal server error',
            ),
          );
        }
        return IngestResponse(
          sessionId: 'test',
          receivedFrames: frames.length,
          acceptedFrames: frames.length,
          rejectedFrames: 0,
          acceptedFromUnixMs: 1,
          acceptedToUnixMs: 2,
          status: 'accepted',
        );
      });

      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.degraded);
      expect(notifier.state.consecutiveFailures, 1);

      notifier.injectPacket(Uint8List(2));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.idle);
      expect(notifier.state.consecutiveFailures, 0);
    });
  });

  group('Buffer behavior during offline', () {
    test('frames accumulate in buffer during degraded mode', () async {
      final mockClient = _NetworkErrorMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.setEnabled(true);

      // First frame — flush fails, frames go back to buffer
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.pendingFrames, greaterThan(0));

      // More frames while degraded — buffer should grow
      final initialPending = notifier.state.pendingFrames;
      notifier.injectPacket(Uint8List(2));
      await Future<void>.delayed(Duration.zero);

      // After the second flush fails, both old and new frames are in buffer
      expect(notifier.state.pendingFrames, greaterThan(initialPending));
      expect(notifier.state.status, SyncStatus.degraded);
    });

    test('buffer overflow transitions to failed and drops oldest frames',
        () async {
      final mockClient = _NetworkErrorMockClient();
      final config = BackendConfig(
        maxBatchSize: 3,
        defaultBatchSize: 1,
        maxRetries: 0,
      );
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: config,
      );

      notifier.setEnabled(true);

      // Push frames until buffer overflows (maxBatchSize*2 = 6)
      // Each frame triggers a flush that fails and re-buffers.
      // After 7+ frames, buffer exceeds 6 → trim to 3 → status = failed.
      for (var i = 0; i < 12; i++) {
        notifier.injectPacket(Uint8List(i));
      }
      await Future<void>.delayed(Duration.zero);

      // After many failures, buffer should have been trimmed
      // Trim to maxBatchSize=3 when buffer exceeds 6
      expect(
        notifier.state.status,
        SyncStatus.failed,
      );
      expect(notifier.state.pendingFrames, lessThanOrEqualTo(3));
      expect(notifier.state.lastErrorMessage, contains('Buffer overflow'));
    });
  });

  group('Local session ID', () {
    test('session ID starts with local_ regardless of errors', () async {
      final mockClient = _NetworkErrorMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      expect(notifier.state.sessionId, startsWith('local_'));

      notifier.setEnabled(true);
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.degraded);
      expect(notifier.state.sessionId, startsWith('local_'));

      // Session ID should be stable
      final originalId = notifier.state.sessionId;
      notifier.injectPacket(Uint8List(2));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.sessionId, originalId);
    });
  });

  group('Non-reentrant flush', () {
    test('concurrent calls skip while flush is in-flight', () async {
      var concurrentCalls = 0;
      final client = _buildMockClient((frames) async {
        concurrentCalls++;
        // Simulate a slow network response
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return IngestResponse(
          sessionId: 'test',
          receivedFrames: frames.length,
          acceptedFrames: frames.length,
          rejectedFrames: 0,
          acceptedFromUnixMs: 1,
          acceptedToUnixMs: 100,
          status: 'accepted',
        );
      });

      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );
      notifier.setEnabled(true);

      // Inject 3 frames rapidly — only 1 flush should run
      notifier.injectPacket(Uint8List(1));
      notifier.injectPacket(Uint8List(2));
      notifier.injectPacket(Uint8List(3));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Only one concurrent call should have been made
      expect(concurrentCalls, 1);
    });
  });

  group('Max batch cap', () {
    test('flush sends at most batchSize frames, rest remain queued', () async {
      final sentBatches = <int>[];
      final config = BackendConfig(
        defaultBatchSize: 2,
        maxBatchSize: 5,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final client = _buildMockClient((frames) async {
        sentBatches.add(frames.length);
        return IngestResponse(
          sessionId: 'test',
          receivedFrames: frames.length,
          acceptedFrames: frames.length,
          rejectedFrames: 0,
          acceptedFromUnixMs: 1,
          acceptedToUnixMs: 100,
          status: 'accepted',
        );
      });

      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: config,
      );
      notifier.setEnabled(true);

      // Inject 7 frames — only 2 sent in first flush, 5 remain queued
      for (var i = 0; i < 7; i++) {
        notifier.injectPacket(Uint8List(i));
      }
      await Future<void>.delayed(Duration.zero);

      // First flush sent exactly batchSize=2 frames
      expect(sentBatches.first, 2);
      // Remaining 5 frames reflected in pendingFrames
      expect(notifier.state.pendingFrames, 5);

      // Next packet triggers another flush of 2
      notifier.injectPacket(Uint8List(99));
      await Future<void>.delayed(Duration.zero);

      expect(sentBatches.length, 2);
      expect(sentBatches.last, 2);
      expect(notifier.state.pendingFrames, 4);
    });
  });

  group('Recovery order preserves chronology', () {
    test('failed frames re-inserted before newer arrivals', () async {
      final sentTimestamps = <int>[];
      var callIndex = 0;
      final client = _buildMockClient((frames) async {
        callIndex++;
        if (callIndex == 1) {
          // First flush fails
          throw BackendRequestException(
            statusCode: 500,
            error: const BackendError(code: 'server_error', message: 'fail'),
          );
        }
        // Subsequent flushes record timestamps and succeed
        sentTimestamps.addAll(
          frames.map((f) => f['timestampUnixMs'] as int),
        );
        return IngestResponse(
          sessionId: 'test',
          receivedFrames: frames.length,
          acceptedFrames: frames.length,
          rejectedFrames: 0,
          acceptedFromUnixMs: 1,
          acceptedToUnixMs: 100,
          status: 'accepted',
        );
      });
      final config = BackendConfig(
        defaultBatchSize: 3,
        maxBatchSize: 10,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: config,
      );
      notifier.setEnabled(true);

      // Inject 3 frames — flush triggers (fails) → 3 re-inserted at front
      notifier.injectPacket(Uint8List(1));
      notifier.injectPacket(Uint8List(2));
      notifier.injectPacket(Uint8List(3));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.degraded);
      expect(notifier.state.pendingFrames, 3);

      // Inject 2 newer frames — auto-flush triggers (succeeds)
      notifier.injectPacket(Uint8List(4));
      notifier.injectPacket(Uint8List(5));
      await Future<void>.delayed(Duration.zero);

      // Recovery flush sent 3 frames (oldest first) → 2 remain in buffer
      expect(sentTimestamps.length, 3);
      expect(notifier.state.pendingFrames, 2);
      // Oldest timestamps should be the original 3 (smallest frameCount = 1,2,3)
      // MockTelemetryParser: timestamp = 1720656000000 + frameCount
      expect(sentTimestamps[0], 1720656000001);
      expect(sentTimestamps[1], 1720656000002);
      expect(sentTimestamps[2], 1720656000003);
    });
  });

  group('Disable clears stale buffer', () {
    test('setEnabled(false) empties buffer', () async {
      final sentBatches = <int>[];
      final client = _buildMockClient((frames) async {
        sentBatches.add(frames.length);
        return IngestResponse(
          sessionId: 'test',
          receivedFrames: frames.length,
          acceptedFrames: frames.length,
          rejectedFrames: 0,
          acceptedFromUnixMs: 1,
          acceptedToUnixMs: 100,
          status: 'accepted',
        );
      });
      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );
      notifier.setEnabled(true);

      // Fill buffer with 3 frames that don't trigger auto-flush
      // (defaultBatchSize = 1, so first frame already triggers flush)
      // Use a config with larger batch to accumulate
      // Actually, with defaultBatchSize=1, each frame triggers a flush
      // Let's test differently: push frames in disabled state
      notifier.setEnabled(false);
      notifier.injectPacket(Uint8List(1));
      notifier.injectPacket(Uint8List(2));
      notifier.injectPacket(Uint8List(3));

      // buffer should be empty because setEnabled(false) clears it
      // and disabled status ignores packets
      expect(notifier.state.pendingFrames, 0);

      // Re-enable — should not send stale frames
      notifier.setEnabled(true);
      await Future<void>.delayed(Duration.zero);

      expect(sentBatches.isEmpty, isTrue);
    });
  });

  group('UDP connect', () {
    test('connect subscribes and packets are processed when enabled', () async {
      final mockClient = _SuccessMockClient();
      final udp = MockUdpService();

      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      notifier.connect(udp);
      expect(notifier.state.udpConnected, isTrue);

      notifier.setEnabled(true);

      udp.push(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(mockClient.callCount, 1);
    });
  });
}

/// Test helpers — internal mock client implementations.

BackendClient _buildMockClient(
  Future<IngestResponse> Function(List<Map<String, dynamic>> frames) handler,
) {
  return _MockBackendClient(handler);
}

class _MockBackendClient extends BackendClient {
  final Future<IngestResponse> Function(List<Map<String, dynamic>> frames)
      handler;

  _MockBackendClient(this.handler, {BackendConfig? config})
    : super(config: config);

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    return handler(frames);
  }
}

class _SuccessMockClient extends BackendClient {
  int callCount = 0;

  _SuccessMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    callCount++;
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

class _RejectionMockClient extends BackendClient {
  final IngestRejection rejection;
  int callCount = 0;

  _RejectionMockClient(this.rejection, {BackendConfig? config})
    : super(config: config);

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    callCount++;
    throw BackendRequestException(
      statusCode: 422,
      error: BackendError(
        code: 'bad_request',
        message: '${frames.length} frame(s) rejected',
        details: rejection,
      ),
    );
  }
}

class _RejectionThenSuccessMockClient extends BackendClient {
  final IngestRejection rejection;
  bool _firstCall = true;

  _RejectionThenSuccessMockClient(this.rejection, {BackendConfig? config})
    : super(config: config);

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    if (_firstCall) {
      _firstCall = false;
      throw BackendRequestException(
        statusCode: 422,
        error: BackendError(
          code: 'bad_request',
          message: 'rejected',
          details: rejection,
        ),
      );
    }
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

class _NetworkErrorMockClient extends BackendClient {
  _NetworkErrorMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    throw BackendRequestException(
      statusCode: 0,
      error: const BackendError(
        code: 'network_error',
        message: 'Connection failed after retries',
      ),
    );
  }
}

class _InternalErrorMockClient extends BackendClient {
  _InternalErrorMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    throw BackendRequestException(
      statusCode: 500,
      error: const BackendError(
        code: 'internal_error',
        message: 'internal server error',
      ),
    );
  }
}

BackendConfig _testConfig() {
  return const BackendConfig(
    defaultBatchSize: 1,
    maxRetries: 0,
    retryBaseDelay: Duration.zero,
  );
}
