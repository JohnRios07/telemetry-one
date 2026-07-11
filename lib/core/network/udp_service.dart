import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';

/// Connection state for the UDP telemetry stream.
enum UdpConnectionState {
  idle,
  connecting,
  listening,
  disconnected,
}

/// UDP service that receives GT7 telemetry packets.
///
/// Opens a [RawDatagramSocket] on port 33740, sends heartbeat 'A' to
/// the PS5 at 33739 every 100ms, and exposes a [Stream] of raw bytes.
class UdpService {
  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _timeoutTimer;
  StreamSubscription<RawSocketEvent>? _subscription;

  final _stateController =
      StreamController<UdpConnectionState>.broadcast();
  final _packetController = StreamController<Uint8List>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  String? _ps5Ip;
  DateTime? _lastPacketTime;

  /// Stream of connection state changes.
  Stream<UdpConnectionState> get stateStream => _stateController.stream;

  /// Stream of raw UDP packet bytes.
  Stream<Uint8List> get packetStream => _packetController.stream;

  /// Stream of error messages.
  Stream<String> get errorStream => _errorController.stream;

  /// Current connection state.
  UdpConnectionState get currentState => _currentState;
  UdpConnectionState _currentState = UdpConnectionState.idle;

  void _setState(UdpConnectionState state) {
    debugPrint('[UDP] State: $_currentState → $state');
    _currentState = state;
    _stateController.add(state);
  }

  /// Start listening for GT7 telemetry from [ps5Ip].
  Future<void> start(String ps5Ip) async {
    if (_currentState == UdpConnectionState.listening) {
      await stop();
    }

    _ps5Ip = ps5Ip;
    _setState(UdpConnectionState.connecting);

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConfig.gt7ListenPort,
      );

      _lastPacketTime = DateTime.now();

      _subscription = _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            debugPrint('[UDP] 📦 Received ${datagram.data.length} bytes '
                'from ${datagram.address.address}:${datagram.port}');
            _lastPacketTime = DateTime.now();
            _resetTimeoutTimer();
            _packetController.add(datagram.data);
          } else {
            debugPrint('[UDP] ⚠️ Null datagram received');
          }
        } else {
          debugPrint('[UDP] Socket event: $event');
        }
      });
      debugPrint('[UDP] ✅ Socket bound on port ${AppConfig.gt7ListenPort}');

      _startHeartbeat();
      _startTimeoutDetection();

      _setState(UdpConnectionState.listening);
    } catch (e) {
      _errorController.add('Failed to bind socket: $e');
      _setState(UdpConnectionState.disconnected);
    }
  }

  /// Stop listening and close the socket.
  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    _setState(UdpConnectionState.disconnected);
  }

  /// Send heartbeat 'A' to PS5 every 100ms to maintain the data stream.
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(AppConfig.heartbeatInterval, (_) {
      if (_ps5Ip == null) return;
      _sendHeartbeat();
    });
  }

  Future<void> _sendHeartbeat() async {
    try {
      _socket?.send(
        [AppConfig.heartbeatChar.codeUnitAt(0)],
        InternetAddress(_ps5Ip!),
        AppConfig.gt7SendPort,
      );
      debugPrint('[UDP] 💓 Heartbeat sent to $_ps5Ip:${AppConfig.gt7SendPort}');
    } catch (e) {
      debugPrint('[UDP] ❌ Heartbeat send failed: $e');
    }
  }

  /// Detect connection timeout (no packets for 3 seconds).
  void _startTimeoutDetection() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lastPacketTime != null &&
          DateTime.now().difference(_lastPacketTime!) >
              AppConfig.connectionTimeout) {
        debugPrint('[UDP] ⏰ Connection timeout — no packets for 3s');
        _errorController.add('Connection timeout');
        _setState(UdpConnectionState.disconnected);
      }
    });
  }

  void _resetTimeoutTimer() {
    // Reset is implicit — the timer checks every second
  }

  /// Clean up all resources.
  void dispose() {
    stop();
    _stateController.close();
    _packetController.close();
    _errorController.close();
  }
}
