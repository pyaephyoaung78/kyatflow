import '../../../../core/database/database_helper.dart';

enum RecurringFrequency {
  daily,
  weekly,
  monthly,
  yearly;

  static RecurringFrequency fromDatabase(String value) {
    return switch (value) {
      'daily' => RecurringFrequency.daily,
      'weekly' => RecurringFrequency.weekly,
      'monthly' => RecurringFrequency.monthly,
      'yearly' => RecurringFrequency.yearly,
      _ => throw FormatException('Unknown recurring frequency: $value'),
    };
  }
}

class RecurringExecutionResult {
  const RecurringExecutionResult({
    required this.rulesExecuted,
    required this.transactionsCreated,
  });

  final int rulesExecuted;
  final int transactionsCreated;
}

/// Materializes recurring rules into normal local transactions at app startup.
///
/// Each rule is processed in the same SQLite transaction as its
/// `last_executed` update. If the app or database operation fails, neither side
/// is committed, making the next startup safe to retry without duplicates.
class RecurringTransactionService {
  factory RecurringTransactionService({
    required DatabaseHelper databaseHelper,
    DateTime Function()? clock,
  }) {
    return RecurringTransactionService._(databaseHelper, clock ?? DateTime.now);
  }

  RecurringTransactionService._(this._databaseHelper, this._clock);

  static const _maximumCatchUpOccurrences = 1200;

  final DatabaseHelper _databaseHelper;
  final DateTime Function() _clock;

  Future<RecurringExecutionResult> executeDueTransactions() async {
    final now = _clock();
    final database = await _databaseHelper.database;
    return database.transaction((txn) async {
      final rules = await txn.query('recurring_rules', orderBy: 'id ASC');
      var rulesExecuted = 0;
      var transactionsCreated = 0;

      for (final rule in rules) {
        final frequency = RecurringFrequency.fromDatabase(
          rule['frequency'] as String,
        );
        final lastExecutedMillis = rule['last_executed'] as int?;
        var occurrence = lastExecutedMillis == null
            ? now
            : _nextOccurrence(
                _startOfDay(
                  DateTime.fromMillisecondsSinceEpoch(
                    lastExecutedMillis,
                    isUtc: now.isUtc,
                  ),
                ),
                frequency,
              );
        var latestExecution = lastExecutedMillis == null ? null : occurrence;
        var ruleTransactionCount = 0;

        while (!occurrence.isAfter(now)) {
          if (ruleTransactionCount >= _maximumCatchUpOccurrences) {
            throw StateError(
              'Recurring rule ${rule['id']} has more than '
              '$_maximumCatchUpOccurrences missed occurrences.',
            );
          }
          await txn.insert('transactions', {
            'amount': rule['amount'],
            'type': rule['type'],
            'category_id': rule['category_id'],
            'timestamp': occurrence.millisecondsSinceEpoch,
            'note': 'Recurring: ${rule['name']}',
          });
          latestExecution = occurrence;
          ruleTransactionCount++;
          transactionsCreated++;
          occurrence = _nextOccurrence(occurrence, frequency);
        }

        if (ruleTransactionCount > 0) {
          await txn.update(
            'recurring_rules',
            {'last_executed': latestExecution!.millisecondsSinceEpoch},
            where: 'id = ?',
            whereArgs: [rule['id']],
          );
          rulesExecuted++;
        }
      }

      return RecurringExecutionResult(
        rulesExecuted: rulesExecuted,
        transactionsCreated: transactionsCreated,
      );
    });
  }

  DateTime _startOfDay(DateTime value) {
    return value.isUtc
        ? DateTime.utc(value.year, value.month, value.day)
        : DateTime(value.year, value.month, value.day);
  }

  DateTime _nextOccurrence(DateTime previous, RecurringFrequency frequency) {
    return switch (frequency) {
      RecurringFrequency.daily => _dateLike(
        previous,
        previous.year,
        previous.month,
        previous.day + 1,
      ),
      RecurringFrequency.weekly => _dateLike(
        previous,
        previous.year,
        previous.month,
        previous.day + 7,
      ),
      RecurringFrequency.monthly => _nextMonth(previous),
      RecurringFrequency.yearly => _nextYear(previous),
    };
  }

  DateTime _nextMonth(DateTime previous) {
    final firstOfTarget = previous.month == 12
        ? (year: previous.year + 1, month: 1)
        : (year: previous.year, month: previous.month + 1);
    final day = previous.day.clamp(
      1,
      _daysInMonth(firstOfTarget.year, firstOfTarget.month),
    );
    return _dateLike(previous, firstOfTarget.year, firstOfTarget.month, day);
  }

  DateTime _nextYear(DateTime previous) {
    final year = previous.year + 1;
    final day = previous.day.clamp(1, _daysInMonth(year, previous.month));
    return _dateLike(previous, year, previous.month, day);
  }

  int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

  DateTime _dateLike(DateTime source, int year, int month, int day) {
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
