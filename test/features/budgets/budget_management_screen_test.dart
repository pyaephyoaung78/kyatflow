import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/theme/app_theme.dart';
import 'package:kyatflow/features/budgets/domain/entities/budget.dart';
import 'package:kyatflow/features/budgets/domain/repositories/budget_repository.dart';
import 'package:kyatflow/features/budgets/presentation/providers/budget_providers.dart';
import 'package:kyatflow/features/budgets/presentation/screens/budget_management_screen.dart';
import 'package:kyatflow/features/transactions/presentation/providers/transaction_providers.dart';

import '../../support/finance_fixtures.dart';

void main() {
  testWidgets('adds, edits, and deletes a monthly category budget', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final budgets = _MutableBudgetRepository();
    addTearDown(budgets.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetRepositoryProvider.overrideWithValue(budgets),
          transactionRepositoryProvider.overrideWithValue(
            TestTransactionRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BudgetManagementScreen(initialMonth: DateTime(2026, 10)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No budgets for October 2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add_first_budget')));
    await tester.pumpAndSettle();

    expect(find.text('New budget'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('budget_amount')),
      '60000',
    );
    await tester.tap(find.byKey(const ValueKey('budget_alert_90')));
    await tester.ensureVisible(find.byKey(const ValueKey('save_budget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_budget')));
    await tester.pumpAndSettle();

    expect(find.text('60,000 Mmk of 60,000 Mmk'), findsNothing);
    expect(find.text('0 Mmk of 60,000 Mmk'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget_progress_1')));
    await tester.pumpAndSettle();

    expect(find.text('Edit budget'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('budget_amount')),
      '70000',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save_budget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_budget')));
    await tester.pumpAndSettle();

    expect(find.text('0 Mmk of 70,000 Mmk'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget_progress_1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('delete_budget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete_budget')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No budgets for October 2026'), findsOneWidget);
  });
}

class _MutableBudgetRepository implements BudgetRepository {
  final _changes = StreamController<int>.broadcast(sync: true);
  final _budgets = <Budget>[];
  var _nextId = 1;
  var _revision = 0;

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Future<int> insert(BudgetDraft budget) async {
    final id = _nextId++;
    _budgets.add(
      Budget(
        id: id,
        categoryId: budget.categoryId,
        amountLimit: budget.amountLimit,
        month: budget.month,
        year: budget.year,
        alertPercentage: budget.alertPercentage,
      ),
    );
    _changes.add(++_revision);
    return id;
  }

  @override
  Future<void> edit(Budget budget) async {
    final index = _budgets.indexWhere((item) => item.id == budget.id);
    if (index < 0) throw BudgetNotFoundException(budget.id);
    _budgets[index] = budget;
    _changes.add(++_revision);
  }

  @override
  Future<void> delete(int id) async {
    _budgets.removeWhere((budget) => budget.id == id);
    _changes.add(++_revision);
  }

  @override
  Future<List<BudgetProgress>> getMonthlyProgress(DateTime month) async {
    return _budgets
        .where(
          (budget) => budget.month == month.month && budget.year == month.year,
        )
        .map(
          (budget) => BudgetProgress(
            budgetId: budget.id,
            categoryId: budget.categoryId,
            categoryName: 'Food',
            categoryIcon: 'restaurant',
            categoryColor: 0xFFFF9800,
            amountLimit: budget.amountLimit,
            actualSpent: 0,
            month: budget.month,
            year: budget.year,
            alertPercentage: budget.alertPercentage,
            progressPercentage: 0,
            warningState: BudgetWarningState.safe,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _changes.close();
  }
}
