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

class BudgetAlreadyExistsException implements Exception {
  const BudgetAlreadyExistsException({
    required this.categoryId,
    required this.month,
    required this.year,
  });

  final int categoryId;
  final int month;
  final int year;

  @override
  String toString() =>
      'A budget already exists for category $categoryId in $month/$year.';
}
