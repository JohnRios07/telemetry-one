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
        points: (map['points'] as List?)
                ?.map((p) => _parsePoint(p as Map<String, dynamic>))
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
      speedKmh: (map['speed_kmh'] as num).toDouble(),
      rpm: (map['rpm'] as num).toDouble(),
      gear: map['gear'] as int,
      throttle: (map['throttle'] as num).toDouble(),
      brake: (map['brake'] as num).toDouble(),
    );
  }
}
