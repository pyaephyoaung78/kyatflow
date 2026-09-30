import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/database/database_helper.dart';
import '../../data/repositories/sqlite_transaction_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../state/transaction_notifier.dart';
import '../state/transaction_state.dart';

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
