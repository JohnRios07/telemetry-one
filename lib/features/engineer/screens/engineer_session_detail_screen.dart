import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../shared/format_utils.dart';
import '../../../shared/widgets/panel_card.dart';
import '../domain/coach_report.dart';
import '../domain/lap_comparison.dart';
import '../domain/session_summary.dart';
import '../providers/engineer_session_providers.dart';

class EngineerSessionDetailScreen extends ConsumerWidget {
  final String sessionId;

  const EngineerSessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SessionSummary?> summaryAsync = ref.watch(
      engineerSessionSummaryProvider(sessionId),
    );
    final AsyncValue<LapComparisonResult> comparisonAsync = ref.watch(
      engineerLapComparisonProvider(sessionId),
    );
    final AsyncValue<List<EngineerRecommendation>> recommendationsAsync = ref
        .watch(engineerRecommendationsProvider(sessionId));
    final AsyncValue<CoachReport?> coachReportAsync = ref.watch(
      engineerCoachReportProvider(sessionId),
    );

    return Scaffold(
      backgroundColor: AppColors.carbonBlack,
      appBar: AppBar(
        backgroundColor: AppColors.graphite,
        title: Text(
          'Engineer · Session detail',
          style: AppTypography.orbitron(
            size: 16,
            weight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: summaryAsync.when(
        data: (SessionSummary? summary) {
          if (summary == null) {
            return const _MissingSessionState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SessionHeader(summary: summary),
                const SizedBox(height: 16),
                _SummaryCards(summary: summary),
                const SizedBox(height: 16),
                _ComparisonSection(comparisonAsync: comparisonAsync),
                const SizedBox(height: 16),
                _RecommendationsSection(
                  recommendationsAsync: recommendationsAsync,
                ),
                const SizedBox(height: 16),
                _CoachSection(coachReportAsync: coachReportAsync),
                const SizedBox(height: 16),
                _LapListSection(summary: summary),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.telemetryOrange),
        ),
        error: (Object error, StackTrace stackTrace) {
          return _SectionMessage(
            title: 'No pudimos abrir esta sesión',
            detail: '$error',
            icon: Icons.error_outline_rounded,
          );
        },
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  final SessionSummary summary;

  const _SessionHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            formatDateTime(summary.startTime),
            style: AppTypography.orbitron(
              size: 18,
              weight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'GT7 local · ${summary.validLapCount} vueltas válidas · ${summary.disclaimer}',
            style: AppTypography.inter(
              size: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final SessionSummary summary;

  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      _MetricCard(
        title: 'Best lap',
        value: formatDuration(summary.bestLap.value),
        detail: _metricDetail(summary.bestLap),
        unavailable: !summary.bestLap.isAvailable,
      ),
      _MetricCard(
        title: 'Avg lap',
        value: formatDuration(summary.averageLap.value),
        detail: _metricDetail(summary.averageLap),
        unavailable: !summary.averageLap.isAvailable,
      ),
      _MetricCard(
        title: 'Total laps',
        value: summary.totalLaps.value?.toString() ?? 'N/D',
        detail: _metricDetail(summary.totalLaps),
        unavailable: !summary.totalLaps.isAvailable,
      ),
      _MetricCard(
        title: 'Fuel / lap',
        value: summary.fuelPerLap.value != null
            ? '${summary.fuelPerLap.value!.toStringAsFixed(2)} L'
            : 'N/D',
        detail: _metricDetail(summary.fuelPerLap),
        unavailable: !summary.fuelPerLap.isAvailable,
      ),
      _MetricCard(
        title: 'Consistency',
        value: summary.consistency.value != null
            ? '${summary.consistency.value!.toStringAsFixed(1)}%'
            : 'N/D',
        detail: _metricDetail(summary.consistency),
        unavailable: !summary.consistency.isAvailable,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map((Widget card) {
            return SizedBox(width: 220, child: card);
          })
          .toList(growable: false),
    );
  }

  String _metricDetail<T>(SummaryMetric<T> metric) {
    if (!metric.isAvailable) {
      return metric.unavailableReason ?? 'No disponible';
    }

    if (metric.note != null) {
      return metric.note!;
    }

    return metric.isBasic
        ? 'Métrica básica V1.'
        : 'Dato guardado o derivado directo.';
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final bool unavailable;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.unavailable,
  });

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: AppTypography.inter(
              size: 10,
              color: AppColors.textPrimary,
              weight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.orbitron(
              size: 24,
              weight: FontWeight.w700,
              color: unavailable
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: AppTypography.inter(
              size: 11,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  final AsyncValue<LapComparisonResult> comparisonAsync;

  const _ComparisonSection({required this.comparisonAsync});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: comparisonAsync.when(
        data: (LapComparisonResult comparison) {
          if (!comparison.isAvailable || comparison.summary == null) {
            return _SectionBody(
              title: 'Best vs last',
              subtitle:
                  comparison.unavailableReason ?? 'Comparación no disponible.',
              child: const SizedBox.shrink(),
            );
          }

          final LapComparisonSummary summary = comparison.summary!;
          final List<LapComparisonPoint> highlightPoints =
              _selectHighlightPoints(comparison.points);

          return _SectionBody(
            title: comparison.label,
            subtitle:
                '${comparison.detail} Cobertura ${(comparison.coverageRatio * 100).toStringAsFixed(0)}%.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _ComparisonChip(
                      label: 'Lap delta',
                      value: formatSignedDuration(summary.lapTimeDelta),
                    ),
                    _ComparisonChip(
                      label: 'Last vs Best speed',
                      value:
                          '${summary.averageSpeedDeltaKmh.toStringAsFixed(1)} km/h',
                    ),
                    _ComparisonChip(
                      label: 'Avg throttle Δ',
                      value:
                          '${(summary.averageThrottleDelta * 100).toStringAsFixed(0)}%',
                    ),
                    _ComparisonChip(
                      label: 'Avg brake Δ',
                      value:
                          '${(summary.averageBrakeDelta * 100).toStringAsFixed(0)}%',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Muestras básicas por progreso',
                  style: AppTypography.inter(
                    size: 12,
                    color: AppColors.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: highlightPoints
                      .map((LapComparisonPoint point) {
                        return _ProgressDeltaCard(point: point);
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          );
        },
        loading: () => const _SectionBody(
          title: 'Best vs last',
          subtitle: 'Calculando comparación local…',
          child: SizedBox.shrink(),
        ),
        error: (Object error, StackTrace stackTrace) {
          return _SectionBody(
            title: 'Best vs last',
            subtitle: 'No se pudo calcular la comparación: $error',
            child: const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

class _ComparisonChip extends StatelessWidget {
  final String label;
  final String value;

  const _ComparisonChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTypography.inter(
              size: 10,
              color: AppColors.neonCyan,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.orbitron(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDeltaCard extends StatelessWidget {
  final LapComparisonPoint point;

  const _ProgressDeltaCard({required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'P${(point.progress * 100).round()}%',
            style: AppTypography.orbitron(
              size: 15,
              weight: FontWeight.w700,
              color: AppColors.neonCyan,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Δ vel ${point.speedDeltaKmh.toStringAsFixed(1)}',
            style: AppTypography.inter(
              size: 11,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'Δ gas ${(point.throttleDelta * 100).toStringAsFixed(0)}%',
            style: AppTypography.inter(
              size: 11,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'Δ brake ${(point.brakeDelta * 100).toStringAsFixed(0)}%',
            style: AppTypography.inter(
              size: 11,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'Δ time ${formatSignedDuration(point.timeDelta)}',
            style: AppTypography.inter(
              size: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationsSection extends StatelessWidget {
  final AsyncValue<List<EngineerRecommendation>> recommendationsAsync;

  const _RecommendationsSection({required this.recommendationsAsync});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: recommendationsAsync.when(
        data: (List<EngineerRecommendation> recommendations) {
          if (recommendations.isEmpty) {
            return const _SectionBody(
              title: 'Recommendations',
              subtitle: 'No hay señales fuertes para recomendaciones básicas. Mejor eso que inventar coaching.',
              child: SizedBox.shrink(),
            );
          }

          return _SectionBody(
            title: 'Recommendations',
            subtitle: 'Heurísticas locales, descriptivas y de baja confianza. Sin IA y sin backend.',
            child: Column(
              children: recommendations
                  .map((EngineerRecommendation recommendation) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecommendationTile(
                        recommendation: recommendation,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          );
        },
        loading: () => const _SectionBody(
          title: 'Recommendations',
          subtitle: 'Revisando señales confiables…',
          child: SizedBox.shrink(),
        ),
        error: (Object error, StackTrace stackTrace) {
          return _SectionBody(
            title: 'Recommendations',
            subtitle: 'No se pudieron derivar recomendaciones: $error',
            child: const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final EngineerRecommendation recommendation;

  const _RecommendationTile({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            recommendation.title,
            style: AppTypography.orbitron(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recommendation.detail,
            style: AppTypography.inter(
              size: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${recommendation.signalLabel} · ${recommendation.disclaimer}',
            style: AppTypography.inter(
              size: 11,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LapListSection extends StatelessWidget {
  final SessionSummary summary;

  const _LapListSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: _SectionBody(
        title: 'Lap list',
        subtitle: 'Vueltas completas guardadas para esta sesión.',
        child: Column(
          children: summary.lapRows
              .map((LapSummaryRow row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LapRow(row: row),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _CoachSection extends StatelessWidget {
  final AsyncValue<CoachReport?> coachReportAsync;

  const _CoachSection({required this.coachReportAsync});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: coachReportAsync.when(
        data: (CoachReport? report) {
          if (report == null) {
            return const _SectionBody(
              title: 'Coach V1',
              subtitle: 'No pudimos abrir el coaching local de esta sesión.',
              child: SizedBox.shrink(),
            );
          }

          return _SectionBody(
            title: 'Coach V1',
            subtitle: report.disclaimer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CoachScoreCard(score: report.driverScore),
                const SizedBox(height: 14),
                _WeakSegmentsCard(analysis: report.weakSegments),
              ],
            ),
          );
        },
        loading: () => const _SectionBody(
          title: 'Coach V1',
          subtitle: 'Armando coaching local con heurísticas de sesión…',
          child: SizedBox.shrink(),
        ),
        error: (Object error, StackTrace stackTrace) {
          return _SectionBody(
            title: 'Coach V1',
            subtitle: 'No se pudo calcular el coaching local: $error',
            child: const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

class _CoachScoreCard extends StatelessWidget {
  final DriverScoreResult score;

  const _CoachScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SESSION SCORE',
            style: AppTypography.inter(
              size: 10,
              color: AppColors.neonCyan,
              weight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            score.isAvailable ? '${score.overallScore}' : 'N/D',
            style: AppTypography.orbitron(
              size: 32,
              weight: FontWeight.w700,
              color: score.isAvailable
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score.isAvailable
                ? score.explanation
                : (score.unavailableReason ?? 'Score no disponible.'),
            style: AppTypography.inter(
              size: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _ComparisonChip(
                label: 'Pace',
                value: score.isAvailable ? '${score.paceScore}' : 'N/D',
              ),
              _ComparisonChip(
                label: 'Consistency',
                value: score.isAvailable ? '${score.consistencyScore}' : 'N/D',
              ),
              _ComparisonChip(
                label: 'Control',
                value: score.isAvailable ? '${score.controlScore}' : 'N/D',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeakSegmentsCard extends StatelessWidget {
  final WeakSegmentAnalysis analysis;

  const _WeakSegmentsCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (!analysis.isAvailable || analysis.segments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          analysis.unavailableReason ??
              'No hay suficientes vueltas comparables para cerrar coaching local.',
          style: AppTypography.inter(
            size: 12,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Weak segments',
          style: AppTypography.inter(
            size: 12,
            color: AppColors.textPrimary,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...analysis.segments.map((WeakSegmentInsight segment) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WeakSegmentTile(segment: segment),
          );
        }),
      ],
    );
  }
}

class _WeakSegmentTile extends StatelessWidget {
  final WeakSegmentInsight segment;

  const _WeakSegmentTile({required this.segment});

  @override
  Widget build(BuildContext context) {
    final List<String> secondarySignals = <String>[];
    if (segment.medianApexSpeedLossKmh >= 1) {
      secondarySignals.add(
        'Apex -${segment.medianApexSpeedLossKmh.toStringAsFixed(1)} km/h',
      );
    }
    if (segment.medianThrottlePickupDelay != null) {
      secondarySignals.add(
        'Gas ${formatSignedDuration(segment.medianThrottlePickupDelay!)}',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  segment.label,
                  style: AppTypography.orbitron(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                formatSignedDuration(segment.medianTimeLoss),
                style: AppTypography.orbitron(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.telemetryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            segment.coachingCue,
            style: AppTypography.inter(
              size: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (secondarySignals.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              secondarySignals.join(' · '),
              style: AppTypography.inter(
                size: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LapRow extends StatelessWidget {
  final LapSummaryRow row;

  const _LapRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final List<String> badges = <String>[];
    if (row.isBestLap) {
      badges.add('BEST');
    }
    if (row.isLastLap) {
      badges.add('LAST');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 25,
            child: Text(
              'Lap ${row.lapNumber}',
              style: AppTypography.orbitron(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 25,
            child: Text(
              formatDuration(row.lapTime),
              style: AppTypography.orbitron(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 30,
            child: Text(
              row.fuelUsedLiters != null
                  ? '${row.fuelUsedLiters!.toStringAsFixed(2)} L usados'
                  : 'Fuel N/D',
              style: AppTypography.inter(
                size: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 20,
            child: Wrap(
              spacing: 6,
              children: badges
                  .map((String badge) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.graphite,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: AppTypography.inter(
                          size: 10,
                          color: AppColors.neonCyan,
                          weight: FontWeight.w600,
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionBody({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTypography.orbitron(
            size: 16,
            weight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppTypography.inter(
            size: 12,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        if (child is! SizedBox) const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _SectionMessage extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;

  const _SectionMessage({
    required this.title,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PanelCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: AppColors.neonCyan),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.orbitron(
                size: 18,
                weight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                size: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingSessionState extends StatelessWidget {
  const _MissingSessionState();

  @override
  Widget build(BuildContext context) {
    return const _SectionMessage(
      title: 'Sesión no encontrada',
      detail: 'Esta sesión ya no existe en el almacenamiento local.',
      icon: Icons.folder_off_rounded,
    );
  }
}

List<LapComparisonPoint> _selectHighlightPoints(
  List<LapComparisonPoint> points,
) {
  if (points.length <= 5) {
    return points;
  }

  final List<LapComparisonPoint> highlights = <LapComparisonPoint>[];
  for (int index = 0; index < 5; index += 1) {
    final int pointIndex = ((points.length - 1) * (index / 4)).round();
    highlights.add(points[pointIndex]);
  }

  return highlights;
}
