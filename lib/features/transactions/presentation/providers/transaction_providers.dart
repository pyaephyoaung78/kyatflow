import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/backup/csv_backup_service.dart';
import '../../data/repositories/sqlite_transaction_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/entities/transaction_category.dart';
import '../state/transaction_notifier.dart';
import '../state/transaction_state.dart';
import '../state/dashboard_notifier.dart';
import '../state/dashboard_state.dart';
import '../state/analytics_notifier.dart';
import '../state/analytics_state.dart';
import '../state/ledger_notifier.dart';
import '../state/ledger_state.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final transactionRepositoryProvider =
    Provider.autoDispose<TransactionRepository>((ref) {
      final repository = SqliteTransactionRepository(
        ref.watch(databaseHelperProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

final transactionStateProvider =
    StateNotifierProvider.autoDispose<TransactionNotifier, TransactionState>((
      ref,
    ) {
      return TransactionNotifier(
        repository: ref.watch(transactionRepositoryProvider),
      );
    });

final managedCategoriesProvider = FutureProvider.autoDispose
    .family<List<TransactionCategory>, bool>((ref, includeArchived) {
      return ref
          .watch(transactionRepositoryProvider)
          .getCategories(includeArchived: includeArchived);
    });

final dashboardStateProvider =
    StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
      return DashboardNotifier(
        repository: ref.watch(transactionRepositoryProvider),
      );
    });

final ledgerStateProvider =
    StateNotifierProvider.autoDispose<LedgerNotifier, LedgerState>((ref) {
      return LedgerNotifier(ref.watch(transactionRepositoryProvider));
    });

final analyticsStateProvider =
    StateNotifierProvider.autoDispose<AnalyticsNotifier, AnalyticsState>((ref) {
      return AnalyticsNotifier(
        repository: ref.watch(transactionRepositoryProvider),
      );
    });

final csvBackupServiceProvider = Provider<CsvBackupService>((ref) {
  return CsvBackupService(databaseHelper: ref.watch(databaseHelperProvider));
});
