import '../../domain/entities/transaction_entry.dart';

enum LedgerTypeFilter { all, income, expense }

enum LedgerLoadStatus { initial, loading, ready, failure }

extension LedgerTypeFilterValue on LedgerTypeFilter {
  TransactionType? get transactionType => switch (this) {
    LedgerTypeFilter.all => null,
    LedgerTypeFilter.income => TransactionType.income,
    LedgerTypeFilter.expense => TransactionType.expense,
  };
}

class LedgerState {
  LedgerState({
    required this.status,
    required this.filter,
    required this.activeMonth,
    required this.latestMonth,
    required List<TransactionEntry> transactions,
    this.error,
  }) : transactions = List.unmodifiable(transactions);

  factory LedgerState.initial(DateTime now) {
    final month = DateTime(now.year, now.month);
    return LedgerState(
      status: LedgerLoadStatus.initial,
      filter: LedgerTypeFilter.all,
      activeMonth: month,
      latestMonth: month,
      transactions: const [],
    );
  }

  static const _unchanged = Object();

  final LedgerLoadStatus status;
  final LedgerTypeFilter filter;
  final DateTime activeMonth;
  final DateTime latestMonth;
  final List<TransactionEntry> transactions;
  final Object? error;
  bool get canGoNext => activeMonth.isBefore(latestMonth);

  LedgerState copyWith({
    LedgerLoadStatus? status,
    LedgerTypeFilter? filter,
    DateTime? activeMonth,
    DateTime? latestMonth,
    List<TransactionEntry>? transactions,
    Object? error = _unchanged,
  }) {
    return LedgerState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      activeMonth: activeMonth ?? this.activeMonth,
      latestMonth: latestMonth ?? this.latestMonth,
      transactions: transactions ?? this.transactions,
      error: identical(error, _unchanged) ? this.error : error,
    );
  }
}
