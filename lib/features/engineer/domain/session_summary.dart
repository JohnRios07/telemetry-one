import '../../../core/storage/session_model.dart';

enum EngineerConfidence { unavailable, basic, supported }

class SummaryMetric<T> {
  final String label;
  final T? value;
  final EngineerConfidence confidence;
  final String? unavailableReason;
  final String? note;

  const SummaryMetric._({
    required this.label,
    required this.value,
    required this.confidence,
    this.unavailableReason,
    this.note,
  });

  const SummaryMetric.available({
    required String label,
    required T value,
    EngineerConfidence confidence = EngineerConfidence.supported,
    String? note,
  }) : this._(label: label, value: value, confidence: confidence, note: note);

  const SummaryMetric.unavailable({
    required String label,
    String? reason,
    String? note,
  }) : this._(
         label: label,
         value: null,
         confidence: EngineerConfidence.unavailable,
         unavailableReason: reason,
         note: note,
       );

  bool get isAvailable => value != null;
  bool get isBasic => confidence == EngineerConfidence.basic;
}

class EngineerSessionListItem {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final String game;
  final int validLapCount;
  final Duration? bestLap;
  final Duration? sessionDuration;

  const EngineerSessionListItem({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.game,
    required this.validLapCount,
    required this.bestLap,
    required this.sessionDuration,
  });
}

class LapSummaryRow {
  final String lapId;
  final int lapNumber;
  final Duration lapTime;
  final double? fuelUsedLiters;
  final bool isBestLap;
  final bool isLastLap;

  const LapSummaryRow({
    required this.lapId,
    required this.lapNumber,
    required this.lapTime,
    required this.fuelUsedLiters,
    required this.isBestLap,
    required this.isLastLap,
  });
}

class SessionSummary {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final int validLapCount;
  final SummaryMetric<Duration> bestLap;
  final SummaryMetric<Duration> averageLap;
  final SummaryMetric<int> totalLaps;
  final SummaryMetric<double> fuelPerLap;
  final SummaryMetric<double> consistency;
  final List<LapSummaryRow> lapRows;
  final String disclaimer;

  const SessionSummary({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.validLapCount,
    required this.bestLap,
    required this.averageLap,
    required this.totalLaps,
    required this.fuelPerLap,
    required this.consistency,
    required this.lapRows,
    required this.disclaimer,
  });
}

class EngineerRecommendation {
  final String title;
  final String detail;
  final String signalLabel;
  final EngineerConfidence confidence;
  final String disclaimer;

  const EngineerRecommendation({
    required this.title,
    required this.detail,
    required this.signalLabel,
    this.confidence = EngineerConfidence.basic,
    required this.disclaimer,
  });
}

class SessionInsightContext {
  final Session session;
  final SessionSummary summary;

  const SessionInsightContext({required this.session, required this.summary});
}
