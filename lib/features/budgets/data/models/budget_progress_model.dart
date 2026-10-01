import '../../domain/entities/budget.dart';

class BudgetProgressModel {
  const BudgetProgressModel({
    required this.budgetId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amountLimit,
    required this.actualSpent,
    required this.month,
    required this.year,
    required this.alertPercentage,
    required this.progressPercentage,
    required this.warningState,
  });

  factory BudgetProgressModel.fromMap(Map<String, Object?> map) {
    return BudgetProgressModel(
      budgetId: map['id'] as int,
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String,
      categoryIcon: map['category_icon'] as String,
      categoryColor: map['category_color'] as int,
      amountLimit: (map['amount_limit'] as num).toDouble(),
      actualSpent: (map['actual_spent'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
      alertPercentage: (map['alert_percentage'] as num).toDouble(),
      progressPercentage: (map['progress_percentage'] as num).toDouble(),
      warningState: map['warning_state'] as String,
    );
  }

  final int budgetId;
  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final int categoryColor;
  final double amountLimit;
  final double actualSpent;
  final int month;
  final int year;
  final double alertPercentage;
  final double progressPercentage;
  final String warningState;

  BudgetProgress toEntity() {
    return BudgetProgress(
      budgetId: budgetId,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      categoryColor: categoryColor,
      amountLimit: amountLimit,
      actualSpent: actualSpent,
      month: month,
      year: year,
      alertPercentage: alertPercentage,
      progressPercentage: progressPercentage,
      warningState: switch (warningState) {
        'safe' => BudgetWarningState.safe,
        'warning' => BudgetWarningState.warning,
        'exceeded' => BudgetWarningState.exceeded,
        _ => throw FormatException(
          'Unknown budget warning state: $warningState',
        ),
      },
    );
  }
}
