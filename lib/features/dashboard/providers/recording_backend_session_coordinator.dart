import 'dart:async';

import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/models/telemetry_data.dart';

import 'session_provider.dart';

/// Coordinates local recording auto-start with backend session creation.
class RecordingBackendSessionCoordinator {
  final SessionRecorder _sessionRecorder;
  final BackendSyncNotifier _backendSync;

  RecordingBackendSessionCoordinator({
    required SessionRecorder sessionRecorder,
    required BackendSyncNotifier backendSync,
  }) : _sessionRecorder = sessionRecorder,
       _backendSync = backendSync;

  void handleTelemetry(TelemetryData data) {
    _sessionRecorder.recordPoint(data);
    final isRecording = _sessionRecorder.state.isRecording;

    if (isRecording) {
      _backendSync.recordData(data);
    }

    if (!isRecording) return;
    if (!_backendSync.state.enabled) return;
    if (_backendSync.state.backendSessionId != null) return;
    if (_backendSync.state.alignmentStatus != SessionAlignmentStatus.none) return;

    unawaited(_backendSync.ensureBackendSession());
  }
}
