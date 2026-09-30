import '../entities/cash_flow_summary.dart';
import '../entities/transaction_entry.dart';
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

  void dispose();
}

class TransactionNotFoundException implements Exception {
  const TransactionNotFoundException(this.id);

  final int id;

  @override
  String toString() =>
      'TransactionNotFoundException: transaction $id was not found';
}
