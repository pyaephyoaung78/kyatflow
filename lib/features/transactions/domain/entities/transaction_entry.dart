enum TransactionType {
  income,
  expense;

  String get databaseValue => name;

  static TransactionType fromDatabase(String value) {
    return switch (value) {
      'income' => TransactionType.income,
      'expense' => TransactionType.expense,
      _ => throw FormatException('Unknown transaction type: $value'),
    };
  }
}

/// A transaction that has already been persisted.
class TransactionEntry {
  const TransactionEntry({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.timestamp,
    this.note,
  });

  final int id;
  final double amount;
  final TransactionType type;
  final int categoryId;
  final DateTime timestamp;
  final String? note;

  TransactionDraft toDraft() {
    return TransactionDraft(
      amount: amount,
      type: type,
      categoryId: categoryId,
      timestamp: timestamp,
      note: note,
    );
  }
}

/// Values needed to create or replace a transaction.
class TransactionDraft {
  const TransactionDraft({
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.timestamp,
    this.note,
  });

  final double amount;
  final TransactionType type;
  final int categoryId;
  final DateTime timestamp;
  final String? note;
}
