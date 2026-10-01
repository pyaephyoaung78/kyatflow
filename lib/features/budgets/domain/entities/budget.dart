enum BudgetWarningState { safe, warning, exceeded }

class BudgetDraft {
  const BudgetDraft({
    required this.categoryId,
    required this.amountLimit,
    required this.month,
    required this.year,
    this.alertPercentage = 80,
  });

  final int categoryId;
  final double amountLimit;
  final int month;
  final int year;
  final double alertPercentage;
}

class Budget extends BudgetDraft {
  const Budget({
    required this.id,
    required super.categoryId,
    required super.amountLimit,
    required super.month,
    required super.year,
    super.alertPercentage,
  });

  final int id;
}

class BudgetProgress {
  const BudgetProgress({
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
  final BudgetWarningState warningState;

  double get progress => (progressPercentage / 100).clamp(0.0, 1.0);
  double get remaining =>
      (amountLimit - actualSpent).clamp(0.0, double.infinity);
  bool get isWarning => warningState != BudgetWarningState.safe;
  bool get isExceeded => warningState == BudgetWarningState.exceeded;
}
