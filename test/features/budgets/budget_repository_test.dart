import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/database/database_helper.dart';
import 'package:kyatflow/features/budgets/data/repositories/sqlite_budget_repository.dart';
import 'package:kyatflow/features/budgets/domain/entities/budget.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late DatabaseHelper database;
  late SqliteBudgetRepository repository;
  late int categoryId;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kyatflow_budget_repo_');
    database = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'test.db'),
    );
    final categories = await database.getCategories(type: 'expense');
    categoryId = categories.first['id'] as int;
    repository = SqliteBudgetRepository(database);
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('maps native spending progress and publishes CRUD revisions', () async {
    final revisions = <int>[];
    final subscription = repository.changes.listen(revisions.add);
    final id = await repository.insert(
      BudgetDraft(
        categoryId: categoryId,
        amountLimit: 1000,
        month: 10,
        year: 2026,
        alertPercentage: 75,
      ),
    );
    await database.insertTransaction(
      amount: 800,
      type: 'expense',
      categoryId: categoryId,
      timestamp: DateTime(2026, 10, 5),
    );

    var progress = (await repository.getMonthlyProgress(
      DateTime(2026, 10),
    )).single;
    expect(progress.actualSpent, 800);
    expect(progress.progressPercentage, 80);
    expect(progress.warningState, BudgetWarningState.warning);

    await repository.edit(
      Budget(
        id: id,
        categoryId: categoryId,
        amountLimit: 700,
        month: 10,
        year: 2026,
        alertPercentage: 75,
      ),
    );
    progress = (await repository.getMonthlyProgress(DateTime(2026, 10))).single;
    expect(progress.warningState, BudgetWarningState.exceeded);
    await repository.delete(id);
    expect(await repository.getMonthlyProgress(DateTime(2026, 10)), isEmpty);
    expect(revisions, [1, 2, 3]);

    await subscription.cancel();
  });
}
