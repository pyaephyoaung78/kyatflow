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

  Future<List<TransactionEntry>> getLedgerTransactions({TransactionType? type});

  Future<List<TransactionCategory>> getCategories();

  Future<List<CategorySpending>> getExpenseBreakdown({
    required DateTime start,
    required DateTime end,
  });

  void dispose();
}

class TransactionNotFoundException implements Exception {
  const TransactionNotFoundException(this.id);

  final int id;

  @override
  String toString() =>
      'TransactionNotFoundException: transaction $id was not found';
}
