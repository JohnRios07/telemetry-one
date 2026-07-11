/// Application-wide configuration constants.
class AppConfig {
  AppConfig._();

  // UDP
  static const int gt7SendPort = 33739;
  static const int gt7ListenPort = 33740;
  static const Duration heartbeatInterval = Duration(milliseconds: 100);
  static const String heartbeatChar = 'C';

  // Performance
  static const Duration uiThrottle = Duration(milliseconds: 100);
  static const Duration connectionTimeout = Duration(seconds: 3);
  static const int maxPacketRateHz = 60;

  // Session recording
  static const int hiveFlushInterval = 100;

  // UI
  static const String appTitle = 'Telemetry One';
  static const String noDataText = 'Waiting for telemetry...';
  static const String disconnectedText = 'Disconnected';
  static const String connectedText = 'Connected';
}
