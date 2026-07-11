import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/connection_manager.dart';

/// Provider for the saved PS5 IP address.
final ps5IpProvider = StateProvider<String?>((ref) {
  // Initial value is loaded asynchronously — we use FutureProvider for the actual load
  return null;
});

/// Future provider that loads the saved IP on app start.
final savedIpProvider = FutureProvider<String?>((ref) async {
  return ConnectionManager.loadSavedIp();
});

/// Provider for connection status messages shown in UI.
final connectionStatusProvider = StateProvider<String>((ref) {
  return 'Disconnected';
});
