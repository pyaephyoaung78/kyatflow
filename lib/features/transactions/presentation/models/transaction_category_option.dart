import 'package:flutter/material.dart';

import '../../domain/entities/transaction_entry.dart';

/// Presentation-ready category data backed by a real SQLite category ID.
class TransactionCategoryOption {
  const TransactionCategoryOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  final int id;
  final String name;
  final IconData icon;
  final Color color;
  final TransactionType type;
}
