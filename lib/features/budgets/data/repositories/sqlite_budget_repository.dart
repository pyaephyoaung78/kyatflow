import 'dart:async';

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../models/budget_progress_model.dart';

class SqliteBudgetRepository implements BudgetRepository {
  SqliteBudgetRepository(this._databaseHelper);

  final DatabaseHelper _databaseHelper;
  final StreamController<int> _changes = StreamController<int>.broadcast();
  int _revision = 0;
  bool _disposed = false;

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Future<int> insert(BudgetDraft budget) async {
    final id = await _databaseHelper.insertBudget(
      categoryId: budget.categoryId,
      amountLimit: budget.amountLimit,
      month: budget.month,
      year: budget.year,
      alertPercentage: budget.alertPercentage,
    );
    _publishChange();
    return id;
  }

  @override
  Future<void> edit(Budget budget) async {
    final affected = await _databaseHelper.updateBudget(
      id: budget.id,
      categoryId: budget.categoryId,
      amountLimit: budget.amountLimit,
      month: budget.month,
      year: budget.year,
      alertPercentage: budget.alertPercentage,
    );
    if (affected == 0) throw BudgetNotFoundException(budget.id);
    _publishChange();
  }

  @override
  Future<void> delete(int id) async {
    final affected = await _databaseHelper.deleteBudget(id);
    if (affected == 0) throw BudgetNotFoundException(id);
    _publishChange();
  }

  @override
  Future<List<BudgetProgress>> getMonthlyProgress(DateTime month) async {
    final rows = await _databaseHelper.getBudgetProgress(
      month: month.month,
      year: month.year,
    );
    return rows
        .map(BudgetProgressModel.fromMap)
        .map((model) => model.toEntity())
        .toList(growable: false);
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
