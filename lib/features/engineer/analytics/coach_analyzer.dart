import '../../../core/storage/session_model.dart';
import '../domain/coach_report.dart';
import 'driver_score_engine.dart';
import 'weak_segment_detector.dart';

class CoachAnalyzer {
  const CoachAnalyzer._();

  static CoachReport build(Session session) {
    return CoachReport(
      sessionId: session.id,
      weakSegments: WeakSegmentDetector.analyze(session),
      driverScore: DriverScoreEngine.build(session),
      disclaimer:
          'Session-local heuristic score. No es comparable entre autos o pistas.',
    );
  }
}
