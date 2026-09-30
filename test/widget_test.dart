import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/features/transactions/domain/entities/cash_flow_summary.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_category.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_entry.dart';
import 'package:kyatflow/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:kyatflow/features/transactions/domain/value_objects/transaction_date_filter.dart';
import 'package:kyatflow/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:kyatflow/main.dart';

void main() {
  testWidgets('app opens dashboard and navigates to history', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: const KyatFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KyatFlow'), findsOneWidget);
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('MMK 750'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
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
  });
}

class _FakeRepository implements TransactionRepository {
  List<TransactionEntry> get _transactions => [
    TransactionEntry(
      id: 1,
      amount: 1000,
      type: TransactionType.income,
      categoryId: 1,
      timestamp: DateTime.now(),
      note: 'September salary',
      categoryName: 'Salary',
      categoryIcon: 'account_balance_wallet',
      categoryColor: 0xFF43A047,
    ),
    TransactionEntry(
      id: 2,
      amount: 250,
      type: TransactionType.expense,
      categoryId: 2,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      note: 'Lunch',
      categoryName: 'Food',
      categoryIcon: 'restaurant',
      categoryColor: 0xFFFF9800,
    ),
  ];

  @override
  Stream<int> get changes => const Stream.empty();

  @override
  Future<void> delete(int id) async {}

  @override
  void dispose() {}

  @override
  Future<void> edit(TransactionEntry transaction) async {}

  @override
  Future<List<TransactionCategory>> getCategories() async => const [
    TransactionCategory(
      id: 1,
      name: 'Salary',
      icon: 'account_balance_wallet',
      color: 0xFF43A047,
      type: TransactionType.income,
    ),
    TransactionCategory(
      id: 2,
      name: 'Food',
      icon: 'restaurant',
      color: 0xFFFF9800,
      type: TransactionType.expense,
    ),
  ];

  @override
  Future<CashFlowSummary> getDashboardCashFlow(DateTime activeMonth) async {
    return const CashFlowSummary(
      currentBalance: 750,
      totalIncome: 1000,
      totalExpense: 250,
    );
  }

  @override
  Future<List<TransactionEntry>> getLedgerTransactions({
    TransactionType? type,
  }) async {
    return type == null
        ? _transactions
        : _transactions.where((entry) => entry.type == type).toList();
  }

  @override
  Future<CashFlowSummary> getMonthlyCashFlow(DateTime activeMonth) async {
    return const CashFlowSummary.zero();
  }

  @override
  Future<List<TransactionEntry>> getRecentTransactions({int limit = 5}) async {
    return _transactions.take(limit).toList();
  }

  @override
  Future<List<TransactionEntry>> getTransactions({
    required TransactionDateFilter filter,
    required DateTime referenceDate,
  }) async => const [];

  @override
  Future<int> insert(TransactionDraft transaction) async => 1;
}
