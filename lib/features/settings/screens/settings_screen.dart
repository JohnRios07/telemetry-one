import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../connection/screens/connection_screen.dart';
import '../../../core/backend/settings_bootstrap_dto.dart';
import '../../../core/network/connection_manager.dart';
import '../../../core/network/udp_service.dart';
import '../../../features/dashboard/providers/telemetry_provider.dart';
import '../../../shared/widgets/panel_card.dart';
import '../providers/settings_bootstrap_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapAsync = ref.watch(settingsBootstrapProvider);

    return Scaffold(
      backgroundColor: AppColors.carbonBlack,
      appBar: AppBar(
        backgroundColor: AppColors.graphite,
        title: Text(
          'Settings',
          style: AppTypography.orbitron(
            size: 18,
            weight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: SafeArea(
        child: bootstrapAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.telemetryOrange),
          ),
          error: (error, stackTrace) => _SettingsErrorState(
            message: 'Could not load settings bootstrap.',
            detail: error.toString(),
            onRetry: () => ref.refresh(settingsBootstrapProvider),
          ),
          data: (response) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ConnectionSectionCard(
                onResetIp: () async {
                  final udpService = ref.read(udpServiceProvider);
                  await udpService.stop();
                  await ConnectionManager.clearIp();

                  if (!context.mounted) return;

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const ConnectionScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
              _BootstrapSectionCard(
                title: 'Client hints',
                section: response.bootstrap.clientHints,
              ),
              const SizedBox(height: 12),
              _BootstrapSectionCard(
                title: 'Limits',
                section: response.bootstrap.limits,
              ),
              const SizedBox(height: 12),
              _BootstrapSectionCard(
                title: 'Capabilities',
                section: response.bootstrap.capabilities,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionSectionCard extends StatelessWidget {
  final Future<void> Function() onResetIp;

  const _ConnectionSectionCard({required this.onResetIp});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PS5 CONNECTION',
            style: AppTypography.inter(
              size: 11,
              color: AppColors.neonCyan,
              weight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Forget the saved PS5 IP and return to the connection screen to enter a new one.',
            style: AppTypography.inter(
              size: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => onResetIp(),
            icon: const Icon(Icons.wifi_off_rounded),
            label: const Text('Change PS5 IP'),
          ),
        ],
      ),
    );
  }
}

class _BootstrapSectionCard extends StatelessWidget {
  final String title;
  final SettingsBootstrapSection section;

  const _BootstrapSectionCard({required this.title, required this.section});

  @override
  Widget build(BuildContext context) {
    final entries = section.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.inter(
              size: 11,
              color: AppColors.neonCyan,
              weight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'No values available.',
              style: AppTypography.inter(
                size: 13,
                color: AppColors.textSecondary,
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < entries.length; index++) ...[
                  _BootstrapEntryRow(
                    label: entries[index].key,
                    value: settingsBootstrapSectionToJsonString(
                      entries[index].value,
                    ),
                  ),
                  if (index < entries.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BootstrapEntryRow extends StatelessWidget {
  final String label;
  final String value;

  const _BootstrapEntryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppTypography.inter(
              size: 13,
              color: AppColors.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: AppTypography.inter(
              size: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsErrorState extends StatelessWidget {
  final String message;
  final String detail;
  final VoidCallback onRetry;

  const _SettingsErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: PanelCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.orbitron(
                  size: 18,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  size: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
