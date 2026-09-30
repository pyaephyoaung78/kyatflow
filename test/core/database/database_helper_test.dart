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
      expect(await connections.first.getVersion(), 1);
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
    expect((await helper.getCategories(type: 'expense')).length, 1);
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

  test('common queries use the intended indexes', () async {
    final db = await helper.database;
    final queries = {
      'idx_categories_type_name':
          "SELECT * FROM categories WHERE type = 'expense' ORDER BY name, id",
      'idx_transactions_timestamp':
          'SELECT * FROM transactions WHERE timestamp >= 0 ORDER BY timestamp DESC, id DESC',
      'idx_transactions_type_timestamp':
          "SELECT * FROM transactions WHERE type = 'expense' AND timestamp >= 0 ORDER BY timestamp DESC, id DESC",
      'idx_transactions_category_timestamp':
          'SELECT * FROM transactions WHERE category_id = 1 AND timestamp >= 0 ORDER BY timestamp DESC, id DESC',
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
    expect(await helper.getCategories(), isEmpty);
  });
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
