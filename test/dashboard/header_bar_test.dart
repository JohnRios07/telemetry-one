import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/core/backend/track_layout_dto.dart';
import 'package:telemetry_one/core/backend/settings_bootstrap_dto.dart';
import 'package:telemetry_one/core/backend/v2_bridge_providers.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/features/dashboard/providers/session_provider.dart';
import 'package:telemetry_one/features/dashboard/widgets/header_bar.dart';

/// Wide viewport (logical 1920×1080 @ 1x) so HeaderBar's dense Row fits.
void useWideScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
}

Widget buildHeaderApp({
  Object? trackDetectionOverride,
  Object? sessionOverride,
  BackendSyncNotifier? syncOverride,
  BackendClient? backendClientOverride,
  BackendConfig? backendConfigOverride,
}) {
  final overrides = <Override>[];
  overrides.add(
    backendConfigProvider.overrideWithValue(
      backendConfigOverride ?? const BackendConfig(),
    ),
  );
  if (trackDetectionOverride != null) {
    overrides.add(
      backendTrackDetectionProvider.overrideWith(
        (_) => Future<TrackDetectionResponse?>.value(
          trackDetectionOverride as TrackDetectionResponse?,
        ),
      ),
    );
  }
  if (sessionOverride != null) {
    overrides.add(
      sessionRecorderProvider.overrideWith(
        (_) => sessionOverride as SessionRecorder,
      ),
    );
  }
  if (backendClientOverride != null) {
    overrides.add(backendClientProvider.overrideWithValue(backendClientOverride));
  }
  overrides.add(
    backendSyncProvider.overrideWith(
      (_) =>
          syncOverride ??
          _MockSyncNotifier(const BackendSyncState(sessionId: 'local_test')),
    ),
  );
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: Scaffold(body: HeaderBar()),
    ),
  );
}

