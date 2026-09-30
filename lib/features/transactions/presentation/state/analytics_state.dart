import '../../domain/entities/category_spending.dart';
import '../../domain/value_objects/transaction_date_filter.dart';

enum AnalyticsPeriod { thisWeek, thisMonth }

enum AnalyticsLoadStatus { initial, loading, ready, failure }

extension AnalyticsPeriodRange on AnalyticsPeriod {
  DateRange rangeFor(DateTime referenceDate) => switch (this) {
    AnalyticsPeriod.thisWeek => TransactionDateFilter.thisWeek.rangeFor(
      referenceDate,
    ),
    AnalyticsPeriod.thisMonth => TransactionDateFilter.thisMonth.rangeFor(
      referenceDate,
    ),
  };
}

class AnalyticsState {
  AnalyticsState({
    required this.status,
    required this.period,
    required this.referenceDate,
    required this.range,
    required List<CategorySpending> categories,
    this.error,
  }) : categories = List.unmodifiable(categories),
       totalExpense = categories.fold(0, (total, item) => total + item.amount);

  factory AnalyticsState.initial(DateTime now) {
    return AnalyticsState(
      status: AnalyticsLoadStatus.initial,
      period: AnalyticsPeriod.thisMonth,
      referenceDate: now,
      range: AnalyticsPeriod.thisMonth.rangeFor(now),
      categories: const [],
    );
  }

  static const _unchanged = Object();

  final AnalyticsLoadStatus status;
  final AnalyticsPeriod period;
  final DateTime referenceDate;
  final DateRange range;
  final List<CategorySpending> categories;
  final double totalExpense;
  final Object? error;

  AnalyticsState copyWith({
    AnalyticsLoadStatus? status,
    AnalyticsPeriod? period,
    DateTime? referenceDate,
    DateRange? range,
    List<CategorySpending>? categories,
    Object? error = _unchanged,
  }) {
    return AnalyticsState(
      status: status ?? this.status,
      period: period ?? this.period,
      referenceDate: referenceDate ?? this.referenceDate,
      range: range ?? this.range,
      categories: categories ?? this.categories,
      error: identical(error, _unchanged) ? this.error : error,
    );
  }
}
