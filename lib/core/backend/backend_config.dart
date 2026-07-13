class BackendConfig {
  final String baseUrl;
  final Duration requestTimeout;
  final int maxRetries;
  final Duration retryBaseDelay;
  final int maxBatchSize;
  final int defaultBatchSize;

  /// Feature flag for V2 backend-sourced data consumption.
  /// When false (default), all V2 bridge providers return null,
  /// preserving local V1 as the source of truth.
  final bool useV2Data;

  /// Driver alias sent to backend on session creation.
  /// Used in V2 session alignment when [useV2Data] is true.
  final String driverAlias;

  const BackendConfig({
    this.baseUrl = 'http://localhost:8080',
    this.requestTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
    this.retryBaseDelay = const Duration(milliseconds: 500),
    this.maxBatchSize = 600,
    this.defaultBatchSize = 120,
    this.useV2Data = false,
    this.driverAlias = 'driver',
  });

  String get apiBase => '$baseUrl/api/v1';
}
