import '../../domain/entities/cash_flow_summary.dart';

class CashFlowSummaryModel {
  const CashFlowSummaryModel({
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
  });

  factory CashFlowSummaryModel.fromMap(Map<String, Object?> map) {
    return CashFlowSummaryModel(
      currentBalance: (map['current_balance'] as num).toDouble(),
      totalIncome: (map['total_income'] as num).toDouble(),
      totalExpense: (map['total_expense'] as num).toDouble(),
    );
  }

  final double currentBalance;
  final double totalIncome;
  final double totalExpense;

  CashFlowSummary toEntity() {
    return CashFlowSummary(
      currentBalance: currentBalance,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }
}
