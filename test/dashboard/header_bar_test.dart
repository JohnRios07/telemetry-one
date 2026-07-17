import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
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
  BackendClient? backendClientOverride,
}) {
  final overrides = <Override>[];
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
