import 'dart:convert';

const String settingsBootstrapApiVersion = 'telemetry-one.api.v2';

class SettingsBootstrapContractException extends FormatException {
  SettingsBootstrapContractException(super.message);
}

class SettingsBootstrapResponse {
  final String apiVersion;
  final SettingsBootstrap bootstrap;

  const SettingsBootstrapResponse({
    required this.apiVersion,
    required this.bootstrap,
  });

  factory SettingsBootstrapResponse.fromJson(Map<String, dynamic> json) {
    final payload = _responsePayload(json);
    final apiVersion = json['apiVersion'] as String? ??
        payload['apiVersion'] as String?;

    if (apiVersion != settingsBootstrapApiVersion) {
      throw SettingsBootstrapContractException(
        'Unsupported apiVersion: ${apiVersion ?? 'missing'}',
      );
    }

    final bootstrapJson = payload['bootstrap'];
    if (bootstrapJson is! Map<String, dynamic>) {
      throw SettingsBootstrapContractException('Missing bootstrap payload');
    }

    return SettingsBootstrapResponse(
      apiVersion: apiVersion!,
      bootstrap: SettingsBootstrap.fromJson(bootstrapJson),
    );
  }
}

class SettingsBootstrap {
  final SettingsBootstrapSection clientHints;
  final SettingsBootstrapSection limits;
  final SettingsBootstrapSection capabilities;

  const SettingsBootstrap({
    required this.clientHints,
    required this.limits,
    required this.capabilities,
  });

  factory SettingsBootstrap.fromJson(Map<String, dynamic> json) {
    final clientHints = json['clientHints'];
    final limits = json['limits'];
    final capabilities = json['capabilities'];

    if (clientHints is! Map<String, dynamic>) {
      throw SettingsBootstrapContractException(
        'Missing bootstrap.clientHints payload',
      );
    }
    if (limits is! Map<String, dynamic>) {
      throw SettingsBootstrapContractException(
        'Missing bootstrap.limits payload',
      );
    }
    if (capabilities is! Map<String, dynamic>) {
      throw SettingsBootstrapContractException(
        'Missing bootstrap.capabilities payload',
      );
    }

    return SettingsBootstrap(
      clientHints: SettingsBootstrapSection.fromJson(clientHints),
      limits: SettingsBootstrapSection.fromJson(limits),
      capabilities: SettingsBootstrapSection.fromJson(capabilities),
    );
  }
}

class SettingsBootstrapSection {
  final Map<String, dynamic> values;

  const SettingsBootstrapSection({required this.values});

  factory SettingsBootstrapSection.fromJson(Map<String, dynamic> json) {
    return SettingsBootstrapSection(values: Map.unmodifiable(json));
  }

  Iterable<MapEntry<String, dynamic>> get entries => values.entries;

  bool get isEmpty => values.isEmpty;
}

Map<String, dynamic> _responsePayload(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) {
    return data;
  }
  return json;
}

String settingsBootstrapSectionToJsonString(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  if (value is Map || value is Iterable) return jsonEncode(value);
  return value.toString();
}
