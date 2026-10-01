import '../entities/budget.dart';

abstract interface class BudgetRepository {
  Stream<int> get changes;

  Future<int> insert(BudgetDraft budget);

  Future<void> edit(Budget budget);

  Future<void> delete(int id);

  Future<List<BudgetProgress>> getMonthlyProgress(DateTime month);

  void dispose();
}

class BudgetNotFoundException implements Exception {
  const BudgetNotFoundException(this.id);

  final int id;

  @override
  String toString() => 'Budget $id was not found.';
}
