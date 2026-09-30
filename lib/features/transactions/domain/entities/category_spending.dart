class CategorySpending {
  const CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amount,
    required this.transactionCount,
  });

  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final int categoryColor;
  final double amount;
  final int transactionCount;
}
