import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telemetry_one/app.dart';
import 'package:telemetry_one/core/network/udp_service.dart';
import 'package:telemetry_one/features/dashboard/providers/telemetry_provider.dart';

class _FakeFailedUdpService extends UdpService {
  @override
  Future<void> start(String ps5Ip) async {
    // Intentionally leave the service non-listening to simulate auto-connect failure.
  }
}

void main() {
  testWidgets(
    'shows connection screen when auto-connect does not reach listening state',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ps5_ip_address': '192.168.18.77',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            udpServiceProvider.overrideWithValue(_FakeFailedUdpService()),
          ],
          child: const TelemetryOneApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('PS5 IP ADDRESS'), findsOneWidget);
      expect(find.text('TELEMETRY ONE'), findsOneWidget);
    },
  );
}
