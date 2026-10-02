import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_entry.dart';

class TransactionCategoryModel {
  const TransactionCategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.isArchived,
  });

  factory TransactionCategoryModel.fromMap(Map<String, Object?> map) {
    return TransactionCategoryModel(
      id: map['id'] as int,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as int,
      type: map['type'] as String,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
    );
  }

  final int id;
  final String name;
  final String icon;
  final int color;
  final String type;
  final bool isArchived;

  TransactionCategory toEntity() {
    return TransactionCategory(
      id: id,
      name: name,
      icon: icon,
      color: color,
      type: TransactionType.fromDatabase(type),
      isArchived: isArchived,
    );
  }
}
