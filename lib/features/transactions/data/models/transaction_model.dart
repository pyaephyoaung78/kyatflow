import '../../domain/entities/transaction_entry.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.timestamp,
    this.note,
  });

  factory TransactionModel.fromMap(Map<String, Object?> map) {
    return TransactionModel(
      id: map['id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      categoryId: map['category_id'] as int,
      timestamp: map['timestamp'] as int,
      note: map['note'] as String?,
    );
  }

  final int id;
  final double amount;
  final String type;
  final int categoryId;
  final int timestamp;
  final String? note;

  TransactionEntry toEntity() {
    return TransactionEntry(
      id: id,
      amount: amount,
      type: TransactionType.fromDatabase(type),
      categoryId: categoryId,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      note: note,
    );
  }
}
