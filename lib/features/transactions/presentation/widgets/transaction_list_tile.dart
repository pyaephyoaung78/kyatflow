import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_theme.dart';
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
    final income = transaction.type == TransactionType.income;
    final note = transaction.note?.trim();
    final subtitle = note == null || note.isEmpty
        ? showDate
              ? formatShortDate(transaction.timestamp)
              : formatTransactionTime(transaction.timestamp)
        : note;
    final amount = Text(
      '${income ? '+' : '−'}${formatMoney(transaction.amount)}',
      style: TextStyle(
        color: income ? AppTheme.accent : AppTheme.ink,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        fontFeatures: AppTheme.numbers,
      ),
    );
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categoryIconFromKey(transaction.categoryIcon),
                  color: AppTheme.ink,
                  size: 20,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption,
                    ),
                    if (stacked) ...[const SizedBox(height: 6), amount],
                  ],
                ),
              ),
              if (!stacked) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(fit: BoxFit.scaleDown, child: amount),
                      if (showDate) ...[
                        const SizedBox(height: 4),
                        Text(
                          formatShortDate(transaction.timestamp),
                          style: AppTheme.caption,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
    if (onTap == null) return content;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppTheme.ink),
        child: content,
      ),
    );
  }
}
