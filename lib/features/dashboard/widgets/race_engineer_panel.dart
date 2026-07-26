import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../../../../core/backend/telemetry_frame_dto.dart';
import '../providers/race_engineer_advice_provider.dart';

class RaceEngineerPanel extends ConsumerWidget {
  final bool compact;

  const RaceEngineerPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(raceEngineerAdviceAutoPollControllerProvider);
    final state = ref.watch(raceEngineerAdviceProvider);
    final availability = ref.watch(raceEngineerAdviceAvailabilityProvider);
    final loading = state.status == RaceEngineerAdviceStatus.loading;
    final cooldownSeconds = state.remainingCooldownSeconds();
    final canRequest =
        !loading && availability.canRequest && cooldownSeconds == null;
    final cooldownMessage = cooldownSeconds != null
        ? 'Race Engineer is cooling down. Retry in ${cooldownSeconds}s.'
        : null;

    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
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
                    size: compact ? 10 : 11,
                    color: AppColors.neonCyan,
                    weight: FontWeight.w700,
                    letterSpacing: compact ? 1.1 : 1.5,
                  ),
                ),
              ),
              _ActionButton(
                label: _buttonLabel(state.status, cooldownSeconds),
                enabled: canRequest,
                onPressed: () => ref
                    .read(raceEngineerAdviceProvider.notifier)
                    .requestAdvice(),
              ),
            ],
          ),
          if (cooldownMessage != null || availability.message != null) ...[
            SizedBox(height: compact ? 4 : 6),
            Text(
              cooldownMessage ?? availability.message!,
              style: AppTypography.inter(
                size: compact ? 9 : 10,
                height: 1.25,
                color: AppColors.textDim,
              ),
            ),
          ],
          SizedBox(height: compact ? 8 : 10),
          Expanded(child: _PanelBody(state: state, compact: compact)),
        ],
      ),
    );
  }
}

String _buttonLabel(RaceEngineerAdviceStatus status, int? cooldownSeconds) {
  if (cooldownSeconds != null) return 'Retry in ${cooldownSeconds}s';

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
  final bool compact;

  const _PanelBody({required this.state, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      RaceEngineerAdviceStatus.idle => _MessageBody(
        compact: compact,
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
        compact: compact,
        title: 'No events',
        message:
            state.message ??
            'No relevant engineer events are available for this session yet.',
        color: AppColors.warning,
      ),
      RaceEngineerAdviceStatus.rateLimited => _RateLimitedBody(state: state),
      RaceEngineerAdviceStatus.error => _MessageBody(
        compact: compact,
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
    final referencedEvents = response?.referencedEvents ?? const <String>[];
    final hasReferencedEvents = referencedEvents.isNotEmpty;
    final visibleSignals = response?.visibleSignals ?? const <RaceEngineerSignal>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
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
                      size: 9,
                      height: 1.3,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                if (hasFallbackMessage) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.message!,
                    style: AppTypography.inter(
                      size: 11,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                if (response != null &&
                    (response.window?.derivedSignalCount != null ||
                        visibleSignals.isNotEmpty)) ...[
                  const SizedBox(height: 6),
                  _SignalSummary(response: response),
                ],
                if (hasReferencedEvents) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${referencedEvents.length} events referenced',
                    style: AppTypography.inter(
                      size: 8,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
    final visibleSignals = response?.visibleSignals ?? const <RaceEngineerSignal>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.message ?? 'No advice text returned.',
                  style: AppTypography.inter(
                    size: 11,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (response != null &&
                    (visibleSignals.isNotEmpty ||
                        response.window?.derivedSignalCount != null)) ...[
                  const SizedBox(height: 8),
                  _SignalSummary(response: response),
                ],
                if (response != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${response.referencedEvents.length} events referenced',
                    style: AppTypography.inter(
                      size: 8,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SignalSummary extends StatelessWidget {
  final RaceEngineerAdviceResponse response;

  const _SignalSummary({required this.response});

  @override
  Widget build(BuildContext context) {
    final derivedSignalCount = response.window?.derivedSignalCount;
    final signals = response.visibleSignals;
    final signalCountLabel = derivedSignalCount != null
        ? '$derivedSignalCount derived signals'
        : '${signals.length} signals';
    final visibleSignals = signals.take(3).toList(growable: false);
    final remainingSignals = signals.length - visibleSignals.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MetaChip(
              label: _humanizeStatus(response.status),
              color: AppColors.textSecondary,
            ),
            if (derivedSignalCount != null)
              _MetaChip(label: signalCountLabel, color: AppColors.neonCyan)
            else if (signals.isNotEmpty)
              _MetaChip(label: signalCountLabel, color: AppColors.neonCyan),
          ],
        ),
        if (visibleSignals.isNotEmpty) ...[
          const SizedBox(height: 8),
          Column(
            children: [
              for (final signal in visibleSignals) ...[
                _SignalRow(signal: signal),
                if (signal != visibleSignals.last) const SizedBox(height: 6),
              ],
              if (remainingSignals > 0) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+$remainingSignals more signals',
                    style: AppTypography.inter(
                      size: 8,
                      color: AppColors.textDim,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24), width: 0.75),
      ),
      child: Text(
        label,
        style: AppTypography.inter(
          size: 8,
          weight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final RaceEngineerSignal signal;

  const _SignalRow({required this.signal});

  @override
  Widget build(BuildContext context) {
    final color = _signalColor(signal.displaySeverity);
    final detail = signal.displayMessage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2), width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  signal.displayLabel,
                  style: AppTypography.inter(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (signal.displaySeverity != null)
                _SeverityPill(label: signal.displaySeverity!, color: color),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.inter(
                  size: 9,
                  height: 1.3,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  final String label;
  final Color color;

  const _SeverityPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.inter(
          size: 7,
          weight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final bool compact;

  const _MessageBody({
    required this.title,
    required this.message,
    required this.color,
    this.compact = false,
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
            size: compact ? 9 : 10,
            weight: FontWeight.w700,
            letterSpacing: compact ? 1.0 : 1.2,
            color: color,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          message,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.inter(
            size: compact ? 10 : 11,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

Color _signalColor(String? severity) {
  final normalized = severity?.trim().toLowerCase();
  return switch (normalized) {
    'critical' || 'error' || 'high' => AppColors.error,
    'warning' || 'warn' || 'medium' => AppColors.warning,
    'info' || 'low' => AppColors.neonCyan,
    _ => AppColors.textSecondary,
  };
}

String _humanizeStatus(String status) {
  final words = status.replaceAll('_', ' ').trim();
  if (words.isEmpty) return 'Status';
  return words
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
