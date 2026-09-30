import 'dart:async';

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/cash_flow_summary.dart';
import '../../domain/entities/transaction_entry.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/value_objects/transaction_date_filter.dart';
import '../models/cash_flow_summary_model.dart';
import '../models/transaction_model.dart';

class SqliteTransactionRepository implements TransactionRepository {
  SqliteTransactionRepository(this._databaseHelper);

  final DatabaseHelper _databaseHelper;
  final StreamController<int> _changes = StreamController<int>.broadcast(
    sync: true,
  );
  int _revision = 0;
  bool _disposed = false;

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Future<int> insert(TransactionDraft transaction) async {
    final id = await _databaseHelper.insertTransaction(
      amount: transaction.amount,
      type: transaction.type.databaseValue,
      categoryId: transaction.categoryId,
      timestamp: transaction.timestamp,
      note: transaction.note,
    );
    _publishChange();
    return id;
  }

  @override
  Future<void> edit(TransactionEntry transaction) async {
    final affected = await _databaseHelper.updateTransaction(
      id: transaction.id,
      amount: transaction.amount,
      type: transaction.type.databaseValue,
      categoryId: transaction.categoryId,
      timestamp: transaction.timestamp,
      note: transaction.note,
    );
    if (affected == 0) throw TransactionNotFoundException(transaction.id);
    _publishChange();
  }

  @override
  Future<void> delete(int id) async {
    final affected = await _databaseHelper.deleteTransaction(id);
    if (affected == 0) throw TransactionNotFoundException(id);
    _publishChange();
  }

  @override
  Future<List<TransactionEntry>> getTransactions({
    required TransactionDateFilter filter,
    required DateTime referenceDate,
  }) async {
    final range = filter.rangeFor(referenceDate);
    final rows = await _databaseHelper.getTransactions(
      start: range.start,
      end: range.end,
    );
    return rows
        .map(TransactionModel.fromMap)
        .map((model) => model.toEntity())
        .toList(growable: false);
  }

  @override
  Future<CashFlowSummary> getMonthlyCashFlow(DateTime activeMonth) async {
    final range = monthRangeFor(activeMonth);
    final row = await _databaseHelper.getCashFlowSummary(
      start: range.start,
      end: range.end,
    );
    return CashFlowSummaryModel.fromMap(row).toEntity();
  }

  void _publishChange() {
    if (!_disposed) _changes.add(++_revision);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_changes.close());
  }
}
