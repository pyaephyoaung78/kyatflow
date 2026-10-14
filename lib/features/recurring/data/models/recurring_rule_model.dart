import '../../../transactions/domain/entities/transaction_entry.dart';
import '../../domain/entities/recurring_rule.dart';

class RecurringRuleModel {
  const RecurringRuleModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.type,
    required this.frequency,
    required this.firstDue,
    required this.nextDue,
    required this.lastExecuted,
    required this.isActive,
    required this.note,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
  });

  factory RecurringRuleModel.fromMap(Map<String, Object?> map) {
    return RecurringRuleModel(
      id: map['id'] as int,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int,
      type: map['type'] as String,
      frequency: map['frequency'] as String,
      firstDue: map['first_due'] as int,
      nextDue: map['next_due'] as int,
      lastExecuted: map['last_executed'] as int?,
      isActive: (map['is_active'] as int) == 1,
      note: map['note'] as String?,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] as int?,
    );
  }

  final int id;
  final String name;
  final double amount;
  final int categoryId;
  final String type;
  final String frequency;
  final int firstDue;
  final int nextDue;
  final int? lastExecuted;
  final bool isActive;
  final String? note;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;

  RecurringRule toEntity() => RecurringRule(
    id: id,
    name: name,
    amount: amount,
    categoryId: categoryId,
    type: TransactionType.fromDatabase(type),
    frequency: RecurringFrequency.fromDatabase(frequency),
    firstDue: DateTime.fromMillisecondsSinceEpoch(firstDue),
    nextDue: DateTime.fromMillisecondsSinceEpoch(nextDue),
    lastExecuted: lastExecuted == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastExecuted!),
    isActive: isActive,
    note: note,
    categoryName: categoryName,
    categoryIcon: categoryIcon,
    categoryColor: categoryColor,
  );
}
