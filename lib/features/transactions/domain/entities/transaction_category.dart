import 'transaction_entry.dart';

class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  final int id;
  final String name;
  final String icon;
  final int color;
  final TransactionType type;
}
