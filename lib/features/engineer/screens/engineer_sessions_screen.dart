import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../core/storage/session_repository.dart';
import '../../../shared/format_utils.dart';
import '../../../shared/widgets/panel_card.dart';
import '../domain/session_summary.dart';
import '../providers/engineer_session_providers.dart';
import 'engineer_session_detail_screen.dart';

class EngineerSessionsScreen extends ConsumerStatefulWidget {
  const EngineerSessionsScreen({super.key});

  @override
  ConsumerState<EngineerSessionsScreen> createState() =>
      _EngineerSessionsScreenState();
}

class _EngineerSessionsScreenState
    extends ConsumerState<EngineerSessionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(engineerSessionsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<EngineerSessionListItem>> sessionsAsync = ref.watch(
      engineerSessionsProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.carbonBlack,
      appBar: AppBar(
        backgroundColor: AppColors.graphite,
        title: Text(
          'Engineer',
          style: AppTypography.orbitron(
            size: 18,
            weight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: sessionsAsync.when(
        data: (List<EngineerSessionListItem> sessions) {
          if (sessions.isEmpty) {
            return const _EngineerEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final EngineerSessionListItem session = sessions[index];
              return _SessionListTile(session: session);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.telemetryOrange),
        ),
        error: (Object error, StackTrace stackTrace) {
          return _EngineerFeedback(
            title: 'No pudimos cargar tus sesiones',
            detail:
                'Engineer V1 usa solo sesiones GT7 guardadas localmente. Error: $error',
            icon: Icons.storage_rounded,
          );
        },
      ),
    );
  }
}

class _SessionListTile extends ConsumerWidget {
  final EngineerSessionListItem session;

  const _SessionListTile({required this.session});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.graphite,
          title: Text(
            'Eliminar sesión',
            style: AppTypography.orbitron(
              size: 16,
              weight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            '¿Estás seguro de eliminar la sesión del ${formatDateTime(session.startTime)}?',
            style: AppTypography.inter(
              size: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancelar',
                style: AppTypography.inter(
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Eliminar',
                style: AppTypography.inter(
                  size: 14,
                  color: AppColors.error,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final SessionRepository repository = ref.read(sessionRepositoryProvider);
    await repository.deleteSession(session.sessionId);
    ref.invalidate(engineerSessionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    EngineerSessionDetailScreen(sessionId: session.sessionId),
            ),
          );
        },
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    formatDateTime(session.startTime),
                    style: AppTypography.orbitron(
                      size: 16,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${session.trackName ?? 'Pista desconocida'} · ${session.validLapCount} vueltas válidas',
                    style: AppTypography.inter(
                      size: 12,
                      color: AppColors.textPrimary,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      _SessionChip(
                        label: 'Best',
                        value: formatDuration(session.bestLap),
                      ),

                      _SessionChip(
                        label: 'Duration',
                        value: formatDuration(session.sessionDuration),
                      ),
                      _SessionChip(label: 'Source', value: session.game),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.neonCyan,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EngineerEmptyState extends StatelessWidget {
  const _EngineerEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _EngineerFeedback(
      title: 'Todavía no hay sesiones para revisar',
      detail: 'Engineer siempre está disponible, pero solo muestra sesiones GT7 con al menos una vuelta completa guardada.',
      icon: Icons.insights_rounded,
    );
  }
}

class _EngineerFeedback extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;

  const _EngineerFeedback({
    required this.title,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: PanelCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 42, color: AppColors.neonCyan),
              const SizedBox(height: 16),
              Text(
                title,
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
                  size: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  final String label;
  final String value;

  const _SessionChip({required this.label, required this.value});

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
              color: AppColors.textSecondary,
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
