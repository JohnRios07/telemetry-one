/// Ring buffer for telemetry graph traces.
///
/// Stores throttle/brake samples over time for the MoTeC-style graph.
/// At 60Hz, 300 samples ≈ 5 seconds of history.
class TelemetryBuffer {
  final int capacity;
  final List<double> _throttle;
  final List<double> _brake;
  int _head = 0;
  bool _full = false;

  TelemetryBuffer({this.capacity = 300})
    : _throttle = List<double>.filled(capacity, 0),
      _brake = List<double>.filled(capacity, 0);

  TelemetryBuffer._fromState({
    required this.capacity,
    required List<double> throttle,
    required List<double> brake,
    required int head,
    required bool full,
  }) : _throttle = throttle,
       _brake = brake,
       _head = head,
       _full = full;

  TelemetryBuffer copy() {
    return TelemetryBuffer._fromState(
      capacity: capacity,
      throttle: List<double>.from(_throttle),
      brake: List<double>.from(_brake),
      head: _head,
      full: _full,
    );
  }

  void add(double throttle, double brake) {
    _throttle[_head] = throttle;
    _brake[_head] = brake;
    _head = (_head + 1) % capacity;
    if (_head == 0) _full = true;
  }

  int get length => _full ? capacity : _head;

  /// Returns samples in chronological order (oldest first).
  List<double> get throttleTrace {
    final result = <double>[];
    final count = length;
    final start = _full ? _head : 0;
    for (int i = 0; i < count; i++) {
      result.add(_throttle[(start + i) % capacity]);
    }
    return result;
  }

  List<double> get brakeTrace {
    final result = <double>[];
    final count = length;
    final start = _full ? _head : 0;
    for (int i = 0; i < count; i++) {
      result.add(_brake[(start + i) % capacity]);
    }
    return result;
  }

  void clear() {
    _head = 0;
    _full = false;
    _throttle.fillRange(0, capacity, 0);
    _brake.fillRange(0, capacity, 0);
  }
}