void main() {
  group('circuitDisplayText', () {
    test('returns CIRCUIT UNKNOWN for null response', () {
      expect(circuitDisplayText(null, true), 'CIRCUIT UNKNOWN');
      expect(circuitDisplayText(null, false), 'CIRCUIT UNKNOWN');
    });

    test('returns track · layout when both available', () {
      final response = TrackDetectionResponse(
        status: 'detected',
        trackName: 'Watkins Glen International',
        layoutName: 'Watkins Glen Long Course',
      );
      expect(
        circuitDisplayText(response, true),
        'Watkins Glen International · Watkins Glen Long Course',
      );
    });

    test('returns track name when only track available', () {
      final response = TrackDetectionResponse(
        status: 'detected',
        trackName: 'Suzuka Circuit',
      );
      expect(circuitDisplayText(response, true), 'Suzuka Circuit');
    });

    test('returns layout name when only layout available', () {
      final response = TrackDetectionResponse(
        status: 'detected',
        layoutName: 'Nordschleife',
      );
      expect(circuitDisplayText(response, true), 'Nordschleife');
      expect(circuitDisplayText(response, false), 'Nordschleife');
    });

    test('returns CIRCUIT UNKNOWN for detected with empty track name', () {
      final response = TrackDetectionResponse(
        status: 'detected',
        trackName: '',
        layoutName: '',
      );
      expect(circuitDisplayText(response, true), 'CIRCUIT UNKNOWN');
    });

    test('returns CIRCUIT UNKNOWN for detected with null names', () {
      final response = TrackDetectionResponse(status: 'detected');
      expect(circuitDisplayText(response, true), 'CIRCUIT UNKNOWN');
    });

    test('returns Detecting... when pending and active session', () {
      final response = TrackDetectionResponse(status: 'pending');
      expect(circuitDisplayText(response, true), 'Detecting...');
    });

    test('returns CIRCUIT UNKNOWN when pending but no active session', () {
      final response = TrackDetectionResponse(status: 'pending');
      expect(circuitDisplayText(response, false), 'CIRCUIT UNKNOWN');
    });

    test('returns CIRCUIT UNKNOWN for unknown status', () {
      final response = TrackDetectionResponse(status: 'unknown');
      expect(circuitDisplayText(response, true), 'CIRCUIT UNKNOWN');
      expect(circuitDisplayText(response, false), 'CIRCUIT UNKNOWN');
    });
  });

  group('HeaderBar circuit text widget', () {
    testWidgets('shows CIRCUIT UNKNOWN by default when no detection',
        (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(buildHeaderApp(trackDetectionOverride: null));
      await tester.pump();
      await tester.pump();

      expect(find.text('CIRCUIT UNKNOWN'), findsOneWidget);
    });

    testWidgets('shows track · layout when detected', (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(
        buildHeaderApp(
          trackDetectionOverride: TrackDetectionResponse(
            status: 'detected',
            trackName: 'Watkins Glen International',
            layoutName: 'Watkins Glen Long Course',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Watkins Glen International · Watkins Glen Long Course'),
        findsOneWidget,
      );
    });

    testWidgets('shows track name when only track detected',
        (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(
        buildHeaderApp(
          trackDetectionOverride: TrackDetectionResponse(
            status: 'detected',
            trackName: 'Suzuka Circuit',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Suzuka Circuit'), findsOneWidget);
    });

    testWidgets('shows Detecting... when pending and recording',
        (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(
        buildHeaderApp(
          trackDetectionOverride: TrackDetectionResponse(status: 'pending'),
          sessionOverride: _MockSessionRecorder(
            const SessionState(status: RecordingStatus.recording),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Detecting...'), findsOneWidget);
    });

    testWidgets('shows CIRCUIT UNKNOWN when pending but not recording',
        (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(
        buildHeaderApp(
          trackDetectionOverride: TrackDetectionResponse(status: 'pending'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('CIRCUIT UNKNOWN'), findsOneWidget);
      expect(find.text('Detecting...'), findsNothing);
    });

    testWidgets('shows CIRCUIT UNKNOWN when backend returns unknown',
        (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(
        buildHeaderApp(
          trackDetectionOverride: TrackDetectionResponse(status: 'unknown'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('CIRCUIT UNKNOWN'), findsOneWidget);
    });

    testWidgets('stale track detection is invalidated when recording starts',
        (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildHeaderApp(
          trackDetectionOverride: TrackDetectionResponse(
            status: 'detected',
            trackName: 'Suzuka Circuit',
          ),
          sessionOverride: _MockSessionRecorder(const SessionState()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Suzuka Circuit'), findsOneWidget);

      await tester.tap(find.text('RECORD'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Suzuka Circuit'), findsOneWidget);
    });

    testWidgets('settings icon opens the settings screen', (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildHeaderApp(backendClientOverride: _FakeSettingsClient()),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('CLIENT HINTS'), findsOneWidget);
    });

    testWidgets('does not show the obsolete ENGINEER header entry', (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildHeaderApp());
      await tester.pump();
      await tester.pump();

      expect(find.text('ENGINEER'), findsNothing);
      expect(find.byIcon(Icons.insights_rounded), findsNothing);
    });

    testWidgets('manual track selection opens, submits, and reflects badge',
        (tester) async {
      useWideScreen(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      final syncNotifier = _MockSyncNotifier(
        const BackendSyncState(
          sessionId: 'local_test',
          backendSessionId: 'session_abc123',
          alignmentStatus: SessionAlignmentStatus.created,
        ),
      );
      final client = _FakeManualTrackClient();

      await tester.pumpWidget(
        buildHeaderApp(
          trackDetectionOverride: TrackDetectionResponse(status: 'unknown'),
          backendClientOverride: client,
          syncOverride: syncNotifier,
          backendConfigOverride: const BackendConfig(useV2Data: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.widgetWithText(TextButton, 'MANUAL'), findsOneWidget);
      expect(find.text('MANUAL'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'MANUAL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Manual Track Selection'), findsOneWidget);
      expect(find.text('Watkins Glen International'), findsOneWidget);

      await tester.tap(find.text('Watkins Glen International'));
      await tester.pump();
      await tester.ensureVisible(find.text('Full Course'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Full Course'));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Apply'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(client.updateCalls, 1);
      expect(find.textContaining('Watkins Glen International · Full Course'),
          findsOneWidget);
      expect(find.text('CIRCUIT UNKNOWN'), findsOneWidget);
    });
  });
}

class _MockSessionRecorder extends SessionRecorder {
  _MockSessionRecorder(SessionState state) : super() {
    this.state = state;
  }

  @override
  void dispose() {
    // No-op to avoid referencing uninitialized test fields.
  }
}

class _FakeSettingsClient extends BackendClient {
  _FakeSettingsClient()
    : super(config: const BackendConfig(baseUrl: 'http://example.test'));

  @override
  Future<SettingsBootstrapResponse> getSettingsBootstrap() async {
    return const SettingsBootstrapResponse(
      apiVersion: settingsBootstrapApiVersion,
      bootstrap: SettingsBootstrap(
        clientHints: SettingsBootstrapSection(values: {'alias': 'alex'}),
        limits: SettingsBootstrapSection(values: {'maxBatchFrames': 600}),
        capabilities: SettingsBootstrapSection(values: {'readOnly': true}),
      ),
    );
  }
}

class _FakeManualTrackClient extends BackendClient {
  int updateCalls = 0;

  _FakeManualTrackClient()
    : super(config: const BackendConfig(baseUrl: 'http://example.test'));

  @override
  Future<TrackLayoutsCatalogResponse> getTrackLayouts() async {
    return const TrackLayoutsCatalogResponse(
      tracks: [
        TrackCatalogTrack(
          trackId: 'gt7_watkins_glen_international',
          trackName: 'Watkins Glen International',
          layouts: [
            TrackCatalogLayout(layoutId: 'full_course', layoutName: 'Full Course'),
          ],
        ),
      ],
    );
  }

  @override
  Future<UpdateSessionTrackLayoutResponse> updateSessionTrackLayout(
    String sessionId,
    String trackId,
    String layoutId,
  ) async {
    updateCalls++;
    return UpdateSessionTrackLayoutResponse(
      sessionId: sessionId,
      trackId: trackId,
      layoutId: layoutId,
      detectedTrackId: 'detected_track_id',
      detectedLayoutId: 'detected_layout_id',
    );
  }
}

class _MockSyncNotifier extends BackendSyncNotifier {
  _MockSyncNotifier(BackendSyncState state)
    : super(config: const BackendConfig()) {
    this.state = state;
  }

  @override
  void dispose() {}
}
