import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/features/dashboard/providers/race_engineer_advice_provider.dart';
import 'package:telemetry_one/features/dashboard/widgets/race_engineer_panel.dart';

class _FakeRaceEngineerAdviceNotifier extends RaceEngineerAdviceNotifier {
  int requestCount = 0;

  _FakeRaceEngineerAdviceNotifier(Ref ref, RaceEngineerAdviceState initial)
    : super(ref) {
    state = initial;
  }

  @override
  Future<void> requestAdvice({
    RaceEngineerAdviceRequest request = const RaceEngineerAdviceRequest(),
  }) async {
    requestCount++;
  }
}

Future<_FakeRaceEngineerAdviceNotifier> _pumpPanel(
  WidgetTester tester,
  RaceEngineerAdviceState state, {
  RaceEngineerAdviceAvailability availability =
      const RaceEngineerAdviceAvailability.available(),
}) async {
  late _FakeRaceEngineerAdviceNotifier notifier;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        raceEngineerAdviceProvider.overrideWith((ref) {
          notifier = _FakeRaceEngineerAdviceNotifier(ref, state);
          return notifier;
        }),
        raceEngineerAdviceAvailabilityProvider.overrideWithValue(availability),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(height: 180, child: RaceEngineerPanel())),
      ),
    ),
  );
  return notifier;
}

