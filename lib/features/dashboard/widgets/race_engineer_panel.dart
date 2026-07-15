import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/race_engineer_advice_provider.dart';

class RaceEngineerPanel extends ConsumerWidget {
  const RaceEngineerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(raceEngineerAdviceProvider);
    final availability = ref.watch(raceEngineerAdviceAvailabilityProvider);
    final loading = state.status == RaceEngineerAdviceStatus.loading;
    final canRequest = !loading && availability.canRequest;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.darkSurface, width: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RACE ENGINEER',
                  style: AppTypography.inter(
                    size: 11,
                    color: AppColors.neonCyan,
                    weight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _ActionButton(
                label: _buttonLabel(state.status),
                enabled: canRequest,
                onPressed: () => ref
                    .read(raceEngineerAdviceProvider.notifier)
                    .requestAdvice(),
              ),
            ],
          ),
          if (availability.message != null) ...[
            const SizedBox(height: 6),
            Text(
              availability.message!,
              style: AppTypography.inter(
                size: 10,
                height: 1.25,
                color: AppColors.textDim,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(child: _PanelBody(state: state)),
        ],
      ),
    );
  }
}

String _buttonLabel(RaceEngineerAdviceStatus status) {
  return switch (status) {
    RaceEngineerAdviceStatus.success => 'Refresh',
    _ => 'Ask Engineer',
  };
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.carbonBlack,
        disabledForegroundColor: AppColors.textDim,
        backgroundColor: AppColors.neonCyan,
        disabledBackgroundColor: AppColors.darkSurface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: AppTypography.inter(
          size: 10,
          weight: FontWeight.w700,
          letterSpacing: 0.6,
          color: enabled ? AppColors.carbonBlack : AppColors.textDim,
        ),
      ),
    );
  }
}

class _PanelBody extends StatelessWidget {
  final RaceEngineerAdviceState state;

  const _PanelBody({required this.state});

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      RaceEngineerAdviceStatus.idle => const _MessageBody(
        title: 'Idle',
        message: 'Ask for a concise read on recent deterministic events.',
        color: AppColors.textSecondary,
      ),
      RaceEngineerAdviceStatus.loading => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.neonCyan,
          ),
        ),
      ),
      RaceEngineerAdviceStatus.success => _AdviceBody(state: state),
      RaceEngineerAdviceStatus.noEvents => _MessageBody(
        title: 'No events',
        message:
            state.message ??
            'No relevant engineer events are available for this session yet.',
        color: AppColors.warning,
      ),
      RaceEngineerAdviceStatus.rateLimited => _RateLimitedBody(state: state),
      RaceEngineerAdviceStatus.error => _MessageBody(
        title: 'Unavailable',
        message: state.message ?? 'Race Engineer request failed.',
        color: AppColors.error,
      ),
    };
  }
}

class _RateLimitedBody extends StatelessWidget {
  final RaceEngineerAdviceState state;

  const _RateLimitedBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final response = state.response;
    final providerInfo = response?.providerInfo;

    String warning = 'AI provider is rate-limited.';
    if (providerInfo?.retryAfterSeconds case final seconds?) {
      warning = 'AI provider is rate-limited. Try again in ~${seconds}s.';
    }

    final name = providerInfo?.providerName ?? providerInfo?.provider;
    final model = providerInfo?.model;
    final providerDetail = [name, model].whereType<String>().join(', ');
    if (providerDetail.isNotEmpty) {
      warning = '$warning\n$providerDetail';
    }

    final hasFallbackMessage =
        state.message != null && state.message!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            warning,
            style: AppTypography.inter(
              size: 10,
              height: 1.3,
              color: AppColors.warning,
            ),
          ),
        ),
        if (hasFallbackMessage) ...[
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                state.message!,
                style: AppTypography.inter(
                  size: 12,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (response?.referencedEvents case final events?
              when events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${events.length} events referenced',
                style: AppTypography.inter(size: 9, color: AppColors.textDim),
              ),
            ),
        ],
      ],
    );
  }
}

class _AdviceBody extends StatelessWidget {
  final RaceEngineerAdviceState state;

  const _AdviceBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final response = state.response;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              state.message ?? 'No advice text returned.',
              style: AppTypography.inter(
                size: 12,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        if (response != null) ...[
          const SizedBox(height: 6),
          Text(
            '${response.referencedEvents.length} events referenced',
            style: AppTypography.inter(size: 9, color: AppColors.textDim),
          ),
        ],
      ],
    );
  }
}

class _MessageBody extends StatelessWidget {
  final String title;
  final String message;
  final Color color;

  const _MessageBody({
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.inter(
            size: 10,
            weight: FontWeight.w700,
            letterSpacing: 1.2,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.inter(
            size: 11,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
