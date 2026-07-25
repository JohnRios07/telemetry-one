import 'dart:async';

import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/models/telemetry_data.dart';

import 'session_provider.dart';

/// Coordinates local recording auto-start with backend session creation.
class RecordingBackendSessionCoordinator {
  final SessionRecorder _sessionRecorder;
  final BackendSyncNotifier _backendSync;
  final bool _useV2Data;

  RecordingBackendSessionCoordinator({
    required SessionRecorder sessionRecorder,
    required BackendSyncNotifier backendSync,
    required bool useV2Data,
  }) : _sessionRecorder = sessionRecorder,
       _backendSync = backendSync,
       _useV2Data = useV2Data;

  void handleTelemetry(TelemetryData data) {
    final wasRecording = _sessionRecorder.state.isRecording;
    _sessionRecorder.recordPoint(data);
    final isRecording = _sessionRecorder.state.isRecording;

    if (isRecording && !wasRecording) {
      _autoEnableBackendSync();
    }

    if (isRecording) {
      _backendSync.recordData(data);
    }

    if (isRecording) {
      _ensureBackendSessionIfNeeded();
      return;
    }

    if (wasRecording && _backendSync.state.enabled) {
      unawaited(_backendSync.setEnabled(false));
    }
  }

  void _autoEnableBackendSync() {
    if (!_useV2Data) return;
    if (_backendSync.state.enabled) return;

    unawaited(_backendSync.setEnabled(true));
  }

  void _ensureBackendSessionIfNeeded() {
    if (!_useV2Data) return;
    if (!_backendSync.state.enabled) return;
    if (_backendSync.state.backendSessionId != null) return;
    if (_backendSync.state.alignmentStatus != SessionAlignmentStatus.none) return;

    unawaited(_backendSync.ensureBackendSession());
  }
}
