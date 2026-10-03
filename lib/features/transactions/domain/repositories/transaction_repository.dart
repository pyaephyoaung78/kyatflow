import '../entities/cash_flow_summary.dart';
import '../entities/category_spending.dart';
import '../entities/transaction_entry.dart';
import '../entities/transaction_category.dart';
import '../value_objects/transaction_date_filter.dart';

abstract interface class TransactionRepository {
  /// Emits a monotonically increasing revision after every successful write.
  Stream<int> get changes;

  Future<int> insert(TransactionDraft transaction);

  Future<void> edit(TransactionEntry transaction);

  Future<void> delete(int id);

  Future<List<TransactionEntry>> getTransactions({
    required TransactionDateFilter filter,
    required DateTime referenceDate,
  });

  Future<CashFlowSummary> getMonthlyCashFlow(DateTime activeMonth);

  Future<CashFlowSummary> getDashboardCashFlow(DateTime activeMonth);

  Future<List<TransactionEntry>> getRecentTransactions({int limit = 5});

  Future<List<TransactionEntry>> getLedgerTransactions({
    TransactionType? type,
    int? categoryId,
    required DateTime start,
    required DateTime end,
  });

  Future<List<TransactionCategory>> getCategories({
    bool includeArchived = false,
  });

  Future<int> addCategory(TransactionCategoryDraft category);

  Future<void> editCategory(TransactionCategory category);

  Future<void> setCategoryArchived(int id, {required bool archived});

  Future<void> deleteCategory(int id);

  Future<List<CategorySpending>> getExpenseBreakdown({
    required DateTime start,
    required DateTime end,
  });

  void dispose();
}

class CategoryNotFoundException implements Exception {
  const CategoryNotFoundException(this.id);
  final int id;
}

class CategoryInUseException implements Exception {
  const CategoryInUseException(this.id);
  final int id;
}

class TransactionNotFoundException implements Exception {
  const TransactionNotFoundException(this.id);

  final int id;

  @override
  String toString() =>
      'TransactionNotFoundException: transaction $id was not found';
}
