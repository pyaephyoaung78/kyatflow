import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/database/database_helper.dart';
import 'package:kyatflow/features/transactions/data/repositories/sqlite_transaction_repository.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_category.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_entry.dart';
import 'package:kyatflow/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:kyatflow/features/transactions/domain/value_objects/transaction_date_filter.dart';
import 'package:kyatflow/features/transactions/presentation/state/transaction_notifier.dart';
import 'package:kyatflow/features/transactions/presentation/state/transaction_state.dart';
import 'package:kyatflow/features/transactions/presentation/state/dashboard_notifier.dart';
import 'package:kyatflow/features/transactions/presentation/state/dashboard_state.dart';
import 'package:kyatflow/features/transactions/presentation/state/analytics_notifier.dart';
import 'package:kyatflow/features/transactions/presentation/state/analytics_state.dart';
import 'package:kyatflow/features/transactions/presentation/state/ledger_notifier.dart';
import 'package:kyatflow/features/transactions/presentation/state/ledger_state.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late DatabaseHelper database;
  late SqliteTransactionRepository repository;
  late int expenseCategoryId;
  late int incomeCategoryId;
  final reference = DateTime(2026, 9, 15, 12);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kyatflow_repository_test_',
    );
    database = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'test.db'),
    );
    repository = SqliteTransactionRepository(database);
    expenseCategoryId = await database.insertCategory(
      name: 'Food',
      icon: 'restaurant',
      color: 0xFFFF9800,
      type: 'expense',
    );
    incomeCategoryId = await database.insertCategory(
      name: 'Salary',
      icon: 'wallet',
      color: 0xFF4CAF50,
      type: 'income',
    );
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  TransactionDraft draft({
    double amount = 100,
    TransactionType type = TransactionType.expense,
    DateTime? timestamp,
  }) {
    return TransactionDraft(
      amount: amount,
      type: type,
      categoryId: type == TransactionType.expense
          ? expenseCategoryId
          : incomeCategoryId,
      timestamp: timestamp ?? reference,
      note: 'Test',
    );
  }

  test('date filters use local calendar day, Monday week, and month', () async {
    final sundayBefore = DateTime(2026, 9, 13, 23, 59);
    final monday = DateTime(2026, 9, 14);
    final today = DateTime(2026, 9, 15, 8);
    final tomorrow = DateTime(2026, 9, 16);
    await repository.insert(draft(timestamp: sundayBefore));
    final mondayId = await repository.insert(draft(timestamp: monday));
    final todayId = await repository.insert(draft(timestamp: today));
    final tomorrowId = await repository.insert(draft(timestamp: tomorrow));

    final todayRows = await repository.getTransactions(
      filter: TransactionDateFilter.today,
      referenceDate: reference,
    );
    final weekRows = await repository.getTransactions(
      filter: TransactionDateFilter.thisWeek,
      referenceDate: reference,
    );
    final monthRows = await repository.getTransactions(
      filter: TransactionDateFilter.thisMonth,
      referenceDate: reference,
    );

    expect(todayRows.map((item) => item.id), [todayId]);
    expect(weekRows.map((item) => item.id), [tomorrowId, todayId, mondayId]);
    expect(monthRows, hasLength(4));
  });

  test(
    'repository aggregates, edits, deletes, and publishes revisions',
    () async {
      final revisions = <int>[];
      final subscription = repository.changes.listen(revisions.add);
      final incomeId = await repository.insert(
        draft(amount: 100000, type: TransactionType.income),
      );
      final expenseId = await repository.insert(draft(amount: 35000));
      await repository.insert(
        draft(
          amount: 900000,
          type: TransactionType.income,
          timestamp: DateTime(2026, 10),
        ),
      );

      final summary = await repository.getMonthlyCashFlow(reference);
      expect(summary.totalIncome, 100000);
      expect(summary.totalExpense, 35000);
      expect(summary.currentBalance, 65000);

      final expense = (await repository.getTransactions(
        filter: TransactionDateFilter.thisMonth,
        referenceDate: reference,
      )).firstWhere((item) => item.id == expenseId);
      await repository.edit(
        TransactionEntry(
          id: expense.id,
          amount: 25000,
          type: expense.type,
          categoryId: expense.categoryId,
          timestamp: expense.timestamp,
          note: 'Edited',
        ),
      );
      await repository.delete(incomeId);

      final afterChanges = await repository.getMonthlyCashFlow(reference);
      expect(afterChanges.currentBalance, -25000);
      expect(revisions, [1, 2, 3, 4, 5]);
      await expectLater(
        repository.delete(incomeId),
        throwsA(isA<TransactionNotFoundException>()),
      );
      expect(revisions, [1, 2, 3, 4, 5]);
      await subscription.cancel();
    },
  );

  test(
    'category management preserves used categories through archiving',
    () async {
      final id = await repository.addCategory(
        const TransactionCategoryDraft(
          name: 'Coffee',
          icon: 'restaurant',
          color: 0xFF246B55,
          type: TransactionType.expense,
        ),
      );
      await repository.editCategory(
        TransactionCategory(
          id: id,
          name: 'Cafes',
          icon: 'restaurant',
          color: 0xFF2D6A9F,
          type: TransactionType.expense,
        ),
      );
      await repository.setCategoryArchived(id, archived: true);

      expect(
        (await repository.getCategories()).map((category) => category.id),
        isNot(contains(id)),
      );
      final archived = (await repository.getCategories(
        includeArchived: true,
      )).singleWhere((category) => category.id == id);
      expect(archived.name, 'Cafes');
      expect(archived.isArchived, isTrue);

      final transactionId = await repository.insert(
        TransactionDraft(
          amount: 4500,
          type: TransactionType.expense,
          categoryId: id,
          timestamp: reference,
          note: 'Coffee beans',
        ),
      );
      await expectLater(
        repository.deleteCategory(id),
        throwsA(isA<CategoryInUseException>()),
      );
      await repository.delete(transactionId);
      await repository.deleteCategory(id);
      expect(
        (await repository.getCategories(
          includeArchived: true,
        )).map((category) => category.id),
        isNot(contains(id)),
      );
    },
  );

  test(
    'notifier streams list and monthly balance updates to its state',
    () async {
      final notifier = TransactionNotifier(
        repository: repository,
        clock: () => reference,
      );
      addTearDown(notifier.dispose);
      await _waitForState(
        notifier,
        (state) => state.status == TransactionLoadStatus.ready,
      );

      final incomeId = await notifier.add(
        draft(amount: 50000, type: TransactionType.income),
      );
      await notifier.add(draft(amount: 12500));
      expect(notifier.state.transactions, hasLength(2));
      expect(notifier.state.summary.currentBalance, 37500);
      expect(notifier.state.isMutating, isFalse);

      await notifier.setFilter(TransactionDateFilter.today);
      expect(notifier.state.filter, TransactionDateFilter.today);
      expect(notifier.state.transactions, hasLength(2));

      // A write through the repository still reaches the notifier via changes.
      await repository.insert(draft(timestamp: DateTime(2026, 9, 14, 10)));
      await _waitForState(
        notifier,
        (state) => state.summary.totalExpense == 12600,
      );
      expect(notifier.state.transactions, hasLength(2));

      await notifier.delete(incomeId);
      expect(notifier.state.summary.currentBalance, -12600);
      expect(notifier.state.transactions, hasLength(1));
    },
  );

  test(
    'dashboard and ledger stream repository changes and type filters',
    () async {
      final dashboard = DashboardNotifier(
        repository: repository,
        clock: () => reference,
      );
      final ledger = LedgerNotifier(repository, clock: () => reference);
      addTearDown(dashboard.dispose);
      addTearDown(ledger.dispose);
      await _waitForDashboard(
        dashboard,
        (state) => state.status == DashboardLoadStatus.ready,
      );
      await _waitForLedger(
        ledger,
        (state) => state.status == LedgerLoadStatus.ready,
      );

      await repository.insert(
        draft(
          amount: 1000,
          type: TransactionType.income,
          timestamp: DateTime(2026, 8, 20),
        ),
      );
      await repository.insert(draft(amount: 250));
      await _waitForDashboard(
        dashboard,
        (state) => state.summary.currentBalance == 750,
      );
      await _waitForLedger(ledger, (state) => state.transactions.length == 1);

      expect(dashboard.state.summary.totalIncome, 0);
      expect(dashboard.state.summary.totalExpense, 250);
      expect(dashboard.state.recentTransactions.first.categoryName, 'Food');
      expect(dashboard.state.categories, isNotEmpty);

      await ledger.showPreviousMonth();
      expect(ledger.state.activeMonth, DateTime(2026, 8));
      await ledger.setFilter(LedgerTypeFilter.income);
      expect(ledger.state.transactions, hasLength(1));
      expect(ledger.state.transactions.single.type, TransactionType.income);
      expect(ledger.state.transactions.single.categoryName, 'Salary');

      await ledger.showNextMonth();
      expect(ledger.state.activeMonth, DateTime(2026, 9));
      expect(ledger.state.transactions, isEmpty);
      await repository.insert(draft(amount: 400, type: TransactionType.income));
      await _waitForLedger(ledger, (state) => state.transactions.length == 1);
      await _waitForDashboard(
        dashboard,
        (state) => state.summary.totalIncome == 400,
      );
      expect(dashboard.state.summary.currentBalance, 1150);
    },
  );

  test(
    'analytics streams grouped expenses and switches calendar ranges',
    () async {
      final analytics = AnalyticsNotifier(
        repository: repository,
        clock: () => reference,
      );
      addTearDown(analytics.dispose);
      await _waitForAnalytics(
        analytics,
        (state) => state.status == AnalyticsLoadStatus.ready,
      );

      await repository.insert(draft(amount: 250));
      await repository.insert(
        draft(amount: 75, timestamp: DateTime(2026, 9, 1, 10)),
      );
      await _waitForAnalytics(analytics, (state) => state.totalExpense == 325);
      expect(analytics.state.categories.single.categoryName, 'Food');
      expect(analytics.state.categories.single.transactionCount, 2);

      await analytics.setPeriod(AnalyticsPeriod.thisWeek);
      expect(analytics.state.totalExpense, 250);
      expect(analytics.state.range.start, DateTime(2026, 9, 14));
      expect(analytics.state.range.end, DateTime(2026, 9, 21));

      await repository.insert(draft(amount: 100));
      await _waitForAnalytics(analytics, (state) => state.totalExpense == 350);
    },
  );
}

