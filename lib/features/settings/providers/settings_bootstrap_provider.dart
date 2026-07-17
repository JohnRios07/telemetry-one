import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_sync_provider.dart';
import '../../../core/backend/settings_bootstrap_dto.dart';

final settingsBootstrapProvider =
    FutureProvider.autoDispose<SettingsBootstrapResponse>((ref) async {
  final client = ref.watch(backendClientProvider);
  return client.getSettingsBootstrap();
});
