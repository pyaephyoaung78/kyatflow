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
    required List<TransactionEntry> transactions,
    this.error,
  }) : transactions = List.unmodifiable(transactions);

  const LedgerState.initial()
    : status = LedgerLoadStatus.initial,
      filter = LedgerTypeFilter.all,
      transactions = const [],
      error = null;

  static const _unchanged = Object();

  final LedgerLoadStatus status;
  final LedgerTypeFilter filter;
  final List<TransactionEntry> transactions;
  final Object? error;

  LedgerState copyWith({
    LedgerLoadStatus? status,
    LedgerTypeFilter? filter,
    List<TransactionEntry>? transactions,
    Object? error = _unchanged,
  }) {
    return LedgerState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      transactions: transactions ?? this.transactions,
      error: identical(error, _unchanged) ? this.error : error,
    );
  }
}
