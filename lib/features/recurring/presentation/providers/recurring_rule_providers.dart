import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/repositories/sqlite_recurring_rule_repository.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/repositories/recurring_rule_repository.dart';

final recurringRuleRepositoryProvider =
    Provider.autoDispose<RecurringRuleRepository>((ref) {
      final repository = SqliteRecurringRuleRepository(
        ref.watch(databaseHelperProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

final _recurringRevisionProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(recurringRuleRepositoryProvider).changes;
});

final recurringRulesProvider = FutureProvider.autoDispose<List<RecurringRule>>((
  ref,
) {
  ref.watch(_recurringRevisionProvider);
  return ref.watch(recurringRuleRepositoryProvider).getAll();
});
