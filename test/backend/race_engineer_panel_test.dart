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
  RaceEngineerAdviceState state,
) async {
  late _FakeRaceEngineerAdviceNotifier notifier;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        raceEngineerAdviceProvider.overrideWith((ref) {
          notifier = _FakeRaceEngineerAdviceNotifier(ref, state);
          return notifier;
        }),
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

    testWidgets('renders success advice and refresh label', (tester) async {
      await _pumpPanel(
        tester,
        const RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.success,
          response: RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'success',
            advice: 'Brake earlier into turn 1.',
            referencedEventIds: ['event_1'],
          ),
          message: 'Brake earlier into turn 1.',
        ),
      );

      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Brake earlier into turn 1.'), findsOneWidget);
      expect(find.text('1 events referenced'), findsOneWidget);
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
