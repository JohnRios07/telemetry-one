import 'dart:math' as math;

import '../../../core/storage/session_model.dart';
import '../domain/session_summary.dart';

class SessionAnalyzer {
  const SessionAnalyzer._();

  static List<CompleteLap> validLaps(Session session) {
    return session.laps.where(_isValidLap).toList(growable: false);
  }

  static EngineerSessionListItem buildListItem(Session session) {
    final List<CompleteLap> laps = validLaps(session);
    final Duration? bestLap = laps.isEmpty
        ? null
        : laps
              .map((CompleteLap lap) => lap.officialLapTime)
              .reduce(_minDuration);

    return EngineerSessionListItem(
      sessionId: session.id,
      startTime: session.startTime,
      endTime: session.endTime,
      game: session.game,
      validLapCount: laps.length,
      bestLap: bestLap,
      sessionDuration: session.duration,
    );
  }

  static SessionSummary buildSummary(Session session) {
    final List<CompleteLap> laps = validLaps(session);
    final Duration? bestLap = laps.isEmpty
        ? null
        : laps
              .map((CompleteLap lap) => lap.officialLapTime)
              .reduce(_minDuration);
    final Duration? averageLap = laps.isEmpty ? null : _averageDuration(laps);
    final List<double> fuelByLap = laps
        .map(fuelUsedForLap)
        .whereType<double>()
        .toList(growable: false);
    final double? averageFuelPerLap = fuelByLap.isEmpty
        ? null
        : fuelByLap.reduce((double a, double b) => a + b) / fuelByLap.length;
    final double? consistency = _consistencyPercent(laps);

    return SessionSummary(
      sessionId: session.id,
      startTime: session.startTime,
      endTime: session.endTime,
      validLapCount: laps.length,
      bestLap: bestLap != null
          ? SummaryMetric<Duration>.available(label: 'Best lap', value: bestLap)
          : const SummaryMetric<Duration>.unavailable(
              label: 'Best lap',
              reason: 'No hay vueltas válidas guardadas.',
            ),
      averageLap: averageLap != null
          ? SummaryMetric<Duration>.available(
              label: 'Avg lap',
              value: averageLap,
              confidence: EngineerConfidence.basic,
              note: 'Promedio simple de vueltas completas válidas.',
            )
          : const SummaryMetric<Duration>.unavailable(
              label: 'Avg lap',
              reason: 'No alcanza para calcular un promedio útil.',
            ),
      totalLaps: SummaryMetric<int>.available(
        label: 'Total laps',
        value: laps.length,
      ),
      fuelPerLap: averageFuelPerLap != null
          ? SummaryMetric<double>.available(
              label: 'Fuel / lap',
              value: averageFuelPerLap,
              confidence: EngineerConfidence.basic,
              note: 'Derivado de combustible inicial/final por vuelta cuando existe.',
            )
          : const SummaryMetric<double>.unavailable(
              label: 'Fuel / lap',
              reason: 'Faltan lecturas de combustible consistentes por vuelta.',
            ),
      consistency: consistency != null
          ? SummaryMetric<double>.available(
              label: 'Consistency',
              value: consistency,
              confidence: EngineerConfidence.basic,
              note: 'Calculado sobre la variación de tiempos entre vueltas válidas.',
            )
          : const SummaryMetric<double>.unavailable(
              label: 'Consistency',
              reason: 'Se necesitan al menos dos vueltas válidas.',
            ),
      lapRows: _buildLapRows(laps, bestLap),
      disclaimer: 'Resumen local GT7 basado solo en vueltas completas guardadas. No estima datos faltantes.',
    );
  }

  static double? fuelUsedForLap(CompleteLap lap) {
    final double? startFuel = lap.points.firstWhereOrNull((
      TelemetryPoint point,
    ) {
      return point.fuelCurrentL != null;
    })?.fuelCurrentL;
    final double? endFuel = lap.points.lastWhereOrNull((TelemetryPoint point) {
      return point.fuelCurrentL != null;
    })?.fuelCurrentL;

    if (startFuel == null || endFuel == null) {
      return null;
    }

    final double delta = startFuel - endFuel;
    if (delta.isNaN || delta.isInfinite || delta < 0) {
      return null;
    }

    return delta;
  }

  static double? averageTireTemperature(CompleteLap lap) {
    final List<double> samples = lap.points
        .map((TelemetryPoint point) => point.tireTemps)
        .whereType<List<double>>()
        .expand<double>((List<double> temps) => temps)
        .where((double temp) => temp > 0)
        .toList(growable: false);

    if (samples.isEmpty) {
      return null;
    }

    final double total = samples.reduce((double a, double b) => a + b);
    return total / samples.length;
  }

  static double brakeThrottleOverlapRatio(CompleteLap lap) {
    if (lap.points.isEmpty) {
      return 0;
    }

    final int overlapCount = lap.points.where((TelemetryPoint point) {
      return point.throttle >= 0.15 && point.brake >= 0.15;
    }).length;

    return overlapCount / lap.points.length;
  }

  static bool _isValidLap(CompleteLap lap) {
    if (lap.officialLapTime <= Duration.zero) {
      return false;
    }

    if (lap.isOutLap == true || lap.isPitLap == true) {
      return false;
    }

    return true;
  }

  static List<LapSummaryRow> _buildLapRows(
    List<CompleteLap> laps,
    Duration? bestLap,
  ) {
    if (laps.isEmpty) {
      return const <LapSummaryRow>[];
    }

    final String lastLapId = laps.last.id;
    return laps
        .map((CompleteLap lap) {
          return LapSummaryRow(
            lapId: lap.id,
            lapNumber: lap.lapNumber,
            lapTime: lap.officialLapTime,
            fuelUsedLiters: fuelUsedForLap(lap),
            isBestLap: bestLap != null && lap.officialLapTime == bestLap,
            isLastLap: lap.id == lastLapId,
          );
        })
        .toList(growable: false);
  }

  static Duration _averageDuration(List<CompleteLap> laps) {
    final int totalMilliseconds = laps
        .map((CompleteLap lap) => lap.officialLapTime.inMilliseconds)
        .reduce((int a, int b) => a + b);
    return Duration(milliseconds: (totalMilliseconds / laps.length).round());
  }

  static double? _consistencyPercent(List<CompleteLap> laps) {
    if (laps.length < 2) {
      return null;
    }

    final List<double> lapTimesMs = laps
        .map((CompleteLap lap) => lap.officialLapTime.inMilliseconds.toDouble())
        .toList(growable: false);
    final double mean =
        lapTimesMs.reduce((double a, double b) => a + b) / lapTimesMs.length;
    if (mean <= 0) {
      return null;
    }

    final double variance =
        lapTimesMs
            .map((double time) => math.pow(time - mean, 2).toDouble())
            .reduce((double a, double b) => a + b) /
        lapTimesMs.length;
    final double standardDeviation = math.sqrt(variance);
    final double normalizedSpread = standardDeviation / mean;

    final double score = (1 - normalizedSpread).clamp(0.0, 1.0) * 100;
    return score;
  }

  static Duration _minDuration(Duration current, Duration next) {
    return current <= next ? current : next;
  }
}

extension _FirstWhereOrNullExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final T value in this) {
      if (test(value)) {
        return value;
      }
    }

    return null;
  }

  T? lastWhereOrNull(bool Function(T value) test) {
    for (int index = length - 1; index >= 0; index -= 1) {
      final T value = this[index];
      if (test(value)) {
        return value;
      }
    }

    return null;
  }
}
