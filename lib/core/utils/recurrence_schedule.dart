abstract final class RecurrenceSchedule {
  static const frequencies = {'daily', 'weekly', 'monthly', 'yearly'};

  static DateTime nextOccurrence(
    DateTime current,
    String frequency, {
    required DateTime anchor,
  }) {
    if (!frequencies.contains(frequency)) {
      throw ArgumentError.value(frequency, 'frequency', 'Invalid frequency');
    }
    return switch (frequency) {
      'daily' => _dateLike(
        current,
        current.year,
        current.month,
        current.day + 1,
      ),
      'weekly' => _dateLike(
        current,
        current.year,
        current.month,
        current.day + 7,
      ),
      'monthly' => _nextMonth(current, anchor),
      'yearly' => _nextYear(current, anchor),
      _ => throw StateError('Frequency was already validated'),
    };
  }

  static DateTime firstOccurrenceAfter(
    DateTime firstDue,
    String frequency,
    DateTime reference,
  ) {
    var occurrence = firstDue;
    var iterations = 0;
    while (!occurrence.isAfter(reference)) {
      if (++iterations > 1200) {
        throw StateError('Recurring schedule exceeds 1200 occurrences.');
      }
      occurrence = nextOccurrence(occurrence, frequency, anchor: firstDue);
    }
    return occurrence;
  }

  static DateTime _nextMonth(DateTime current, DateTime anchor) {
    final target = current.month == 12
        ? (year: current.year + 1, month: 1)
        : (year: current.year, month: current.month + 1);
    final day = anchor.day.clamp(1, _daysInMonth(target.year, target.month));
    return _dateLike(current, target.year, target.month, day);
  }

  static DateTime _nextYear(DateTime current, DateTime anchor) {
    final year = current.year + 1;
    final day = anchor.day.clamp(1, _daysInMonth(year, anchor.month));
    return _dateLike(current, year, anchor.month, day);
  }

  static int _daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  static DateTime _dateLike(DateTime source, int year, int month, int day) {
    if (source.isUtc) {
      return DateTime.utc(
        year,
        month,
        day,
        source.hour,
        source.minute,
        source.second,
        source.millisecond,
        source.microsecond,
      );
    }
    return DateTime(
      year,
      month,
      day,
      source.hour,
      source.minute,
      source.second,
      source.millisecond,
      source.microsecond,
    );
  }
}
