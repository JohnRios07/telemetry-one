import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/core/backend/track_capabilities_dto.dart';
import 'package:telemetry_one/core/backend/v2_bridge_providers.dart';
import 'package:telemetry_one/features/dashboard/providers/session_provider.dart';
import 'package:telemetry_one/features/dashboard/providers/telemetry_provider.dart';
import 'package:telemetry_one/features/dashboard/widgets/header_bar.dart';
import 'package:telemetry_one/features/dashboard/screens/dashboard_screen.dart';
import 'package:telemetry_one/features/dashboard/widgets/track_capabilities_panel.dart';

class _MockSyncNotifier extends BackendSyncNotifier {
  _MockSyncNotifier(BackendSyncState state)
      : super(config: const BackendConfig()) {
    this.state = state;
  }

  @override
  void dispose() {}
}

class _NoopTelemetryBufferNotifier extends TelemetryBufferNotifier {
  @override
  void dispose() {}
}

class _NoopTrackHistoryNotifier extends TrackHistoryNotifier {
  @override
  void dispose() {}
}

class _NoopSessionRecorder extends SessionRecorder {
  @override
  void dispose() {}
}

Widget _panelApp(TrackCapabilitiesDto capabilities) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 170,
        child: TrackCapabilitiesPanel(capabilities: capabilities),
      ),
    ),
  );
}

Widget _dashboardApp(TrackCapabilitiesDto capabilities) {
  return ProviderScope(
    overrides: [
      backendConfigProvider.overrideWithValue(
        const BackendConfig(useV2Data: true),
      ),
      telemetryDataProvider.overrideWith((ref) => null),
      telemetryBufferProvider.overrideWith((ref) => _NoopTelemetryBufferNotifier()),
      trackHistoryProvider.overrideWith((ref) => _NoopTrackHistoryNotifier()),
      sessionRecorderProvider.overrideWith((ref) => _NoopSessionRecorder()),
      backendSyncProvider.overrideWith(
        (ref) => _MockSyncNotifier(
          const BackendSyncState(
            sessionId: 'local_123',
            backendSessionId: 'session_abc123',
            alignmentStatus: SessionAlignmentStatus.created,
          ),
        ),
      ),
      backendTrackDetectionProvider.overrideWith(
        (ref) async => TrackDetectionResponse(
          status: 'detected',
          capabilities: capabilities,
        ),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
  );
}

void _useWideScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
}

void main() {
  group('TrackCapabilitiesPanel', () {
    testWidgets('renders partial state and reason', (tester) async {
      await tester.pumpWidget(
        _panelApp(
          const TrackCapabilitiesDto(
            state: TrackCapabilityState.partial,
            reason: 'Only track-level capabilities are known.',
          ),
        ),
      );

      expect(find.text('TRACK CAPABILITIES'), findsOneWidget);
      expect(find.text('PARTIAL'), findsOneWidget);
      expect(find.text('Only track-level capabilities are known.'), findsOneWidget);
    });

    testWidgets('renders unavailable state and reason', (tester) async {
      await tester.pumpWidget(
        _panelApp(
          const TrackCapabilitiesDto(
            state: TrackCapabilityState.unavailable,
            reason: 'Manual layout data not yet resolved.',
          ),
        ),
      );

      expect(find.text('UNAVAILABLE'), findsOneWidget);
      expect(find.text('Manual layout data not yet resolved.'), findsOneWidget);
    });
  });

  group('Dashboard placement', () {
    testWidgets('shows capabilities panel in the bottom row, not the header', (
      tester,
    ) async {
      _useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _dashboardApp(
          const TrackCapabilitiesDto(
            state: TrackCapabilityState.available,
            reason: 'Layout capabilities are fully available.',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('TRACK CAPABILITIES'), findsOneWidget);
      expect(find.text('RACE ENGINEER'), findsOneWidget);
      expect(find.text('Layout capabilities are fully available.'), findsOneWidget);
      expect(find.descendant(
        of: find.byType(HeaderBar),
        matching: find.text('TRACK CAPABILITIES'),
      ), findsNothing);
    });
  });
}
