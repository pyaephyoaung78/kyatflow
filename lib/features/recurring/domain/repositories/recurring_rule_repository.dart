import '../entities/recurring_rule.dart';

abstract interface class RecurringRuleRepository {
  Stream<int> get changes;

  Future<List<RecurringRule>> getAll();

  Future<int> insert(RecurringRuleDraft rule);

  Future<void> edit(RecurringRule rule);

  Future<void> setActive(int id, {required bool active});

  Future<void> delete(int id);

  void dispose();
}

class RecurringRuleNotFoundException implements Exception {
  const RecurringRuleNotFoundException(this.id);

  final int id;
}
