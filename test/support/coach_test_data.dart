import 'dart:math' as math;

import 'package:telemetry_one/core/storage/session_model.dart';

final DateTime coachRefDate = DateTime(2026);

TelemetryPoint coachPoint({
  required int index,
  required double speedKmh,
  required double throttle,
  required double brake,
  double? posX,
  double? posY = 0,
  double? posZ = 0,
}) {
  return TelemetryPoint(
    timestamp: coachRefDate.add(Duration(milliseconds: index * 100)),
    speedKmh: speedKmh,
    rpm: 6000,
    gear: 4,
    throttle: throttle,
    brake: brake,
    posX: posX,
    posY: posY,
    posZ: posZ,
  );
}

CompleteLap buildCoachLap({
  required String id,
  required int lapNumber,
  required int officialLapTimeMs,
  Set<int> weakTurns = const <int>{},
  bool includePositions = true,
  bool? isOutLap,
  bool? isPitLap,
}) {
  final Duration lapTime = Duration(milliseconds: officialLapTimeMs);
  return CompleteLap(
    id: id,
    lapNumber: lapNumber,
    startTime: coachRefDate,
    endTime: coachRefDate.add(lapTime),
    officialLapTime: lapTime,
    isOutLap: isOutLap,
    isPitLap: isPitLap,
    points: buildCoachPoints(
      weakTurns: weakTurns,
      includePositions: includePositions,
    ),
  );
}

Session buildCoachSession(List<CompleteLap> laps) {
  return Session(
    id: 'coach-session',
    startTime: coachRefDate,
    endTime: coachRefDate.add(const Duration(minutes: 20)),
    trackName: 'Local Test Track',
    laps: laps,
  );
}

List<TelemetryPoint> buildCoachPoints({
  Set<int> weakTurns = const <int>{},
  bool includePositions = true,
}) {
  return List<TelemetryPoint>.generate(121, (int index) {
    final _TurnState? turnState = _turnForIndex(index);
    double x = index.toDouble();
    double z = 0;
    double speed = 182;
    double throttle = 0.92;
    double brake = 0;

    for (int turn = 1; turn <= 3; turn += 1) {
      final _TurnState? localTurn = _turnForIndex(index, turn: turn);
      if (localTurn == null) {
        continue;
      }

      final bool weak = weakTurns.contains(turn);
      final double amplitude = switch (turn) {
        1 => weak ? 18 : 12,
        2 => weak ? -22 : -15,
        _ => weak ? 16 : 10,
      };
      z += amplitude * math.sin(localTurn.localProgress * math.pi);
      if (weak) {
        z += (amplitude.abs() * 0.18) * math.sin(localTurn.localProgress * math.pi * 3);
      }
    }

    if (turnState != null) {
      final bool weak = weakTurns.contains(turnState.turnNumber);
      final double local = turnState.localProgress;
      speed = 152 - (46 * math.sin(local * math.pi));
      brake = local <= 0.48 ? 0.18 + (0.34 * math.sin(local * math.pi)) : 0.03;
      throttle = local < 0.55
          ? 0.18
          : 0.52 + (((local - 0.55) / 0.45).clamp(0.0, 1.0) * 0.40);

      if (weak) {
        speed -= turnState.turnNumber == 2 ? 14 : 9;
        if (local < 0.72) {
          throttle = 0.28;
        } else {
          throttle = 0.62 + (((local - 0.72) / 0.28).clamp(0.0, 1.0) * 0.18);
        }
        if (local < 0.66) {
          brake = math.max(brake, 0.14);
        }
      }
    }

    return coachPoint(
      index: index,
      speedKmh: speed,
      throttle: throttle,
      brake: brake,
      posX: includePositions ? x : null,
      posZ: includePositions ? z : null,
      posY: includePositions ? 0 : null,
    );
  }, growable: false);
}

_TurnState? _turnForIndex(int index, {int? turn}) {
  const List<(int, int)> windows = <(int, int)>[(20, 35), (55, 72), (90, 108)];
  for (int turnIndex = 0; turnIndex < windows.length; turnIndex += 1) {
    final (int start, int end) = windows[turnIndex];
    if (index < start || index > end) {
      continue;
    }
    final int turnNumber = turnIndex + 1;
    if (turn != null && turnNumber != turn) {
      continue;
    }

    return _TurnState(
      turnNumber: turnNumber,
      localProgress: (index - start) / (end - start),
    );
  }

  return null;
}

class _TurnState {
  final int turnNumber;
  final double localProgress;

  const _TurnState({required this.turnNumber, required this.localProgress});
}
