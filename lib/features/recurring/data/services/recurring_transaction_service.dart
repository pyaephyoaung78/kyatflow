import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/recurrence_schedule.dart';

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
      final rules = await txn.query(
        'recurring_rules',
        where: 'is_active = 1',
        orderBy: 'next_due ASC, id ASC',
      );
      var rulesExecuted = 0;
      var transactionsCreated = 0;

      for (final rule in rules) {
        final frequency = rule['frequency'] as String;
        final firstDue = DateTime.fromMillisecondsSinceEpoch(
          rule['first_due'] as int,
          isUtc: now.isUtc,
        );
        var occurrence = DateTime.fromMillisecondsSinceEpoch(
          rule['next_due'] as int,
          isUtc: now.isUtc,
        );
        DateTime? latestExecution;
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
            'note': _transactionNote(rule),
          });
          latestExecution = occurrence;
          ruleTransactionCount++;
          transactionsCreated++;
          occurrence = RecurrenceSchedule.nextOccurrence(
            occurrence,
            frequency,
            anchor: firstDue,
          );
        }

        if (ruleTransactionCount > 0) {
          await txn.update(
            'recurring_rules',
            {
              'last_executed': latestExecution!.millisecondsSinceEpoch,
              'next_due': occurrence.millisecondsSinceEpoch,
            },
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

  String _transactionNote(Map<String, Object?> rule) {
    final note = (rule['note'] as String?)?.trim();
    return note == null || note.isEmpty
        ? 'Recurring: ${rule['name']}'
        : 'Recurring: ${rule['name']} · $note';
  }
}
