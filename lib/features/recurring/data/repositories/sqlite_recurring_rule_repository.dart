import 'dart:async';

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/repositories/recurring_rule_repository.dart';
import '../models/recurring_rule_model.dart';

class SqliteRecurringRuleRepository implements RecurringRuleRepository {
  SqliteRecurringRuleRepository(this._databaseHelper);

  final DatabaseHelper _databaseHelper;
  final _changes = StreamController<int>.broadcast(sync: true);
  var _revision = 0;
  var _disposed = false;

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Future<List<RecurringRule>> getAll() async {
    final rows = await _databaseHelper.getRecurringRuleDetails();
    return rows
        .map(RecurringRuleModel.fromMap)
        .map((model) => model.toEntity())
        .toList(growable: false);
  }

  @override
  Future<int> insert(RecurringRuleDraft rule) async {
    final id = await _databaseHelper.insertRecurringRule(
      name: rule.name,
      amount: rule.amount,
      categoryId: rule.categoryId,
      type: rule.type.databaseValue,
      frequency: rule.frequency.name,
      firstDue: rule.firstDue,
      nextDue: rule.firstDue,
      isActive: rule.isActive,
      note: rule.note,
    );
    _publish();
    return id;
  }

  @override
  Future<void> edit(RecurringRule rule) async {
    final affected = await _databaseHelper.updateRecurringRule(
      id: rule.id,
      name: rule.name,
      amount: rule.amount,
      categoryId: rule.categoryId,
      type: rule.type.databaseValue,
      frequency: rule.frequency.name,
      firstDue: rule.firstDue,
      nextDue: rule.nextDue,
      lastExecuted: rule.lastExecuted,
      isActive: rule.isActive,
      note: rule.note,
    );
    if (affected == 0) throw RecurringRuleNotFoundException(rule.id);
    _publish();
  }

  @override
  Future<void> setActive(int id, {required bool active}) async {
    final affected = await _databaseHelper.setRecurringRuleActive(
      id,
      active: active,
    );
    if (affected == 0) throw RecurringRuleNotFoundException(id);
    _publish();
  }

  @override
  Future<void> delete(int id) async {
    final affected = await _databaseHelper.deleteRecurringRule(id);
    if (affected == 0) throw RecurringRuleNotFoundException(id);
    _publish();
  }

  void _publish() {
    if (!_disposed) _changes.add(++_revision);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_changes.close());
  }
}
