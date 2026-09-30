class CashFlowSummary {
  const CashFlowSummary({
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
  });

  const CashFlowSummary.zero()
    : currentBalance = 0,
      totalIncome = 0,
      totalExpense = 0;

  final double currentBalance;
  final double totalIncome;
  final double totalExpense;
}
