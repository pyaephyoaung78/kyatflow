enum TransactionDateFilter { today, thisWeek, thisMonth }

class DateRange {
  const DateRange({required this.start, required this.end});

  /// Inclusive lower bound.
  final DateTime start;

  /// Exclusive upper bound.
  final DateTime end;
}

extension TransactionDateFilterRange on TransactionDateFilter {
  DateRange rangeFor(DateTime reference) {
    final today = _calendarDate(
      reference,
      reference.year,
      reference.month,
      reference.day,
    );
    return switch (this) {
      TransactionDateFilter.today => DateRange(
        start: today,
        end: _calendarDate(
          reference,
          reference.year,
          reference.month,
          reference.day + 1,
        ),
      ),
      TransactionDateFilter.thisWeek => _weekRange(reference, today),
      TransactionDateFilter.thisMonth => DateRange(
        start: _calendarDate(reference, reference.year, reference.month),
        end: _calendarDate(reference, reference.year, reference.month + 1),
      ),
    };
  }

  DateRange _weekRange(DateTime reference, DateTime today) {
    final monday = _calendarDate(
      reference,
      today.year,
      today.month,
      today.day - (today.weekday - DateTime.monday),
    );
    return DateRange(
      start: monday,
      end: _calendarDate(reference, monday.year, monday.month, monday.day + 7),
    );
  }
}

DateTime _calendarDate(DateTime source, int year, int month, [int day = 1]) {
  return source.isUtc
      ? DateTime.utc(year, month, day)
      : DateTime(year, month, day);
}

DateRange monthRangeFor(DateTime reference) {
  return TransactionDateFilter.thisMonth.rangeFor(reference);
}
