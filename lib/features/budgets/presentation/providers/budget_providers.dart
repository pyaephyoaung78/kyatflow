import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/repositories/sqlite_budget_repository.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';

final budgetRepositoryProvider = Provider.autoDispose<BudgetRepository>((ref) {
  final repository = SqliteBudgetRepository(ref.watch(databaseHelperProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final _budgetRevisionProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(budgetRepositoryProvider).changes;
});

final _transactionRevisionProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(transactionRepositoryProvider).changes;
});

final monthlyBudgetProgressProvider = FutureProvider.autoDispose
    .family<List<BudgetProgress>, DateTime>((ref, activeMonth) async {
      ref.watch(_budgetRevisionProvider);
      ref.watch(_transactionRevisionProvider);
      return ref
          .watch(budgetRepositoryProvider)
          .getMonthlyProgress(activeMonth);
    });
