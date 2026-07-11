import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/session_model.dart';
import '../../../core/storage/session_repository.dart';
import '../analytics/coach_analyzer.dart';
import '../analytics/lap_alignment.dart';
import '../analytics/recommendation_engine.dart';
import '../analytics/session_analyzer.dart';
import '../domain/coach_report.dart';
import '../domain/lap_comparison.dart';
import '../domain/session_summary.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository();
});

final engineerSessionsProvider = FutureProvider<List<EngineerSessionListItem>>((
  ref,
) async {
  final SessionRepository repository = ref.watch(sessionRepositoryProvider);
  final List<Session> sessions = await repository.getEngineerSessions();
  return sessions.map(SessionAnalyzer.buildListItem).toList(growable: false);
});

final engineerSessionProvider = FutureProvider.family<Session?, String>((
  ref,
  String sessionId,
) async {
  final SessionRepository repository = ref.watch(sessionRepositoryProvider);
  return repository.getSessionById(sessionId);
});

final engineerSessionSummaryProvider =
    FutureProvider.family<SessionSummary?, String>((
      ref,
      String sessionId,
    ) async {
      final Session? session = await ref.watch(
        engineerSessionProvider(sessionId).future,
      );
      if (session == null) {
        return null;
      }

      return SessionAnalyzer.buildSummary(session);
    });

final engineerLapComparisonProvider =
    FutureProvider.family<LapComparisonResult, String>((
      ref,
      String sessionId,
    ) async {
      final Session? session = await ref.watch(
        engineerSessionProvider(sessionId).future,
      );
      if (session == null) {
        return LapComparisonResult.unavailable(
          sessionId: sessionId,
          reason: 'No se encontró la sesión guardada.',
        );
      }

      return LapAlignment.compareSessionLaps(session);
    });

final engineerRecommendationsProvider =
    FutureProvider.family<List<EngineerRecommendation>, String>((
      ref,
      String sessionId,
    ) async {
      final Session? session = await ref.watch(
        engineerSessionProvider(sessionId).future,
      );
      if (session == null) {
        return const <EngineerRecommendation>[];
      }

      return RecommendationEngine.build(session);
    });

final engineerCoachReportProvider =
    FutureProvider.family<CoachReport?, String>((ref, String sessionId) async {
      final Session? session = await ref.watch(
        engineerSessionProvider(sessionId).future,
      );
      if (session == null) {
        return null;
      }

      return CoachAnalyzer.build(session);
    });
