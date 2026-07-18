import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/core/backend/settings_bootstrap_dto.dart';
import 'package:telemetry_one/core/network/connection_manager.dart';
import 'package:telemetry_one/features/settings/screens/settings_screen.dart';

class _FakeSettingsClient extends BackendClient {
  int callCount = 0;
  Completer<SettingsBootstrapResponse>? completer;
  BackendRequestException? exception;
  SettingsBootstrapResponse? response;

  _FakeSettingsClient()
    : super(config: const BackendConfig(baseUrl: 'http://example.test'));

  @override
  Future<SettingsBootstrapResponse> getSettingsBootstrap() async {
    callCount++;
    if (completer != null) {
      return completer!.future;
    }
    final error = exception;
    if (error != null) throw error;
    return response ??
        const SettingsBootstrapResponse(
          apiVersion: settingsBootstrapApiVersion,
          bootstrap: SettingsBootstrap(
            clientHints: SettingsBootstrapSection(values: {'alias': 'alex'}),
            limits: SettingsBootstrapSection(values: {'maxBatchFrames': 600}),
            capabilities: SettingsBootstrapSection(values: {'readOnly': true}),
          ),
        );
  }
}

void main() {
  testWidgets('shows loading state while fetching bootstrap', (tester) async {
    final client = _FakeSettingsClient()
      ..completer = Completer<SettingsBootstrapResponse>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows data state with bootstrap sections', (tester) async {
    final client = _FakeSettingsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('CLIENT HINTS'), findsOneWidget);
    expect(find.text('LIMITS'), findsOneWidget);
    expect(find.text('CAPABILITIES'), findsOneWidget);
    expect(find.textContaining('alias'), findsOneWidget);
    expect(find.textContaining('readOnly'), findsOneWidget);
  });

  testWidgets('shows error state and retry action', (tester) async {
    final client = _FakeSettingsClient()
      ..exception = const BackendRequestException(
        statusCode: 0,
        error: BackendError(code: 'network_error', message: 'offline'),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Could not load settings bootstrap.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'resetting PS5 IP clears saved value and opens connection screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ps5_ip_address': '192.168.1.55',
      });

      final client = _FakeSettingsClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [backendClientProvider.overrideWithValue(client)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Change PS5 IP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('PS5 IP ADDRESS'), findsOneWidget);
      expect(await ConnectionManager.loadSavedIp(), isNull);
    },
  );
}