Future<void> _waitForState(
  TransactionNotifier notifier,
  bool Function(TransactionState state) predicate,
) async {
  if (predicate(notifier.state)) return;
  final completer = Completer<void>();
  late final void Function() removeListener;
  removeListener = notifier.addListener((state) {
    if (!completer.isCompleted && predicate(state)) completer.complete();
  });
  try {
    await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    removeListener();
  }
}

Future<void> _waitForDashboard(
  DashboardNotifier notifier,
  bool Function(DashboardState state) predicate,
) async {
  if (predicate(notifier.state)) return;
  final completer = Completer<void>();
  late final void Function() removeListener;
  removeListener = notifier.addListener((state) {
    if (!completer.isCompleted && predicate(state)) completer.complete();
  });
  try {
    await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    removeListener();
  }
}

Future<void> _waitForLedger(
  LedgerNotifier notifier,
  bool Function(LedgerState state) predicate,
) async {
  if (predicate(notifier.state)) return;
  final completer = Completer<void>();
  late final void Function() removeListener;
  removeListener = notifier.addListener((state) {
    if (!completer.isCompleted && predicate(state)) completer.complete();
  });
  try {
    await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    removeListener();
  }
}

Future<void> _waitForAnalytics(
  AnalyticsNotifier notifier,
  bool Function(AnalyticsState state) predicate,
) async {
  if (predicate(notifier.state)) return;
  final completer = Completer<void>();
  late final void Function() removeListener;
  removeListener = notifier.addListener((state) {
    if (!completer.isCompleted && predicate(state)) completer.complete();
  });
  try {
    await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    removeListener();
  }
}
