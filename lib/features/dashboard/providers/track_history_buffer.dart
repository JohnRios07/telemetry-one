class TrackHistoryPoint {
  final double x;
  final double z;

  const TrackHistoryPoint({required this.x, required this.z});
}

/// Ring buffer for the player's GT7 world position history.
///
/// Stores X/Z samples only for a top-down track trace.
class TrackHistoryBuffer {
  final int capacity;
  final List<TrackHistoryPoint?> _points;
  int _head = 0;
  bool _full = false;

  TrackHistoryBuffer({this.capacity = 7200})
    : _points = List<TrackHistoryPoint?>.filled(capacity, null);

  TrackHistoryBuffer._fromState({
    required this.capacity,
    required List<TrackHistoryPoint?> points,
    required int head,
    required bool full,
  }) : _points = points,
       _head = head,
       _full = full;

  TrackHistoryBuffer copy() {
    return TrackHistoryBuffer._fromState(
      capacity: capacity,
      points: List<TrackHistoryPoint?>.from(_points),
      head: _head,
      full: _full,
    );
  }

  int get length => _full ? capacity : _head;

  TrackHistoryPoint? get latest {
    if (length == 0) return null;
    final index = _head == 0 ? capacity - 1 : _head - 1;
    return _points[index];
  }

  List<TrackHistoryPoint> get points {
    final result = <TrackHistoryPoint>[];
    final count = length;
    final start = _full ? _head : 0;

    for (int i = 0; i < count; i++) {
      final point = _points[(start + i) % capacity];
      if (point != null) result.add(point);
    }

    return result;
  }

  void add(double x, double z) {
    final previous = latest;
    if (previous != null) {
      final dx = previous.x - x;
      final dz = previous.z - z;
      final movedSquared = (dx * dx) + (dz * dz);

      if (movedSquared < 0.0025) {
        return;
      }
    }

    _points[_head] = TrackHistoryPoint(x: x, z: z);
    _head = (_head + 1) % capacity;
    if (_head == 0) _full = true;
  }

  void clear() {
    _head = 0;
    _full = false;
    _points.fillRange(0, capacity, null);
  }
}
