import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/database/database_helper.dart';
import 'package:kyatflow/features/recurring/data/services/recurring_transaction_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late DatabaseHelper database;
  late int expenseCategoryId;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kyatflow_recurring_');
    database = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'test.db'),
    );
    final categories = await database.getCategories(type: 'expense');
    expenseCategoryId = categories.first['id'] as int;
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('a new rule runs once and repeated startup is idempotent', () async {
    final now = DateTime.utc(2026, 10, 1, 8, 30);
    await database.insertRecurringRule(
      name: 'Music subscription',
      amount: 12000,
      categoryId: expenseCategoryId,
      type: 'expense',
      frequency: 'monthly',
    );
    final service = RecurringTransactionService(
      databaseHelper: database,
      clock: () => now,
    );

    final first = await service.executeDueTransactions();
    final second = await service.executeDueTransactions();

    expect(first.rulesExecuted, 1);
    expect(first.transactionsCreated, 1);
    expect(second.rulesExecuted, 0);
    expect(second.transactionsCreated, 0);
    final transaction = (await database.getTransactions()).single;
    expect(transaction['amount'], 12000.0);
    expect(transaction['timestamp'], now.millisecondsSinceEpoch);
    expect(transaction['note'], 'Recurring: Music subscription');
    expect(
      (await database.getRecurringRules()).single['last_executed'],
      now.millisecondsSinceEpoch,
    );
  });

  test('monthly rule catches up each missed occurrence', () async {
    await database.insertRecurringRule(
      name: 'Home internet',
      amount: 45000,
      categoryId: expenseCategoryId,
      type: 'expense',
      frequency: 'monthly',
      lastExecuted: DateTime.utc(2026, 7, 31, 9),
    );
    final result = await RecurringTransactionService(
      databaseHelper: database,
      clock: () => DateTime.utc(2026, 10, 1, 12),
    ).executeDueTransactions();

    expect(result.rulesExecuted, 1);
    expect(result.transactionsCreated, 2);
    final transactions = await database.getTransactions();
    expect(transactions.map((row) => row['timestamp']), [
      DateTime.utc(2026, 9, 30).millisecondsSinceEpoch,
      DateTime.utc(2026, 8, 31).millisecondsSinceEpoch,
    ]);
    expect(
      (await database.getRecurringRules()).single['last_executed'],
      DateTime.utc(2026, 9, 30).millisecondsSinceEpoch,
    );
  });
}
