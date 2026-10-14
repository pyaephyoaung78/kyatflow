import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/database/database_helper.dart';
import 'package:kyatflow/features/recurring/data/repositories/sqlite_recurring_rule_repository.dart';
import 'package:kyatflow/features/recurring/domain/entities/recurring_rule.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_entry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late DatabaseHelper database;
  late SqliteRecurringRuleRepository repository;
  late int categoryId;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kyatflow_recurring_repository_',
    );
    database = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'test.db'),
    );
    repository = SqliteRecurringRuleRepository(database);
    final categories = await database.getCategories(type: 'expense');
    categoryId = categories.first['id'] as int;
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('creates, edits, pauses, and deletes a recurring rule', () async {
    final firstDue = DateTime(2026, 11, 1);
    final id = await repository.insert(
      RecurringRuleDraft(
        name: 'Home internet',
        amount: 30000,
        categoryId: categoryId,
        type: TransactionType.expense,
        frequency: RecurringFrequency.monthly,
        firstDue: firstDue,
        isActive: true,
        note: 'Fiber plan',
      ),
    );

    var rule = (await repository.getAll()).single;
    expect(rule.id, id);
    expect(rule.categoryName, isNotEmpty);
    expect(rule.nextDue, firstDue);
    expect(rule.isActive, isTrue);

    await repository.edit(
      RecurringRule(
        id: rule.id,
        name: 'Faster internet',
        amount: 35000,
        categoryId: rule.categoryId,
        type: rule.type,
        frequency: RecurringFrequency.monthly,
        firstDue: rule.firstDue,
        nextDue: rule.nextDue,
        lastExecuted: rule.lastExecuted,
        isActive: rule.isActive,
        note: 'New package',
      ),
    );
    await repository.setActive(id, active: false);

    rule = (await repository.getAll()).single;
    expect(rule.name, 'Faster internet');
    expect(rule.amount, 35000);
    expect(rule.note, 'New package');
    expect(rule.isActive, isFalse);

    await repository.delete(id);
    expect(await repository.getAll(), isEmpty);
  });
}
