import '../../domain/entities/cash_flow_summary.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_entry.dart';

enum DashboardLoadStatus { initial, loading, ready, failure }

class DashboardState {
  DashboardState({
    required this.status,
    required this.activeMonth,
    required this.summary,
    required List<TransactionEntry> recentTransactions,
    required List<TransactionCategory> categories,
    this.error,
  }) : recentTransactions = List.unmodifiable(recentTransactions),
       categories = List.unmodifiable(categories);

  factory DashboardState.initial(DateTime now) {
    return DashboardState(
      status: DashboardLoadStatus.initial,
      activeMonth: now,
      summary: const CashFlowSummary.zero(),
      recentTransactions: const [],
      categories: const [],
    );
  }

  static const _unchanged = Object();

  final DashboardLoadStatus status;
  final DateTime activeMonth;
  final CashFlowSummary summary;
  final List<TransactionEntry> recentTransactions;
  final List<TransactionCategory> categories;
  final Object? error;

  DashboardState copyWith({
    DashboardLoadStatus? status,
    DateTime? activeMonth,
    CashFlowSummary? summary,
    List<TransactionEntry>? recentTransactions,
    List<TransactionCategory>? categories,
    Object? error = _unchanged,
  }) {
    return DashboardState(
      status: status ?? this.status,
      activeMonth: activeMonth ?? this.activeMonth,
      summary: summary ?? this.summary,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      categories: categories ?? this.categories,
      error: identical(error, _unchanged) ? this.error : error,
    );
  }
}
