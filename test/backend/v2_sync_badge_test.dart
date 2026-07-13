import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/config/theme/app_colors.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/features/dashboard/widgets/v2_sync_badge.dart';

/// Mock notifier that holds a fixed state for testing display.
class _MockSyncNotifier extends BackendSyncNotifier {
  _MockSyncNotifier(BackendSyncState state) : super(config: const BackendConfig()) {
    this.state = state;
  }

  @override
  void dispose() {
    // Avoid state_notifier debug assertion during test teardown.
    // The parent dispose() calls _subscription?.cancel() / _client.dispose()
    // which reference uninitialized fields in tests.
  }
}

void main() {
  group('syncStatusLabel', () {
    test('disabled -> OFF', () {
      expect(syncStatusLabel(SyncStatus.disabled), 'OFF');
    });
    test('idle -> IDLE', () {
      expect(syncStatusLabel(SyncStatus.idle), 'IDLE');
    });
    test('syncing -> SYNC', () {
      expect(syncStatusLabel(SyncStatus.syncing), 'SYNC');
    });
    test('degraded -> DOWN', () {
      expect(syncStatusLabel(SyncStatus.degraded), 'DOWN');
    });
    test('rejected -> REJ', () {
      expect(syncStatusLabel(SyncStatus.rejected), 'REJ');
    });
    test('failed -> FAIL', () {
      expect(syncStatusLabel(SyncStatus.failed), 'FAIL');
    });
  });

  group('syncStatusColor', () {
    test('disabled is textDim', () {
      expect(syncStatusColor(SyncStatus.disabled), AppColors.textDim);
    });
    test('idle is success green', () {
      expect(syncStatusColor(SyncStatus.idle), AppColors.success);
    });
    test('syncing is neonCyan', () {
      expect(syncStatusColor(SyncStatus.syncing), AppColors.neonCyan);
    });
    test('degraded is warning amber', () {
      expect(syncStatusColor(SyncStatus.degraded), AppColors.warning);
    });
    test('rejected is error red', () {
      expect(syncStatusColor(SyncStatus.rejected), AppColors.error);
    });
    test('failed is error red', () {
      expect(syncStatusColor(SyncStatus.failed), AppColors.error);
    });
  });

  group('V2SyncBadge visibility', () {
    testWidgets('hidden when useV2Data is false (default)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendConfigProvider.overrideWithValue(const BackendConfig()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: V2SyncBadge()),
          ),
        ),
      );

      expect(find.byType(V2SyncBadge), findsOneWidget);
      expect(find.text('OFF'), findsNothing);
    });

    testWidgets('visible when useV2Data is true', (tester) async {
      final defaultState = BackendSyncState(
        sessionId: 'local_test',
        status: SyncStatus.disabled,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendConfigProvider.overrideWithValue(
              const BackendConfig(useV2Data: true),
            ),
            backendSyncProvider.overrideWith(
              (ref) => _MockSyncNotifier(defaultState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: V2SyncBadge()),
          ),
        ),
      );

      expect(find.text('OFF'), findsOneWidget);
    });
  });

  group('V2SyncBadge status display', () {
    testWidgets('shows IDLE and counters when enabled', (tester) async {
      final syncState = BackendSyncState(
        sessionId: 'local_test_123',
        status: SyncStatus.idle,
        totalSent: 5,
        totalAccepted: 5,
        totalRejected: 0,
        pendingFrames: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendConfigProvider.overrideWithValue(
              const BackendConfig(useV2Data: true),
            ),
            backendSyncProvider.overrideWith(
              (ref) => _MockSyncNotifier(syncState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: V2SyncBadge()),
          ),
        ),
      );

      expect(find.text('IDLE'), findsOneWidget);
      expect(find.textContaining('local_test'), findsOneWidget);
      expect(find.textContaining('P:0'), findsOneWidget);
      expect(find.textContaining('S:5'), findsOneWidget);
      expect(find.textContaining('A:5'), findsOneWidget);
      expect(find.textContaining('R:0'), findsOneWidget);
    });

    testWidgets('shows SYNC when syncing', (tester) async {
      final syncState = BackendSyncState(
        sessionId: 'local_test_456',
        status: SyncStatus.syncing,
        pendingFrames: 10,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendConfigProvider.overrideWithValue(
              const BackendConfig(useV2Data: true),
            ),
            backendSyncProvider.overrideWith(
              (ref) => _MockSyncNotifier(syncState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: V2SyncBadge()),
          ),
        ),
      );

      expect(find.text('SYNC'), findsOneWidget);
    });

    testWidgets('shows backend session ID when aligned', (tester) async {
      final syncState = BackendSyncState(
        sessionId: 'local_ignore',
        status: SyncStatus.idle,
        backendSessionId: 'session_abc123',
        alignmentStatus: SessionAlignmentStatus.created,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendConfigProvider.overrideWithValue(
              const BackendConfig(useV2Data: true),
            ),
            backendSyncProvider.overrideWith(
              (ref) => _MockSyncNotifier(syncState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: V2SyncBadge()),
          ),
        ),
      );

      expect(
        find.text('session_abc123'),
        findsOneWidget,
        reason: 'badge shows backend session ID when alignment succeeded',
      );
      expect(
        find.textContaining('local_ignore'),
        findsNothing,
        reason: 'badge hides local session ID when backend session exists',
      );
    });

    testWidgets('hides counters and session ID when disabled',
        (tester) async {
      final disabledState = BackendSyncState(
        sessionId: 'local_test',
        status: SyncStatus.disabled,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendConfigProvider.overrideWithValue(
              const BackendConfig(useV2Data: true),
            ),
            backendSyncProvider.overrideWith(
              (ref) => _MockSyncNotifier(disabledState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: V2SyncBadge()),
          ),
        ),
      );

      expect(find.text('OFF'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
      expect(find.textContaining('P:'), findsNothing);
      expect(find.textContaining('S:'), findsNothing);
    });
  });
}
