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
    expect(find.text('750 Mmk'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);

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
    expect(find.text('250 Mmk'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('ledger_tab')));
    await tester.pumpAndSettle();
    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ledger_transaction_2')));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.text('Delete transaction'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('history_category_filter')));
    await tester.pumpAndSettle();
    expect(find.text('Filter by category'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history_category_2')));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Salary'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('clear_history_filters')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('history_date_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 7 days'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clear_history_filters')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear_history_filters')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ledger_filter_income')));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings_tab')));
    await tester.pumpAndSettle();
    expect(find.text('Local-first by design'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('manage_categories')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('manage_categories')));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('manage_category_2')));
    await tester.pumpAndSettle();
    expect(find.text('Edit category'), findsOneWidget);
    expect(find.text('Archive category'), findsOneWidget);
    expect(find.text('Delete permanently'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_category')));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);
    await tester.drag(
      find.byType(Scrollable).last,
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add category'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open_user_guide')));
    await tester.pumpAndSettle();
    expect(find.text('How to use Kyat Flow'), findsWidgets);
    expect(find.text('Add your income'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Keep a backup'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Keep a backup'), findsOneWidget);
    await tester.pageBack();
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
