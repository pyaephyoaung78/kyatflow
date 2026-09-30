import '../../domain/entities/cash_flow_summary.dart';
import '../../domain/entities/transaction_entry.dart';
import '../../domain/value_objects/transaction_date_filter.dart';

enum TransactionLoadStatus { initial, loading, ready, failure }

class TransactionState {
  TransactionState({
    required this.status,
    required this.filter,
    required this.referenceDate,
    required this.listRange,
    required this.monthRange,
    required List<TransactionEntry> transactions,
    required this.summary,
    this.isMutating = false,
    this.error,
    this.stackTrace,
  }) : transactions = List.unmodifiable(transactions);

  factory TransactionState.initial(DateTime referenceDate) {
    return TransactionState(
      status: TransactionLoadStatus.initial,
      filter: TransactionDateFilter.thisMonth,
      referenceDate: referenceDate,
      listRange: TransactionDateFilter.thisMonth.rangeFor(referenceDate),
      monthRange: monthRangeFor(referenceDate),
      transactions: const [],
      summary: const CashFlowSummary.zero(),
    );
  }

  static const _notProvided = Object();

  final TransactionLoadStatus status;
  final TransactionDateFilter filter;
  final DateTime referenceDate;
  final DateRange listRange;
  final DateRange monthRange;
  final List<TransactionEntry> transactions;
  final CashFlowSummary summary;
  final bool isMutating;
  final Object? error;
  final StackTrace? stackTrace;

  TransactionState copyWith({
    TransactionLoadStatus? status,
    TransactionDateFilter? filter,
    DateTime? referenceDate,
    DateRange? listRange,
    DateRange? monthRange,
    List<TransactionEntry>? transactions,
    CashFlowSummary? summary,
    bool? isMutating,
    Object? error = _notProvided,
    Object? stackTrace = _notProvided,
  }) {
    return TransactionState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      referenceDate: referenceDate ?? this.referenceDate,
      listRange: listRange ?? this.listRange,
      monthRange: monthRange ?? this.monthRange,
      transactions: transactions ?? this.transactions,
      summary: summary ?? this.summary,
      isMutating: isMutating ?? this.isMutating,
      error: identical(error, _notProvided) ? this.error : error,
      stackTrace: identical(stackTrace, _notProvided)
          ? this.stackTrace
          : stackTrace as StackTrace?,
    );
  }
}
