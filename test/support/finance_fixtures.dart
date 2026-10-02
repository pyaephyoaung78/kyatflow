import 'package:kyatflow/features/budgets/domain/entities/budget.dart';
import 'package:kyatflow/features/budgets/domain/repositories/budget_repository.dart';
import 'package:kyatflow/features/transactions/domain/entities/cash_flow_summary.dart';
import 'package:kyatflow/features/transactions/domain/entities/category_spending.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_category.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_entry.dart';
import 'package:kyatflow/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:kyatflow/features/transactions/domain/value_objects/transaction_date_filter.dart';

class TestTransactionRepository implements TransactionRepository {
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
  Future<int> addCategory(TransactionCategoryDraft category) async => 1;

  @override
  Future<void> editCategory(TransactionCategory category) async {}

  @override
  Future<void> setCategoryArchived(int id, {required bool archived}) async {}

  @override
  Future<void> deleteCategory(int id) async {}

  @override
  Future<List<TransactionCategory>> getCategories({
    bool includeArchived = false,
  }) async => const [
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
  Future<List<CategorySpending>> getExpenseBreakdown({
    required DateTime start,
    required DateTime end,
  }) async {
    return const [
      CategorySpending(
        categoryId: 2,
        categoryName: 'Food',
        categoryIcon: 'restaurant',
        categoryColor: 0xFFFF9800,
        amount: 250,
        transactionCount: 1,
      ),
    ];
  }

  @override
  Future<List<TransactionEntry>> getLedgerTransactions({
    TransactionType? type,
    required DateTime start,
    required DateTime end,
  }) async {
    return _transactions
        .where(
          (entry) =>
              !entry.timestamp.isBefore(start) &&
              entry.timestamp.isBefore(end) &&
              (type == null || entry.type == type),
        )
        .toList();
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

class TestBudgetRepository implements BudgetRepository {
  @override
  Stream<int> get changes => const Stream.empty();

  @override
  Future<void> delete(int id) async {}

  @override
  void dispose() {}

  @override
  Future<void> edit(Budget budget) async {}

  @override
  Future<List<BudgetProgress>> getMonthlyProgress(DateTime month) async {
    return const [];
  }

  @override
  Future<int> insert(BudgetDraft budget) async => 1;
}
