import '../../../core/storage/session_model.dart';
import '../domain/lap_comparison.dart';
import '../domain/session_summary.dart';
import 'lap_alignment.dart';
import 'session_analyzer.dart';

class RecommendationEngine {
  const RecommendationEngine._();

  static List<EngineerRecommendation> build(Session session) {
    final SessionSummary summary = SessionAnalyzer.buildSummary(session);
    final List<CompleteLap> laps = SessionAnalyzer.validLaps(session);
    final List<EngineerRecommendation> recommendations =
        <EngineerRecommendation>[];

    final LapComparisonResult comparison = LapAlignment.compareSessionLaps(
      session,
    );
    if (comparison.isAvailable && comparison.summary != null) {
      final Duration delta = comparison.summary!.lapTimeDelta;
      if (delta > const Duration(milliseconds: 500)) {
        recommendations.add(
          EngineerRecommendation(
            title: 'La última vuelta cayó frente a tu referencia',
            detail:
                'La última vuelta quedó ${_formatDelta(delta)} por detrás de la mejor guardada en esta sesión.',
            signalLabel: 'Comparación local best-vs-last',
            disclaimer:
                'Heurística básica V1. No identifica curvas ni causas exactas.',
          ),
        );
      }
    }

    if (summary.consistency.isAvailable &&
        (summary.consistency.value ?? 100) < 95) {
      recommendations.add(
        EngineerRecommendation(
          title: 'Hay margen en repetibilidad',
          detail:
              'La consistencia entre vueltas válidas quedó en ${summary.consistency.value!.toStringAsFixed(1)}%.',
          signalLabel: 'Variación simple de tiempos de vuelta',
          disclaimer: 'Heurística básica V1 basada solo en tiempos guardados.',
        ),
      );
    }

    final double? fuelFirst = laps.isEmpty
        ? null
        : SessionAnalyzer.fuelUsedForLap(laps.first);
    final double? fuelLast = laps.isEmpty
        ? null
        : SessionAnalyzer.fuelUsedForLap(laps.last);
    if (fuelFirst != null && fuelLast != null && fuelLast - fuelFirst >= 0.15) {
      recommendations.add(
        EngineerRecommendation(
          title: 'El consumo por vuelta subió al final',
          detail:
              'La última vuelta usó ${fuelLast.toStringAsFixed(2)} L frente a ${fuelFirst.toStringAsFixed(2)} L al inicio.',
          signalLabel: 'Combustible local por vuelta',
          disclaimer: 'Heurística básica V1. Útil solo cuando las lecturas de combustible son completas.',
        ),
      );
    }

    if (laps.length >= 2) {
      final double bestOverlap = SessionAnalyzer.brakeThrottleOverlapRatio(
        laps.reduce((CompleteLap current, CompleteLap next) {
          return current.officialLapTime <= next.officialLapTime
              ? current
              : next;
        }),
      );
      final double lastOverlap = SessionAnalyzer.brakeThrottleOverlapRatio(
        laps.last,
      );
      if (lastOverlap - bestOverlap >= 0.08) {
        recommendations.add(
          EngineerRecommendation(
            title: 'La última vuelta mezcló más freno y acelerador',
            detail:
                'El solapamiento subió de ${(bestOverlap * 100).toStringAsFixed(0)}% a ${(lastOverlap * 100).toStringAsFixed(0)}% de los puntos guardados.',
            signalLabel: 'Solapamiento freno/acelerador',
            disclaimer: 'Heurística básica V1. Describe la señal, no una corrección exacta.',
          ),
        );
      }
    }

    final double? firstLapTemp = laps.isEmpty
        ? null
        : SessionAnalyzer.averageTireTemperature(laps.first);
    final double? lastLapTemp = laps.isEmpty
        ? null
        : SessionAnalyzer.averageTireTemperature(laps.last);
    if (firstLapTemp != null &&
        lastLapTemp != null &&
        lastLapTemp - firstLapTemp >= 4) {
      recommendations.add(
        EngineerRecommendation(
          title: 'Las temperaturas medias subieron con la tanda',
          detail:
              'La media pasó de ${firstLapTemp.toStringAsFixed(1)}° a ${lastLapTemp.toStringAsFixed(1)}° entre la primera y la última vuelta válida.',
          signalLabel: 'Temperatura media de neumáticos',
          disclaimer: 'Heurística básica V1. Muestra tendencia térmica, no desgaste real.',
        ),
      );
    }

    return recommendations.take(4).toList(growable: false);
  }

  static String _formatDelta(Duration delta) {
    final int milliseconds = delta.inMilliseconds.abs();
    final int minutes = milliseconds ~/ 60000;
    final int seconds = (milliseconds % 60000) ~/ 1000;
    final int millis = milliseconds % 1000;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.${(millis ~/ 10).toString().padLeft(2, '0')}';
    }

    return '$seconds.${(millis ~/ 10).toString().padLeft(2, '0')} s';
  }
}
