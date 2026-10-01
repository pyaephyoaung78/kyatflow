import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/features/budgets/presentation/providers/budget_providers.dart';
import 'package:kyatflow/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:kyatflow/main.dart';

import 'support/finance_fixtures.dart';

void main() {
  testWidgets('app opens dashboard and navigates to history', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            TestTransactionRepository(),
          ),
          budgetRepositoryProvider.overrideWithValue(TestBudgetRepository()),
        ],
        child: const KyatFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kyat Flow'), findsOneWidget);
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('MMK 750'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('analytics_tab')));
    await tester.pumpAndSettle();
    expect(find.text('See where your money goes'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).hitTestable(),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(find.text('Spending by category'), findsOneWidget);
    expect(find.text('MMK 250'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('ledger_tab')));
    await tester.pumpAndSettle();
    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ledger_filter_income')));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings_tab')));
    await tester.pumpAndSettle();
    expect(find.text('Local-first by design'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add_transaction')));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Local-first by design'), findsOneWidget);
  });
}
