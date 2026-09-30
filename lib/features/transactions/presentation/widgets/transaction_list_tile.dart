import 'package:flutter/material.dart';

import '../../domain/entities/transaction_entry.dart';
import '../utils/category_icon_mapper.dart';
import '../utils/finance_formatters.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
    this.showDate = false,
    this.onTap,
  });

  final TransactionEntry transaction;
  final bool showDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? const Color(0xFF16866B) : const Color(0xFFE85D4A);
    final categoryColor = Color(transaction.categoryColor ?? 0xFF78909C);
    final note = transaction.note?.trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  categoryIconFromKey(transaction.categoryIcon),
                  color: categoryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.categoryName ?? 'Category',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      note == null || note.isEmpty
                          ? showDate
                                ? formatShortDate(transaction.timestamp)
                                : formatTransactionTime(transaction.timestamp)
                          : note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}${formatMoney(transaction.amount)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (showDate) ...[
                    const SizedBox(height: 3),
                    Text(
                      formatTransactionTime(transaction.timestamp),
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
