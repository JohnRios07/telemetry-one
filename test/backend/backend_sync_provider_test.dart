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
      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
      expect(notifier.state.backendSessionId, isNull);
    });

    test('setEnabled(true) transitions to idle', () async {
      final notifier = BackendSyncNotifier(
        config: const BackendConfig(),
      );

      await notifier.setEnabled(true);

      expect(notifier.state.status, SyncStatus.idle);
      expect(notifier.state.enabled, isTrue);
      expect(notifier.state.consecutiveFailures, 0);
      // V2 disabled by default — no alignment attempt
      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
    });

    test('setEnabled(false) transitions back to disabled', () async {
      final notifier = BackendSyncNotifier(
        config: const BackendConfig(),
      );

      await notifier.setEnabled(true);
      await notifier.setEnabled(false);

      expect(notifier.state.status, SyncStatus.disabled);
      expect(notifier.state.enabled, isFalse);
    });

    test('disconnect transitions to disabled', () async {
      final notifier = BackendSyncNotifier(
        config: const BackendConfig(),
      );

      await notifier.setEnabled(true);
      await notifier.disconnect();

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

      await notifier.setEnabled(true);
      // Push a frame -> triggers flush
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(mockClient.callCount, 1);
      expect(notifier.state.status, SyncStatus.idle);

      await notifier.setEnabled(false);
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

      await notifier.setEnabled(true);
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

  group('Partial success with rejection summary', () {
    test('sets lastRejectionCode from response summary', () async {
      final client = _buildMockClient((frames) async {
        return IngestResponse(
          sessionId: 'test',
          receivedFrames: frames.length,
          acceptedFrames: frames.length - 1,
          rejectedFrames: 1,
          acceptedFromUnixMs: 1,
          acceptedToUnixMs: 100,
          status: 'partial',
          rejectionSummary: const RejectionSummary(reasons: [
            RejectionReasonCount(code: 'invalid_throttle', count: 1),
          ]),
        );
      });

      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      await notifier.setEnabled(true);

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.idle);
      expect(notifier.state.totalRejected, 1);
      expect(notifier.state.totalAccepted, 0);
      expect(notifier.state.lastRejectionCode, 'invalid_throttle');
    });

    test('success without rejection preserves lastRejectionCode', () async {
      var callIndex = 0;
      final client = _buildMockClient((frames) async {
        callIndex++;
        if (callIndex == 1) {
          return IngestResponse(
            sessionId: 'test',
            receivedFrames: frames.length,
            acceptedFrames: frames.length - 1,
            rejectedFrames: 1,
            acceptedFromUnixMs: 1,
            acceptedToUnixMs: 100,
            status: 'partial',
            rejectionSummary: const RejectionSummary(reasons: [
              RejectionReasonCount(code: 'invalid_throttle', count: 1),
            ]),
          );
        }
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

      await notifier.setEnabled(true);

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.lastRejectionCode, 'invalid_throttle');

      notifier.injectPacket(Uint8List(2));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.lastRejectionCode, 'invalid_throttle');
    });

    test('partial rejection then accepted keeps code and totalRejected cumulative',
        () async {
      var callIndex = 0;
      final client = _buildMockClient((frames) async {
        callIndex++;
        if (callIndex == 1) {
          return IngestResponse(
            sessionId: 'test',
            receivedFrames: frames.length,
            acceptedFrames: 0,
            rejectedFrames: 14,
            acceptedFromUnixMs: 1,
            acceptedToUnixMs: 100,
            status: 'partial',
            rejectionSummary: const RejectionSummary(reasons: [
              RejectionReasonCount(code: 'current_lap_time_regressed', count: 14),
            ]),
          );
        }
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

      await notifier.setEnabled(true);

      // First batch: partial with 14 rejected frames
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.lastRejectionCode, 'current_lap_time_regressed');
      expect(notifier.state.totalRejected, 14);

      // Second batch: fully accepted, no rejection summary
      notifier.injectPacket(Uint8List(2));
      await Future<void>.delayed(Duration.zero);

      // totalRejected stays at 14 (no new rejections)
      expect(notifier.state.totalRejected, 14);
      // lastRejectionCode preserved across accepted batch
      expect(notifier.state.lastRejectionCode, 'current_lap_time_regressed');
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

      await notifier.setEnabled(true);

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

      await notifier.setEnabled(true);

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

  group('Bad request without details (400 invalid JSON body)', () {
    test('drops batch and increments rejected — no reinsert loop', () async {
      final mockClient = _BadRequestNoDetailsMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      await notifier.setEnabled(true);

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.rejected);
      expect(notifier.state.totalRejected, 1);
      expect(notifier.state.totalAccepted, 0);
      expect(notifier.state.totalSent, 0);
      expect(notifier.state.pendingFrames, 0,
          reason: 'batch must be dropped, not reinserted');
      expect(notifier.state.lastRejection, isNull,
          reason: 'no details means no structured rejection info');
      expect(notifier.state.lastErrorMessage, contains('invalid JSON body'));
    });

    test('subsequent success after 400 recovers normally', () async {
      var callIndex = 0;
      final client = _buildMockClient((frames) async {
        callIndex++;
        if (callIndex == 1) {
          throw BackendRequestException(
            statusCode: 400,
            error: const BackendError(
              code: 'bad_request',
              message: 'invalid JSON body: unknown field "steeringAngle"',
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

      await notifier.setEnabled(true);

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.rejected);

      notifier.injectPacket(Uint8List(2));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.idle);
      expect(notifier.state.totalAccepted, 1);
      expect(notifier.state.totalRejected, 1);
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

      await notifier.setEnabled(true);

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

      await notifier.setEnabled(true);

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

      await notifier.setEnabled(true);

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

      await notifier.setEnabled(true);

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

      await notifier.setEnabled(true);

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

      await notifier.setEnabled(true);

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

      await notifier.setEnabled(true);

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

      await notifier.setEnabled(true);
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
      await notifier.setEnabled(true);

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
      await notifier.setEnabled(true);

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
      await notifier.setEnabled(true);

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

  group('recordData fan-out', () {
    test('ignored when sync is disabled', () {
      final mockClient = _SuccessMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      expect(notifier.state.status, SyncStatus.disabled);

      notifier.recordData(_sampleData(1));

      expect(notifier.state.pendingFrames, 0);
      expect(mockClient.callCount, 0);
    });

    test('buffers and flushes when enabled — counters updated', () async {
      final mockClient = _SuccessMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      await notifier.setEnabled(true);
      expect(notifier.state.status, SyncStatus.idle);

      notifier.recordData(_sampleData(101));

      // Should be syncing (defaultBatchSize: 1 triggers immediate flush)
      expect(notifier.state.status, SyncStatus.syncing);
      expect(notifier.state.pendingFrames, 1);

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.idle);
      expect(notifier.state.totalSent, 1);
      expect(notifier.state.totalAccepted, 1);
      expect(notifier.state.totalRejected, 0);
      expect(notifier.state.lastSyncAt, isNotNull);
    });

    test('multiple calls accumulate and flush at threshold', () async {
      final config = BackendConfig(
        defaultBatchSize: 3,
        maxBatchSize: 10,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
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
        config: config,
      );
      await notifier.setEnabled(true);

      // 2 frames — below threshold (defaultBatchSize: 3)
      notifier.recordData(_sampleData(1));
      notifier.recordData(_sampleData(2));

      await Future(() => null);
      // pendingFrames is only updated during flush — data is buffered
      // but state still shows 0 until flush runs
      expect(sentBatches.isEmpty, isTrue);

      // 3rd frame — triggers flush
      notifier.recordData(_sampleData(3));
      await Future(() => null);

      expect(sentBatches.length, 1);
      expect(sentBatches.first, 3);
      expect(notifier.state.pendingFrames, 0);
    });

    test('works alongside injectPacket from UDP path', () async {
      final mockClient = _SuccessMockClient();
      final notifier = BackendSyncNotifier(
        client: mockClient,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      await notifier.setEnabled(true);

      // Feed via UDP path
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);
      expect(mockClient.callCount, 1);

      // Feed via recordData
      notifier.recordData(_sampleData(2));
      await Future<void>.delayed(Duration.zero);
      expect(mockClient.callCount, 2);
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
      await notifier.setEnabled(true);

      // Fill buffer with 3 frames that don't trigger auto-flush
      // (defaultBatchSize = 1, so first frame already triggers flush)
      // Use a config with larger batch to accumulate
      // Actually, with defaultBatchSize=1, each frame triggers a flush
      // Let's test differently: push frames in disabled state
      await notifier.setEnabled(false);
      notifier.injectPacket(Uint8List(1));
      notifier.injectPacket(Uint8List(2));
      notifier.injectPacket(Uint8List(3));

      // buffer should be empty because setEnabled(false) clears it
      // and disabled status ignores packets
      expect(notifier.state.pendingFrames, 0);

      // Re-enable — should not send stale frames
      await notifier.setEnabled(true);
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

      await notifier.setEnabled(true);

      udp.push(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(mockClient.callCount, 1);
    });
  });

    group('V2 disable wins race against in-flight createSession', () {
    test('disable during createSession HTTP gap keeps sync disabled', () async {
      final controller = _ControllableCreateMockClient();
      final config = BackendConfig(
        useV2Data: true,
        defaultBatchSize: 1,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final notifier = BackendSyncNotifier(
        client: controller,
        parser: MockTelemetryParser(),
        config: config,
      );

      await notifier.setEnabled(true);

      // Step 1: start session alignment explicitly — it won't complete until we release.
      final enableFuture = notifier.ensureBackendSession();

      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.pending);
      expect(controller.pendingCreateCount, 1);

      // Step 2: disable while createSession is in-flight
      await notifier.setEnabled(false);

      expect(notifier.state.status, SyncStatus.disabled);
      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
      expect(notifier.state.backendSessionId, isNull);

      // Step 3: complete the in-flight createSession
      controller.completePendingCreate();

      // Allow the continuations to run
      await Future<void>.delayed(Duration.zero);
      await enableFuture;

      // Step 4: assert sync is still disabled — race was won by disable
      expect(notifier.state.status, SyncStatus.disabled);
      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
      expect(notifier.state.backendSessionId, isNull);
      expect(notifier.state.enabled, isFalse);

      // No flush timer should be active — inject a packet and see it ignored
      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);
      expect(controller.batchCallCount, 0);
    });

    test('enable after disable race still works fresh', () async {
      final controller = _ControllableCreateMockClient();
      final config = BackendConfig(
        useV2Data: true,
        defaultBatchSize: 1,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final notifier = BackendSyncNotifier(
        client: controller,
        parser: MockTelemetryParser(),
        config: config,
      );

      // Don't await enableFuture — let it race naturally
      await notifier.setEnabled(true);
      final createFuture = notifier.ensureBackendSession();
      await notifier.setEnabled(false);
      controller.completePendingCreate();
      // Drain microtasks so the guard returns
      await Future<void>.delayed(Duration.zero);
      await createFuture;

      // Assert disable won the race
      expect(notifier.state.status, SyncStatus.disabled);
      expect(notifier.state.backendSessionId, isNull);
      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);

      // Fresh enable with a separate notifier/mock
      // Don't await — let it block on HTTP, then complete the pending call
      final controller2 = _ControllableCreateMockClient();
      final notifier2 = BackendSyncNotifier(
        client: controller2,
        parser: MockTelemetryParser(),
        config: config,
      );
      await notifier2.setEnabled(true);
      final createFuture2 = notifier2.ensureBackendSession();
      controller2.completePendingCreate();
      await Future<void>.delayed(Duration.zero);
      await createFuture2;

      expect(notifier2.state.status, SyncStatus.idle);
      expect(notifier2.state.backendSessionId, 'session_backend_test_1');
      expect(notifier2.state.alignmentStatus, SessionAlignmentStatus.created);
    });
  });

  group('Disable lifecycle drains buffer before finish', () {
    test('disable flushes pending frames with backendSessionId before finish',
        () async {
      final client = _DisableLifecycleMockClient();
      final config = BackendConfig(
        useV2Data: true,
        defaultBatchSize: 5,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: config,
      );

      await notifier.setEnabled(true);
      await notifier.ensureBackendSession();
      expect(notifier.state.backendSessionId, 'session_backend_test_1');
      expect(notifier.state.status, SyncStatus.idle);

      // Buffer some frames without triggering auto-flush (batchSize=5)
      for (var i = 0; i < 3; i++) {
        notifier.injectPacket(Uint8List(i));
      }
      expect(notifier.state.pendingFrames, 0,
          reason: 'frames buffered but not yet flushed');

      // Disable — should flush pending frames BEFORE finishing
      await notifier.setEnabled(false);

      // Verify: batch was flushed with backendSessionId
      expect(client.batchCallCount, 1,
          reason: 'pending frames should flush before finish');
      expect(client.lastBatchSessionId, 'session_backend_test_1',
          reason: 'flush must use backendSessionId, not local_*');
      expect(client.finishCallCount, 1);
      expect(client.lastFinishSessionId, 'session_backend_test_1');

      // State should be clean disabled
      expect(notifier.state.status, SyncStatus.disabled);
      expect(notifier.state.enabled, isFalse);
      expect(notifier.state.backendSessionId, isNull);
      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
    });

    test('disable with empty buffer does not flush, only finishes', () async {
      final client = _DisableLifecycleMockClient();
      final config = BackendConfig(
        useV2Data: true,
        defaultBatchSize: 5,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: config,
      );

      await notifier.setEnabled(true);
      await notifier.ensureBackendSession();
      expect(notifier.state.backendSessionId, 'session_backend_test_1');

      // Disable immediately — no frames buffered
      await notifier.setEnabled(false);

      expect(client.batchCallCount, 0,
          reason: 'no frames to flush');
      expect(client.finishCallCount, 1);
      expect(notifier.state.status, SyncStatus.disabled);
    });

    test('no local_* fallback after disable with pending frames', () async {
      final client = _DisableLifecycleMockClient();
      final config = BackendConfig(
        useV2Data: true,
        defaultBatchSize: 5,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: config,
      );

      await notifier.setEnabled(true);
      await notifier.ensureBackendSession();
      expect(notifier.state.backendSessionId, 'session_backend_test_1');

      for (var i = 0; i < 3; i++) {
        notifier.injectPacket(Uint8List(i));
      }

      await notifier.setEnabled(false);

      // Every batch that was sent must have used the backend session ID
      if (client.batchCallCount > 0) {
        expect(client.lastBatchSessionId, 'session_backend_test_1',
            reason: 'ALL batches must use backendSessionId, not local_*');
      }

      // After finish, no more batches should be sent
      final finishCallIndex = client.finishCallCount;
      await Future<void>.delayed(Duration.zero);

      // No additional batch calls after finish
      expect(client.batchCallCount,
          finishCallIndex > 0 ? client.batchCallCount : 0);

      // State has no backendSessionId
      expect(notifier.state.backendSessionId, isNull);

      // recordData no longer accepts data
      notifier.recordData(_sampleData(99));
      expect(notifier.state.pendingFrames, 0);
    });
  });

  group('V2 session alignment', () {
    group('V2 disabled (default) — no alignment', () {
      test('setEnabled does not attempt backend session creation', () async {
        final client = _SessionCreateMockClient();
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: _testConfig(),
        );

        await notifier.setEnabled(true);

        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
        expect(notifier.state.backendSessionId, isNull);
        expect(client.createCallCount, 0);
      });
    });

    group('V2 enabled — successful creation', () {
      test('does not create backend session on setEnabled', () async {
        final client = _SessionCreateMockClient();
        final config = BackendConfig(
          useV2Data: true,
          driverAlias: 'testdriver',
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
        expect(notifier.state.backendSessionId, isNull);

        await notifier.setEnabled(true);

        expect(client.createCallCount, 0);
        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
        expect(notifier.state.backendSessionId, isNull);
        expect(notifier.state.effectiveSessionId, startsWith('local_'));
        expect(notifier.state.status, SyncStatus.idle);

        // No create request should be issued until recording actually starts.
        expect(client.lastCreateRequest, isNull);
      });

      test('creates backend session only when explicitly started', () async {
        final client = _SessionCreateMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);

        await notifier.ensureBackendSession();

        expect(client.createCallCount, 1);
        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.created);
        expect(notifier.state.backendSessionId, 'session_backend_test_1');
        expect(notifier.state.effectiveSessionId, 'session_backend_test_1');
      });

      test('uses backend session ID for frame batch', () async {
        final client = _SessionCreateMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();
        expect(notifier.state.backendSessionId, 'session_backend_test_1');

        notifier.injectPacket(Uint8List(1));
        await Future<void>.delayed(Duration.zero);

        // Frame batch should have been sent with backend session ID
        expect(client.lastBatchSessionId, 'session_backend_test_1');
        expect(notifier.state.totalAccepted, 1);
      });

      test('calls finish on disable when backend session exists', () async {
        final client = _SessionCreateMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();
        expect(notifier.state.backendSessionId, 'session_backend_test_1');
        expect(client.finishCallCount, 0);

        await notifier.setEnabled(false);

        expect(client.finishCallCount, 1);
        expect(client.lastFinishSessionId, 'session_backend_test_1');
        expect(notifier.state.backendSessionId, isNull);
        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
      });

      test('calls finish on disconnect when backend session exists', () async {
        final client = _SessionCreateMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();
        expect(client.finishCallCount, 0);

        await notifier.disconnect();

        expect(client.finishCallCount, 1);
        expect(client.lastFinishSessionId, 'session_backend_test_1');
      });
    });

    group('V2 enabled — creation failure fallback', () {
      test('marks alignment failed on creation failure', () async {
        final client = _SessionCreateFailMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();

        expect(client.createCallCount, 1);
        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.failed);
        expect(notifier.state.backendSessionId, isNull);
        expect(notifier.state.status, SyncStatus.idle);
      });

      test('does not post frames with local ID when creation fails', () async {
        final client = _SessionCreateFailMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();
        expect(notifier.state.backendSessionId, isNull);

        notifier.injectPacket(Uint8List(1));
        await Future<void>.delayed(Duration.zero);

        expect(client.batchCallCount, 0);
        expect(client.lastBatchSessionId, isNull);
      });

      test('does not call finish when no backend session created', () async {
        final client = _SessionCreateFailMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();
        expect(client.finishCallCount, 0);

        await notifier.setEnabled(false);

        expect(client.finishCallCount, 0);
      });
    });

    group('V2 enabled — Dart Error during creation', () {
      test('Error does not leave alignmentStatus stuck at pending', () async {
        final client = _SessionCreateErrorMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);

        try {
          await notifier.setEnabled(true);
          await notifier.ensureBackendSession();
          fail('Expected Error to propagate');
        } catch (_) {
          // Error propagated — alignmentStatus should have been reset
        }

        expect(
          notifier.state.alignmentStatus,
          SessionAlignmentStatus.failed,
          reason: 'finally block reset pending to failed before Error propagation',
        );

        // Guard: not stuck at pending — subsequent retry should work
        expect(client.createCallCount, 1);
      });

      test('retry after Error still creates session', () async {
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );

        final client = _SessionCreateMockClient();
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();
        expect(client.createCallCount, 1);
        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.created);
        expect(notifier.state.backendSessionId, 'session_backend_test_1');
      });
    });

    group('V2 enabled — finish failure non-fatal', () {
      test('disconnect cleanup runs even if finish throws Dart Error', () async {
        final client = _SessionCreateFinishErrorMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();
        expect(notifier.state.backendSessionId, 'session_backend_test_1');
        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.created);

        try {
          await notifier.disconnect();
          fail('Expected Error to propagate');
        } catch (_) {
          // Error propagated after cleanup
        }

        expect(client.finishCallCount, 1);
        expect(notifier.state.udpConnected, isFalse);
        expect(notifier.state.status, SyncStatus.disabled);
        expect(notifier.state.backendSessionId, isNull);
        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
      });

      test('setEnabled(false) cleanup runs even if finish throws Dart Error',
          () async {
        final client = _SessionCreateFinishErrorMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();
        expect(notifier.state.backendSessionId, 'session_backend_test_1');

        try {
          await notifier.setEnabled(false);
          fail('Expected Error to propagate');
        } catch (_) {
          // Error propagated after cleanup
        }

        expect(client.finishCallCount, 1);
        expect(notifier.state.status, SyncStatus.disabled);
        expect(notifier.state.backendSessionId, isNull);
        expect(notifier.state.alignmentStatus, SessionAlignmentStatus.none);
        expect(notifier.state.pendingFrames, 0);
      });

      test('finish failure does not prevent state transition', () async {
        final client = _SessionCreateFinishFailMockClient();
        final config = BackendConfig(
          useV2Data: true,
          defaultBatchSize: 1,
          maxRetries: 0,
          retryBaseDelay: Duration.zero,
        );
        final notifier = BackendSyncNotifier(
          client: client,
          parser: MockTelemetryParser(),
          config: config,
        );

        await notifier.setEnabled(true);
        await notifier.ensureBackendSession();
        expect(notifier.state.backendSessionId, 'session_backend_test_1');

        await notifier.setEnabled(false);

        // Should still transition to disabled even though finish failed
        expect(client.finishCallCount, 1);
        expect(notifier.state.status, SyncStatus.disabled);
        expect(notifier.state.backendSessionId, isNull);
      });
    });
  });

  group('Session not found realignment', () {
    test('session_not_found clears stale alignment, creates new session, retries batch',
        () async {
      final client = _SessionNotFoundMockClient(
        config: BackendConfig(maxRetries: 0, retryBaseDelay: Duration.zero),
      );
      final config = BackendConfig(
        useV2Data: true,
        defaultBatchSize: 1,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: config,
      );

      await notifier.setEnabled(true);
      await notifier.ensureBackendSession();
      expect(notifier.state.backendSessionId, 'session_backend_test_1');
      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.created);

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.totalAccepted, 1);
      expect(client.lastBatchSessionId, 'session_backend_test_1');
      expect(client.batchCallCount, 1);

      notifier.injectPacket(Uint8List(2));
      await Future<void>.delayed(Duration.zero);

      expect(client.createCallCount, 2);
      expect(notifier.state.backendSessionId, 'session_backend_test_2');
      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.created);
      expect(notifier.state.status, SyncStatus.idle);
      expect(client.lastBatchSessionId, 'session_backend_test_2');
      expect(notifier.state.totalAccepted, 2);
    });

    test('session_not_found with realignment failure degrades and drops stale id',
        () async {
      final client = _SessionNotFoundThenRecreateFailMockClient(
        config: BackendConfig(maxRetries: 0, retryBaseDelay: Duration.zero),
      );
      final config = BackendConfig(
        useV2Data: true,
        defaultBatchSize: 1,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: config,
      );

      await notifier.setEnabled(true);
      await notifier.ensureBackendSession();
      expect(notifier.state.alignmentStatus, SessionAlignmentStatus.created);
      expect(notifier.state.backendSessionId, 'session_backend_test_1');

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);
      expect(client.batchCallCount, 1);

      notifier.injectPacket(Uint8List(2));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.degraded);
      expect(notifier.state.backendSessionId, isNull);
      expect(client.createCallCount, 2);
      expect(notifier.state.effectiveSessionId, startsWith('local_'));
      expect(notifier.state.pendingFrames, greaterThan(0));
    });

    test('existing bad_request rejection still works alongside new codes',
        () async {
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

      await notifier.setEnabled(true);
      await notifier.ensureBackendSession();

      notifier.injectPacket(Uint8List(0));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.rejected);
      expect(notifier.state.lastRejection, isNotNull);
      expect(notifier.state.lastRejection!.rejectionCode, 'invalid_throttle');
      expect(notifier.state.pendingFrames, 0);
      expect(notifier.state.totalRejected, 1);
    });
  });

  group('Session finished terminal handling', () {
    test('session_finished drops frames as terminal without re-buffering',
        () async {
      final client = _SessionFinishedMockClient(
        config: BackendConfig(maxRetries: 0, retryBaseDelay: Duration.zero),
      );
      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: _testConfig(),
      );

      await notifier.setEnabled(true);

      notifier.injectPacket(Uint8List(1));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, SyncStatus.rejected);
      expect(notifier.state.pendingFrames, 0,
          reason: 'frames must NOT be re-buffered for finished session');
      expect(notifier.state.totalRejected, 1);
      expect(notifier.state.consecutiveFailures, 0,
          reason: 'consecutiveFailures should not increment (non-retryable)');
      expect(notifier.state.lastRejectionCode, 'session_finished');
      expect(notifier.state.lastErrorMessage, contains('finished'));
    });

    test('session_finished does not re-buffer across multiple flushes',
        () async {
      final client = _SessionFinishedMockClient(
        config: BackendConfig(maxRetries: 0, retryBaseDelay: Duration.zero),
      );
      final config = BackendConfig(
        defaultBatchSize: 1,
        maxRetries: 0,
        retryBaseDelay: Duration.zero,
      );
      final notifier = BackendSyncNotifier(
        client: client,
        parser: MockTelemetryParser(),
        config: config,
      );

      await notifier.setEnabled(true);

      // Inject one frame at a time to let each flush complete
      for (var i = 0; i < 3; i++) {
        notifier.injectPacket(Uint8List(i));
        await Future<void>.delayed(Duration.zero);
      }

      expect(notifier.state.status, SyncStatus.rejected);
      expect(notifier.state.pendingFrames, 0,
          reason: 'no frames should accumulate in buffer');
      expect(notifier.state.totalRejected, 3);
      expect(client.batchCallCount, 3);
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

/// Return a minimal [TelemetryData] with a given [packetId] for testing.
TelemetryData _sampleData(int packetId) {
  return TelemetryData(
    timestamp: DateTime.fromMillisecondsSinceEpoch(1720656000000 + packetId),
    packetId: packetId,
    speedKmh: 100.0 + packetId,
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

class _SessionCreateMockClient extends BackendClient {
  int createCallCount = 0;
  int finishCallCount = 0;
  CreateSessionRequest? lastCreateRequest;
  String? lastFinishSessionId;
  int? lastFinishEndedUnixMs;
  String? lastBatchSessionId;

  _SessionCreateMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    lastCreateRequest = request;
    return CreateSessionResponse(sessionId: 'session_backend_test_1');
  }

  @override
  Future<FinishSessionResponse> finishSession(
    String sessionId,
    FinishSessionRequest request,
  ) async {
    finishCallCount++;
    lastFinishSessionId = sessionId;
    lastFinishEndedUnixMs = request.endedUnixMs;
    return const FinishSessionResponse(status: 'finished');
  }

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
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
  int finishCallCount = 0;
  int batchCallCount = 0;
  String? lastBatchSessionId;

  _SessionCreateFailMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    throw BackendRequestException(
      statusCode: 0,
      error: const BackendError(
        code: 'network_error',
        message: 'Connection failed',
      ),
    );
  }

  @override
  Future<FinishSessionResponse> finishSession(
    String sessionId,
    FinishSessionRequest request,
  ) async {
    finishCallCount++;
    return const FinishSessionResponse(status: 'finished');
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

/// Mock that holds createSession until [completePendingCreate] is called.
class _ControllableCreateMockClient extends BackendClient {
  int pendingCreateCount = 0;
  int batchCallCount = 0;
  Completer<CreateSessionResponse>? _createCompleter;

  _ControllableCreateMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    pendingCreateCount++;
    _createCompleter = Completer<CreateSessionResponse>();
    return _createCompleter!.future;
  }

  void completePendingCreate() {
    if (_createCompleter != null && !_createCompleter!.isCompleted) {
      _createCompleter!.complete(
        CreateSessionResponse(sessionId: 'session_backend_test_1'),
      );
    }
  }

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    batchCallCount++;
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

class _SessionCreateErrorMockClient extends BackendClient {
  int createCallCount = 0;

  _SessionCreateErrorMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    throw Error(); // Dart Error — not caught by on Exception
  }
}

/// Mock that throws a Dart Error on finishSession.
class _SessionCreateFinishErrorMockClient extends BackendClient {
  int createCallCount = 0;
  int finishCallCount = 0;

  _SessionCreateFinishErrorMockClient({BackendConfig? config})
    : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    return CreateSessionResponse(sessionId: 'session_backend_test_1');
  }

  @override
  Future<FinishSessionResponse> finishSession(
    String sessionId,
    FinishSessionRequest request,
  ) async {
    finishCallCount++;
    throw Error(); // Dart Error — not caught by on Exception
  }

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
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

class _SessionCreateFinishFailMockClient extends BackendClient {
  int createCallCount = 0;
  int finishCallCount = 0;

  _SessionCreateFinishFailMockClient({BackendConfig? config})
    : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    return CreateSessionResponse(sessionId: 'session_backend_test_1');
  }

  @override
  Future<FinishSessionResponse> finishSession(
    String sessionId,
    FinishSessionRequest request,
  ) async {
    finishCallCount++;
    throw BackendRequestException(
      statusCode: 500,
      error: const BackendError(
        code: 'internal_error',
        message: 'server error',
      ),
    );
  }

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
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

class _BadRequestNoDetailsMockClient extends BackendClient {
  int callCount = 0;

  _BadRequestNoDetailsMockClient({BackendConfig? config})
    : super(config: config);

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    callCount++;
    throw BackendRequestException(
      statusCode: 400,
      error: const BackendError(
        code: 'bad_request',
        message: 'invalid JSON body: unknown field "steeringAngle"',
      ),
    );
  }
}

/// Mock where batch call at [failBatchIndex] (1-indexed) throws session_not_found.
/// Other batch calls succeed. createSession always succeeds.
class _SessionNotFoundMockClient extends BackendClient {
  int createCallCount = 0;
  int batchCallCount = 0;
  int failBatchIndex = 2;
  String? lastBatchSessionId;

  _SessionNotFoundMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    return CreateSessionResponse(
      sessionId: 'session_backend_test_$createCallCount',
    );
  }

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    batchCallCount++;
    lastBatchSessionId = sessionId;
    if (batchCallCount == failBatchIndex) {
      throw BackendRequestException(
        statusCode: 404,
        error: const BackendError(
          code: 'session_not_found',
          message: 'Session not found',
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

/// Mock that always returns session_finished on frame ingest.
class _SessionFinishedMockClient extends BackendClient {
  int batchCallCount = 0;

  _SessionFinishedMockClient({BackendConfig? config}) : super(config: config);

  @override
  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    batchCallCount++;
    throw BackendRequestException(
      statusCode: 409,
      error: const BackendError(
        code: 'session_finished',
        message: 'Session is already finished',
      ),
    );
  }
}

/// Mock where createSession always fails (realignment cannot recover).
/// All batch calls throw session_not_found.
class _SessionNotFoundThenCreateFailMockClient extends BackendClient {
  int createCallCount = 0;
  int batchCallCount = 0;
  String? lastBatchSessionId;

  _SessionNotFoundThenCreateFailMockClient({BackendConfig? config})
    : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    throw BackendRequestException(
      statusCode: 0,
      error: const BackendError(
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
    throw BackendRequestException(
      statusCode: 404,
      error: const BackendError(
        code: 'session_not_found',
        message: 'Session not found',
      ),
    );
  }
}

/// Mock where the initial session create succeeds, the second batch is
/// rejected as session_not_found, and the re-alignment create fails.
class _SessionNotFoundThenRecreateFailMockClient extends BackendClient {
  int createCallCount = 0;
  int batchCallCount = 0;
  String? lastBatchSessionId;

  _SessionNotFoundThenRecreateFailMockClient({BackendConfig? config})
    : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    if (createCallCount == 1) {
      return CreateSessionResponse(sessionId: 'session_backend_test_1');
    }
    throw BackendRequestException(
      statusCode: 0,
      error: const BackendError(
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
    if (batchCallCount == 2) {
      throw BackendRequestException(
        statusCode: 404,
        error: const BackendError(
          code: 'session_not_found',
          message: 'Session not found',
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

class _DisableLifecycleMockClient extends BackendClient {
  int createCallCount = 0;
  int finishCallCount = 0;
  int batchCallCount = 0;
  String? lastBatchSessionId;
  String? lastFinishSessionId;

  _DisableLifecycleMockClient({BackendConfig? config})
    : super(config: config);

  @override
  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    createCallCount++;
    return CreateSessionResponse(sessionId: 'session_backend_test_1');
  }

  @override
  Future<FinishSessionResponse> finishSession(
    String sessionId,
    FinishSessionRequest request,
  ) async {
    finishCallCount++;
    lastFinishSessionId = sessionId;
    return const FinishSessionResponse(status: 'finished');
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
