import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'config/theme/app_theme.dart';
import 'core/network/connection_manager.dart';
import 'core/network/udp_service.dart';
import 'features/dashboard/providers/telemetry_provider.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'connection/screens/connection_screen.dart';

/// Root widget of Telemetry One.
///
/// Determines the initial route based on saved PS5 IP:
/// - No saved IP → [ConnectionScreen]
/// - Saved IP → [DashboardScreen] when auto-connect reaches listening state,
///   otherwise [ConnectionScreen]
class TelemetryOneApp extends ConsumerStatefulWidget {
  const TelemetryOneApp({super.key});

  @override
  ConsumerState<TelemetryOneApp> createState() => _TelemetryOneAppState();
}

class _TelemetryOneAppState extends ConsumerState<TelemetryOneApp> {
  bool _checking = true;
  Widget _initialScreen = const ConnectionScreen();

  @override
  void initState() {
    super.initState();
    _checkSavedIp();
  }

  Future<void> _checkSavedIp() async {
    final savedIp = await ConnectionManager.loadSavedIp();
    if (mounted) {
      Widget initialScreen = const ConnectionScreen();

      if (savedIp != null) {
        final udpService = ref.read(udpServiceProvider);
        try {
          await udpService.start(savedIp);
        } catch (_) {
          // Keep the connection screen if auto-connect fails for any reason.
        }

        initialScreen = udpService.currentState == UdpConnectionState.listening
            ? const DashboardScreen()
            : const ConnectionScreen();
      }

      if (!mounted) return;

      setState(() {
        _checking = false;
        _initialScreen = initialScreen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lock to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (_checking) {
      return MaterialApp(
        title: 'Telemetry One',
        theme: AppTheme.dark,
        home: const Scaffold(
          backgroundColor: Color(0xFF0A0A0A),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Telemetry One',
      theme: AppTheme.dark,
      home: _initialScreen,
    );
  }
}
