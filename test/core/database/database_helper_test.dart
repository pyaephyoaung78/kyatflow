import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late DatabaseHelper helper;
  final date = DateTime.utc(2026, 9, 15);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kyatflow_test_');
    helper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await helper.close();
    await directory.delete(recursive: true);
  });

  Future<int> category({String name = 'Food', String type = 'expense'}) {
    return helper.insertCategory(
      name: name,
      icon: 'restaurant',
      color: 0xFF008000,
      type: type,
    );
  }

  Future<int> transaction(
    int categoryId, {
    DateTime? time,
    String type = 'expense',
  }) {
    return helper.insertTransaction(
      amount: 2500.5,
      type: type,
      categoryId: categoryId,
      timestamp: time ?? date,
      note: "Lunch at Moe's",
    );
  }

  test(
    'concurrent initialization shares a connection and enables foreign keys',
    () async {
      final connections = await Future.wait(
        List.generate(5, (_) => helper.database),
      );
      expect(
        connections.every((db) => identical(db, connections.first)),
        isTrue,
      );
      expect(await connections.first.getVersion(), 4);
      expect(
        (await connections.first.rawQuery(
          'PRAGMA foreign_keys',
        )).single.values.single,
        1,
      );
    },
  );

  test('category CRUD preserves quoted text and filters by type', () async {
    final id = await category(name: "  Moe's food  ");
    await category(name: 'Salary', type: 'income');
    expect((await helper.getCategory(id))!['name'], "Moe's food");
    expect(
      (await helper.getCategories(type: 'expense')).map((row) => row['id']),
      contains(id),
    );
    expect(
      await helper.updateCategory(
        id: id,
        name: 'Meals',
        icon: 'food',
        color: 0xFF000000,
        type: 'expense',
      ),
      1,
    );
    expect((await helper.getCategory(id))!['name'], 'Meals');
    expect(await helper.setCategoryArchived(id, archived: true), 1);
    expect(
      (await helper.getCategories(type: 'expense')).map((row) => row['id']),
      isNot(contains(id)),
    );
    expect(
      (await helper.getCategories(
        type: 'expense',
        includeArchived: true,
      )).map((row) => row['id']),
      contains(id),
    );
    expect(await helper.setCategoryArchived(id, archived: false), 1);
    expect(await helper.deleteCategory(id), 1);
    expect(await helper.getCategory(id), isNull);
    expect(await helper.deleteCategory(id), 0);
  });

  test(
    'transaction CRUD persists amount, timestamp, and nullable note',
    () async {
      final categoryId = await category();
      final id = await transaction(categoryId);
      final row = (await helper.getTransaction(id))!;
      expect(row['amount'], 2500.5);
      expect(row['timestamp'], date.millisecondsSinceEpoch);
      expect(row['note'], "Lunch at Moe's");
      expect(
        await helper.updateTransaction(
          id: id,
          amount: 3000,
          type: 'expense',
          categoryId: categoryId,
          timestamp: date,
        ),
        1,
      );
      expect((await helper.getTransaction(id))!['note'], isNull);
      expect((await helper.getTransaction(id))!['amount'], 3000.0);
      expect(await helper.deleteTransaction(id), 1);
      expect(await helper.getTransaction(id), isNull);
      expect(await helper.deleteTransaction(id), 0);
    },
  );

  test('filters use exclusive end dates and stable pagination', () async {
    final food = await category();
    final salary = await category(name: 'Salary', type: 'income');
    final start = DateTime.utc(2026, 9);
    final end = DateTime.utc(2026, 10);
    await transaction(
      food,
      time: start.subtract(const Duration(milliseconds: 1)),
    );
    final first = await transaction(food, time: start);
    final second = await transaction(food);
    final third = await transaction(food);
    await transaction(food, time: end);
    await transaction(salary, type: 'income');
    final rows = await helper.getTransactions(
      type: 'expense',
      categoryId: food,
      start: start,
      end: end,
    );
    expect(rows.map((row) => row['id']), [third, second, first]);
    expect(
      (await helper.getTransactions(
        categoryId: food,
        start: start,
        end: end,
        limit: 1,
        offset: 1,
      )).single['id'],
      second,
    );
    expect(
      (await helper.getTransactions(
        categoryId: food,
        start: start,
        end: end,
        offset: 1,
      )).map((row) => row['id']),
      [second, first],
    );
  });

  test('foreign keys protect history and category type consistency', () async {
    final food = await category();
    await transaction(food);
    await expectLater(
      helper.deleteCategory(food),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(transaction(999), throwsA(isA<DatabaseException>()));
    await expectLater(
      transaction(food, type: 'income'),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      helper.updateCategory(
        id: food,
        name: 'Food',
        icon: 'food',
        color: 0,
        type: 'income',
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect((await helper.getTransactions()).length, 1);
  });

  test(
    'rejects invalid amounts, types, categories, and query bounds',
    () async {
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          helper.insertTransaction(
            amount: amount,
            type: 'expense',
            categoryId: 1,
            timestamp: date,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(category(name: ' '), throwsArgumentError);
      await expectLater(category(type: 'invalid'), throwsArgumentError);
      await expectLater(helper.getTransactions(limit: 0), throwsArgumentError);
      await expectLater(
        helper.getTransactions(offset: -1),
        throwsArgumentError,
      );
      await expectLater(
        helper.getTransactions(start: date, end: date),
        throwsArgumentError,
      );
      final db = await helper.database;
      await expectLater(
        db.insert('categories', {
          'name': 'Broken',
          'icon': 'food',
          'color': 0,
          'type': 'invalid',
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test('closing and reopening preserves saved data', () async {
    final id = await transaction(await category());
    await helper.close();
    await helper.close();
    await helper.initialize();
    expect((await helper.getTransaction(id))!['amount'], 2500.5);
  });

  test('cash-flow aggregation is calculated natively for one range', () async {
    final expenseCategory = await category();
    final incomeCategory = await category(name: 'Salary', type: 'income');
    final monthStart = DateTime.utc(2026, 9);
    final monthEnd = DateTime.utc(2026, 10);
    await helper.insertTransaction(
      amount: 100000,
      type: 'income',
      categoryId: incomeCategory,
      timestamp: date,
    );
    await helper.insertTransaction(
      amount: 35000,
      type: 'expense',
      categoryId: expenseCategory,
      timestamp: date,
    );
    await helper.insertTransaction(
      amount: 999999,
      type: 'income',
      categoryId: incomeCategory,
      timestamp: monthEnd,
    );

    final totals = await helper.getCashFlowSummary(
      start: monthStart,
      end: monthEnd,
    );
    expect(totals['total_income'], 100000.0);
    expect(totals['total_expense'], 35000.0);
    expect(totals['current_balance'], 65000.0);

    final empty = await helper.getCashFlowSummary(
      start: DateTime.utc(2027),
      end: DateTime.utc(2027, 2),
    );
    expect(empty.values, everyElement(0.0));
  });

  test(
    'dashboard uses all-time balance and active-month income/expense',
    () async {
      final expenseCategory = await category();
      final incomeCategory = await category(name: 'Consulting', type: 'income');
      final monthStart = DateTime.utc(2026, 9);
      final monthEnd = DateTime.utc(2026, 10);
      await helper.insertTransaction(
        amount: 50000,
        type: 'income',
        categoryId: incomeCategory,
        timestamp: DateTime.utc(2026, 8, 20),
      );
      await helper.insertTransaction(
        amount: 100000,
        type: 'income',
        categoryId: incomeCategory,
        timestamp: date,
      );
      await helper.insertTransaction(
        amount: 30000,
        type: 'expense',
        categoryId: expenseCategory,
        timestamp: date,
      );

      final totals = await helper.getDashboardSummary(
        start: monthStart,
        end: monthEnd,
      );
      expect(totals['current_balance'], 120000.0);
      expect(totals['total_income'], 100000.0);
      expect(totals['total_expense'], 30000.0);
    },
  );

  test('transaction details include joined category metadata', () async {
    final categoryId = await category(name: 'Coffee');
    final id = await transaction(categoryId);
    final row = (await helper.getTransactionDetails(limit: 1)).single;
    expect(row['id'], id);
    expect(row['category_name'], 'Coffee');
    expect(row['category_icon'], 'restaurant');
    expect(row['category_color'], 0xFF008000);
  });

  test(
    'expense breakdown groups, ranks, and excludes range boundaries',
    () async {
      final food = await category(name: 'Cafe');
      final transport = await category(name: 'Taxi');
      final income = await category(name: 'Bonus', type: 'income');
      final start = DateTime.utc(2026, 9, 14);
      final end = DateTime.utc(2026, 9, 21);
      await helper.insertTransaction(
        amount: 100,
        type: 'expense',
        categoryId: food,
        timestamp: start,
      );
      await helper.insertTransaction(
        amount: 250,
        type: 'expense',
        categoryId: food,
        timestamp: date,
      );
      await helper.insertTransaction(
        amount: 500,
        type: 'expense',
        categoryId: transport,
        timestamp: date,
      );
      await helper.insertTransaction(
        amount: 999,
        type: 'expense',
        categoryId: transport,
        timestamp: end,
      );
      await helper.insertTransaction(
        amount: 10000,
        type: 'income',
        categoryId: income,
        timestamp: date,
      );

      final rows = await helper.getExpenseBreakdown(start: start, end: end);
      expect(rows.map((row) => row['category_name']), ['Taxi', 'Cafe']);
      expect(rows.first['total_amount'], 500.0);
      expect(rows.last['total_amount'], 350.0);
      expect(rows.last['transaction_count'], 2);
    },
  );

  test('budget progress reports safe, warning, and exceeded states', () async {
    final food = await category(name: 'Budget Food');
    final transport = await category(name: 'Budget Transport');
    final health = await category(name: 'Budget Health');
    final income = await category(name: 'Budget Income', type: 'income');

    await helper.insertBudget(
      categoryId: food,
      amountLimit: 1000,
      month: 9,
      year: 2026,
      alertPercentage: 80,
    );
    await helper.insertBudget(
      categoryId: transport,
      amountLimit: 200,
      month: 9,
      year: 2026,
      alertPercentage: 75,
    );
    await helper.insertBudget(
      categoryId: health,
      amountLimit: 500,
      month: 9,
      year: 2026,
      alertPercentage: 80,
    );

    Future<void> spend(int categoryId, double amount, DateTime timestamp) {
      return helper
          .insertTransaction(
            amount: amount,
            type: 'expense',
            categoryId: categoryId,
            timestamp: timestamp,
          )
          .then((_) {});
    }

    await spend(food, 800, DateTime(2026, 9, 10));
    await spend(transport, 250, DateTime(2026, 9, 11));
    await spend(health, 100, DateTime(2026, 9, 12));
    await spend(food, 9999, DateTime(2026, 10));

    final rows = await helper.getBudgetProgress(month: 9, year: 2026);
    expect(rows.map((row) => row['warning_state']), [
      'exceeded',
      'warning',
      'safe',
    ]);
    expect(rows[0]['actual_spent'], 250.0);
    expect(rows[0]['progress_percentage'], 125.0);
    expect(rows[1]['actual_spent'], 800.0);
    expect(rows[1]['progress_percentage'], 80.0);
    expect(rows[2]['actual_spent'], 100.0);

    await expectLater(
      helper.insertBudget(
        categoryId: food,
        amountLimit: 500,
        month: 9,
        year: 2026,
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      helper.insertBudget(
        categoryId: income,
        amountLimit: 500,
        month: 9,
        year: 2026,
      ),
      throwsArgumentError,
    );
  });

  test('recurring rule CRUD validates frequency and category type', () async {
    final bills = await category(name: 'Internet');
    final id = await helper.insertRecurringRule(
      name: 'Home internet',
      amount: 45000,
      categoryId: bills,
      type: 'expense',
      frequency: 'monthly',
      lastExecuted: DateTime.utc(2026, 8, 1),
    );
    var rule = (await helper.getRecurringRules()).single;
    expect(rule['id'], id);
    expect(rule['name'], 'Home internet');
    expect(rule['frequency'], 'monthly');

    expect(
      await helper.updateRecurringRule(
        id: id,
        name: 'Fiber internet',
        amount: 50000,
        categoryId: bills,
        type: 'expense',
        frequency: 'monthly',
      ),
      1,
    );
    rule = (await helper.getRecurringRules()).single;
    expect(rule['name'], 'Fiber internet');
    expect(rule['last_executed'], isNull);
    await expectLater(
      helper.insertRecurringRule(
        name: 'Broken',
        amount: 1,
        categoryId: bills,
        type: 'expense',
        frequency: 'sometimes',
      ),
      throwsArgumentError,
    );
    expect(await helper.deleteRecurringRule(id), 1);
    expect(await helper.getRecurringRules(), isEmpty);
  });

  test('common queries use the intended indexes', () async {
    final db = await helper.database;
    final queries = {
      'idx_categories_archived_type_name':
          "SELECT * FROM categories WHERE is_archived = 0 AND type = 'expense' ORDER BY name, id",
      'idx_transactions_timestamp':
          'SELECT * FROM transactions WHERE timestamp >= 0 ORDER BY timestamp DESC, id DESC',
      'idx_transactions_type_timestamp':
          "SELECT * FROM transactions WHERE type = 'expense' AND timestamp >= 0 ORDER BY timestamp DESC, id DESC",
      'idx_transactions_category_timestamp':
          'SELECT * FROM transactions WHERE category_id = 1 AND timestamp >= 0 ORDER BY timestamp DESC, id DESC',
      'idx_budgets_year_month_category':
          'SELECT * FROM budgets WHERE year = 2026 AND month = 9 ORDER BY category_id',
      'idx_recurring_rules_last_executed':
          'SELECT * FROM recurring_rules ORDER BY last_executed, id',
    };
    for (final entry in queries.entries) {
      final plan = await db.rawQuery('EXPLAIN QUERY PLAN ${entry.value}');
      expect(plan.map((row) => row['detail']).join(' '), contains(entry.key));
    }
  });

  test('initialization can retry after a failed open', () async {
    await helper.close();
    final factory = _FailOnceFactory();
    helper = DatabaseHelper.forTesting(
      databaseFactory: factory,
      databasePath: p.join(directory.path, 'retry.db'),
    );
    await expectLater(helper.initialize(), throwsStateError);
    await helper.initialize();
    expect(factory.attempts, 2);
    expect(await helper.getCategories(), hasLength(10));
  });

  test(
    'version 4 migration preserves data and adds category archiving',
    () async {
      await helper.close();
      final legacyPath = p.join(directory.path, 'legacy.db');
      final legacyDatabase = await databaseFactoryFfi.openDatabase(
        legacyPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              icon TEXT NOT NULL,
              color INTEGER NOT NULL,
              type TEXT NOT NULL,
              UNIQUE (id, type)
            )
          ''');
            await db.execute('''
            CREATE TABLE transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              type TEXT NOT NULL,
              category_id INTEGER NOT NULL,
              timestamp INTEGER NOT NULL,
              note TEXT
            )
          ''');
            await db.insert('categories', {
              'name': 'My custom category',
              'icon': 'star',
              'color': 0xFF112233,
              'type': 'expense',
            });
          },
        ),
      );
      await legacyDatabase.close();

      helper = DatabaseHelper.forTesting(
        databaseFactory: databaseFactoryFfi,
        databasePath: legacyPath,
      );
      await helper.initialize();

      expect(await (await helper.database).getVersion(), 4);
      final categories = await helper.getCategories(includeArchived: true);
      expect(categories, hasLength(1));
      expect(categories.single['name'], 'My custom category');
      expect(categories.single['is_archived'], 0);
      final tables = await (await helper.database).rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      expect(
        tables.map((row) => row['name']),
        containsAll(['budgets', 'recurring_rules']),
      );
    },
  );
}

class _FailOnceFactory implements DatabaseFactory {
  int attempts = 0;

  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) {
    if (++attempts == 1) throw StateError('Simulated open failure');
    return databaseFactoryFfi.openDatabase(path, options: options);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
