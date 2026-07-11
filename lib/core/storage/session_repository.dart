import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'session_model.dart';

/// Repository for persisting and retrieving telemetry sessions via Hive.
class SessionRepository {
  static const String _boxName = 'sessions';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  /// Save a session to local storage.
  Future<void> saveSession(Session session) async {
    await _box.put(session.id, jsonEncode(session.toJson()));
  }

  /// Retrieve all saved sessions, ordered by start time descending.
  Future<List<Session>> getSessions() async {
    final sessions = <Session>[];
    for (final key in _box.keys) {
      final json = _box.get(key) as String?;
      if (json != null) {
        final session = _parseSession(json);
        if (session != null) sessions.add(session);
      }
    }
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  /// Delete a session by ID.
  Future<void> deleteSession(String id) async {
    await _box.delete(id);
  }

  Session? _parseSession(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return Session(
        id: map['id'] as String,
        startTime: DateTime.parse(map['start_time'] as String),
        endTime: map['end_time'] != null
            ? DateTime.parse(map['end_time'] as String)
            : null,
        game: map['game'] as String? ?? 'GT7',
        ps5Ip: map['ps5_ip'] as String?,
        points:
            (map['points'] as List?)
                ?.map((p) => _parsePoint(p as Map<String, dynamic>))
                .toList() ??
            [],
        laps:
            (map['laps'] as List?)
                ?.map((lap) => _parseLap(lap as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (_) {
      return null;
    }
  }

  TelemetryPoint _parsePoint(Map<String, dynamic> map) {
    return TelemetryPoint(
      timestamp: DateTime.parse(map['timestamp'] as String),
      packetId: map['packet_id'] as int?,
      currentLap: map['current_lap'] as int?,
      currentLapTime: _parseDuration(map['current_lap_time_ms']),
      speedKmh: (map['speed_kmh'] as num).toDouble(),
      rpm: (map['rpm'] as num).toDouble(),
      gear: map['gear'] as int,
      throttle: (map['throttle'] as num).toDouble(),
      brake: (map['brake'] as num).toDouble(),
      clutch: (map['clutch'] as num?)?.toDouble(),
      fuelCurrentL: (map['fuel_current_l'] as num?)?.toDouble(),
      fuelCapacityL: (map['fuel_capacity_l'] as num?)?.toDouble(),
      tireTemps: (map['tire_temps'] as List?)
          ?.map((temp) => (temp as num).toDouble())
          .toList(),
      posX: (map['pos_x'] as num?)?.toDouble(),
      posY: (map['pos_y'] as num?)?.toDouble(),
      posZ: (map['pos_z'] as num?)?.toDouble(),
    );
  }

  CompleteLap _parseLap(Map<String, dynamic> map) {
    return CompleteLap(
      id: map['id'] as String,
      lapNumber: map['lap_number'] as int,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      officialLapTime: _parseDuration(map['official_lap_time_ms'])!,
      bestLapTimeAtCompletion: _parseDuration(
        map['best_lap_time_at_completion_ms'],
      ),
      position: map['position'] as int?,
      isOutLap: map['is_out_lap'] as bool?,
      isPitLap: map['is_pit_lap'] as bool?,
      points:
          (map['points'] as List?)
              ?.map((p) => _parsePoint(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Duration? _parseDuration(dynamic milliseconds) {
    if (milliseconds == null) return null;
    return Duration(milliseconds: (milliseconds as num).round());
  }
}
