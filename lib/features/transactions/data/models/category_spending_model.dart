import '../../domain/entities/category_spending.dart';

class CategorySpendingModel {
  const CategorySpendingModel({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amount,
    required this.transactionCount,
  });

  factory CategorySpendingModel.fromMap(Map<String, Object?> map) {
    return CategorySpendingModel(
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String,
      categoryIcon: map['category_icon'] as String,
      categoryColor: map['category_color'] as int,
      amount: (map['total_amount'] as num).toDouble(),
      transactionCount: map['transaction_count'] as int,
    );
  }

  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final int categoryColor;
  final double amount;
  final int transactionCount;

  CategorySpending toEntity() {
    return CategorySpending(
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      categoryColor: categoryColor,
      amount: amount,
      transactionCount: transactionCount,
    );
  }
}
