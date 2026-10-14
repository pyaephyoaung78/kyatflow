import '../../../transactions/domain/entities/transaction_entry.dart';

enum RecurringFrequency {
  daily,
  weekly,
  monthly,
  yearly;

  String get label => switch (this) {
    daily => 'Daily',
    weekly => 'Weekly',
    monthly => 'Monthly',
    yearly => 'Yearly',
  };

  static RecurringFrequency fromDatabase(String value) {
    return switch (value) {
      'daily' => daily,
      'weekly' => weekly,
      'monthly' => monthly,
      'yearly' => yearly,
      _ => throw FormatException('Unknown recurring frequency: $value'),
    };
  }
}

class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.type,
    required this.frequency,
    required this.firstDue,
    required this.nextDue,
    required this.isActive,
    this.lastExecuted,
    this.note,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  final int id;
  final String name;
  final double amount;
  final int categoryId;
  final TransactionType type;
  final RecurringFrequency frequency;
  final DateTime firstDue;
  final DateTime nextDue;
  final DateTime? lastExecuted;
  final bool isActive;
  final String? note;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;
}

class RecurringRuleDraft {
  const RecurringRuleDraft({
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.type,
    required this.frequency,
    required this.firstDue,
    required this.isActive,
    this.note,
  });

  final String name;
  final double amount;
  final int categoryId;
  final TransactionType type;
  final RecurringFrequency frequency;
  final DateTime firstDue;
  final bool isActive;
  final String? note;
}