void main() {
  group('RaceEngineerPanel', () {
    testWidgets('renders idle and triggers one manual ask', (tester) async {
      final notifier = await _pumpPanel(
        tester,
        const RaceEngineerAdviceState.idle(),
      );

      expect(find.text('RACE ENGINEER'), findsOneWidget);
      expect(find.text('Ask Engineer'), findsOneWidget);
      expect(find.text('IDLE'), findsOneWidget);

      await tester.tap(find.text('Ask Engineer'));
      await tester.pump();

      expect(notifier.requestCount, 1);
    });

    testWidgets('renders loading with disabled button', (tester) async {
      final notifier = await _pumpPanel(
        tester,
        const RaceEngineerAdviceState(status: RaceEngineerAdviceStatus.loading),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Ask Engineer'));
      await tester.pump();
      expect(notifier.requestCount, 0);
    });

    testWidgets('disables ask with friendly copy when no session exists', (
      tester,
    ) async {
      final notifier = await _pumpPanel(
        tester,
        const RaceEngineerAdviceState.idle(),
        availability: const RaceEngineerAdviceAvailability.unavailable(
          'Start a race to ask the engineer.',
        ),
      );

      expect(find.text('Start a race to ask the engineer.'), findsOneWidget);

      await tester.tap(find.text('Ask Engineer'));
      await tester.pump();

      expect(notifier.requestCount, 0);
    });

    testWidgets('renders success advice and refresh label', (tester) async {
      await _pumpPanel(
        tester,
        const RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.success,
          response: RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'success',
            message: 'Brake earlier into turn 1.',
            referencedEvents: ['event_1'],
          ),
          message: 'Brake earlier into turn 1.',
        ),
      );

      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Brake earlier into turn 1.'), findsOneWidget);
      expect(find.text('1 events referenced'), findsOneWidget);
    });

    testWidgets('renders success advice with derived signals summary', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        const RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.success,
          response: RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'success',
            message: 'Brake earlier into turn 1.',
            signals: [
              RaceEngineerSignal(
                type: 'lap_pace_regression',
                severity: 'warning',
                message: 'Lap 4 is 1.2s slower than the best lap.',
              ),
              RaceEngineerSignal(
                type: 'telemetry_gap_warning',
                severity: 'info',
                title: 'Telemetry gap warning',
                summary: 'Missing telemetry in sector 2.',
              ),
            ],
            window: RaceEngineerAdviceWindow(derivedSignalCount: 2),
          ),
          message: 'Brake earlier into turn 1.',
        ),
      );

      expect(find.text('Success'), findsOneWidget);
      expect(find.text('2 derived signals'), findsOneWidget);
      expect(find.text('Lap Pace Regression'), findsOneWidget);
      expect(find.text('Telemetry gap warning'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('Missing telemetry in sector 2.'), findsOneWidget);
    });

    testWidgets('renders kind-only user-facing signals', (tester) async {
      await _pumpPanel(
        tester,
        RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.success,
          response: RaceEngineerAdviceResponse.fromJson({
            'sessionId': 'session_test_1',
            'status': 'success',
            'message': 'Brake earlier into turn 1.',
            'signals': [
              {
                'kind': 'off_track_stint_warning',
                'severity': 'warning',
                'summary': 'You spent 2 laps off track.',
              },
            ],
            'window': {'derivedSignalCount': 1},
          }),
          message: 'Brake earlier into turn 1.',
        ),
      );

      expect(find.text('Success'), findsOneWidget);
      expect(find.text('1 derived signals'), findsOneWidget);
      expect(find.text('Off Track Stint Warning'), findsOneWidget);
      expect(find.text('You spent 2 laps off track.'), findsOneWidget);
    });

    testWidgets('keeps internal kind-only signals hidden', (tester) async {
      await _pumpPanel(
        tester,
        RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.success,
          response: RaceEngineerAdviceResponse.fromJson({
            'sessionId': 'session_test_1',
            'status': 'success',
            'message': 'Brake earlier into turn 1.',
            'signals': [
              {
                'kind': 'trackbuilder_chord_excess',
                'summary': 'Internal diagnostic payload.',
              },
            ],
          }),
          message: 'Brake earlier into turn 1.',
        ),
      );

      expect(find.text('Internal signal'), findsNothing);
      expect(find.text('Internal diagnostic payload.'), findsNothing);
      expect(find.textContaining('derived signals'), findsNothing);
    });

    testWidgets('filters internal diagnostic signals from normal UI', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        const RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.success,
          response: RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'success',
            message: 'Brake earlier into turn 1.',
            signals: [
              RaceEngineerSignal(
                type: 'trackbuilder_chord_excess',
                label: 'Trackbuilder chord excess',
                message: 'Internal diagnostic payload.',
              ),
              RaceEngineerSignal(
                type: 'telemetry_baseline_only',
                title: 'Telemetry baseline only',
                summary: 'Internal baseline diagnostic.',
              ),
              RaceEngineerSignal(
                type: 'geometry_status',
                title: 'Geometry status',
                summary: 'Internal geometry diagnostic.',
              ),
              RaceEngineerSignal(
                type: 'baseline_delta',
                message: 'Internal baseline delta diagnostic.',
              ),
              RaceEngineerSignal(
                type: 'lap_pace_regression',
                severity: 'warning',
                message: 'Lap pace is regressing.',
              ),
            ],
          ),
          message: 'Brake earlier into turn 1.',
        ),
      );

      expect(find.text('Lap Pace Regression'), findsOneWidget);
      expect(find.text('Lap pace is regressing.'), findsOneWidget);
      expect(find.text('Trackbuilder chord excess'), findsNothing);
      expect(find.text('Internal diagnostic payload.'), findsNothing);
      expect(find.text('Telemetry baseline only'), findsNothing);
      expect(find.text('Internal baseline diagnostic.'), findsNothing);
      expect(find.text('Geometry status'), findsNothing);
      expect(find.text('Internal geometry diagnostic.'), findsNothing);
      expect(find.text('Baseline delta diagnostic.'), findsNothing);
    });

    testWidgets('renders no_events state', (tester) async {
      await _pumpPanel(
        tester,
        const RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.noEvents,
        ),
      );

      expect(find.text('NO EVENTS'), findsOneWidget);
      expect(find.text('Ask Engineer'), findsOneWidget);
    });

    testWidgets('renders rate_limited with provider info', (tester) async {
      await _pumpPanel(
        tester,
        const RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.rateLimited,
          response: RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'rate_limited',
            message: 'Fallback: Lift and coast.',
            referencedEvents: ['event_1'],
            providerInfo: RaceEngineerProviderInfo(
              providerName: 'google-vertex-ai',
              model: 'gemini-2.0-pro',
              retryAfterSeconds: 17,
            ),
          ),
          message: 'Fallback: Lift and coast.',
        ),
      );

      expect(find.textContaining('rate-limited'), findsOneWidget);
      expect(find.textContaining('17'), findsOneWidget);
      expect(find.textContaining('google-vertex-ai'), findsOneWidget);
      expect(find.textContaining('gemini-2.0-pro'), findsOneWidget);
      expect(find.text('Fallback: Lift and coast.'), findsOneWidget);
      expect(find.text('1 events referenced'), findsOneWidget);
      expect(find.text('Ask Engineer'), findsOneWidget);
    });

    testWidgets('renders rate_limited without fallback message', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        const RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.rateLimited,
          response: RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'rate_limited',
            referencedEvents: ['event_1', 'event_2'],
            providerInfo: RaceEngineerProviderInfo(retryAfterSeconds: 60),
          ),
        ),
      );

      expect(find.textContaining('60'), findsOneWidget);
      expect(find.textContaining('rate-limited'), findsOneWidget);
      expect(find.text('2 events referenced'), findsOneWidget);
    });

    testWidgets('disables ask while rate-limit cooldown is active', (
      tester,
    ) async {
      final notifier = await _pumpPanel(
        tester,
        RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.rateLimited,
          response: const RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'rate_limited',
            providerInfo: RaceEngineerProviderInfo(retryAfterSeconds: 60),
          ),
          cooldownExpiresAt: DateTime.now().add(const Duration(seconds: 60)),
        ),
      );

      expect(find.text('Retry in 60s'), findsOneWidget);
      expect(find.textContaining('cooling down'), findsOneWidget);

      await tester.tap(find.text('Retry in 60s'));
      await tester.pump();

      expect(notifier.requestCount, 0);
    });

    testWidgets('renders error retry state', (tester) async {
      await _pumpPanel(
        tester,
        const RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.error,
          message: 'backend unavailable',
        ),
      );

      expect(find.text('UNAVAILABLE'), findsOneWidget);
      expect(find.text('backend unavailable'), findsOneWidget);
      expect(find.text('Ask Engineer'), findsOneWidget);
    });
  });
}
