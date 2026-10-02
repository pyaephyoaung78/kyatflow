import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_entry_route.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../domain/entities/transaction_entry.dart';
import '../models/transaction_category_option.dart';
import '../providers/transaction_providers.dart';
import '../state/ledger_state.dart';
import '../utils/category_icon_mapper.dart';
import '../utils/finance_formatters.dart';
import '../widgets/transaction_list_tile.dart';
import 'transaction_entry_screen.dart';

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ledgerStateProvider);
    final groups = <DateTime, List<TransactionEntry>>{};
    for (final transaction in state.transactions) {
      final timestamp = transaction.timestamp;
      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
      (groups[day] ??= []).add(transaction);
    }

    return FinancePage(
      title: 'Transaction history',
      onRefresh: () => ref.read(ledgerStateProvider.notifier).refresh(),
      children: [
        _MonthNavigator(
          month: state.activeMonth,
          canGoNext: state.canGoNext,
          onPrevious: () =>
              ref.read(ledgerStateProvider.notifier).showPreviousMonth(),
          onNext: () => ref.read(ledgerStateProvider.notifier).showNextMonth(),
        ),
        const SizedBox(height: 12),
        FinanceSegments<LedgerTypeFilter>(
          value: state.filter,
          keyPrefix: 'ledger_filter',
          labels: const {
            LedgerTypeFilter.all: 'All',
            LedgerTypeFilter.income: 'Income',
            LedgerTypeFilter.expense: 'Expense',
          },
          onChanged: (value) =>
              ref.read(ledgerStateProvider.notifier).setFilter(value),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 12, 4, 24),
          child: Text(
            'Tap an entry to edit or delete it.',
            style: AppTheme.caption,
          ),
        ),
        if (state.status == LedgerLoadStatus.loading &&
            state.transactions.isEmpty)
          const FinanceLoading()
        else if (state.status == LedgerLoadStatus.failure)
          FinanceEmptyState(
            icon: CupertinoIcons.exclamationmark_circle,
            title: 'Could not load transaction history',
            message: 'Your records are still stored on this device.',
            onRetry: () => ref.read(ledgerStateProvider.notifier).refresh(),
          )
        else if (state.transactions.isEmpty)
          FinanceEmptyState(
            icon: CupertinoIcons.doc_text,
            title: 'No transactions in ${formatMonth(state.activeMonth)}',
            message: 'Try another month or add a new entry.',
          )
        else
          for (final group in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                formatLedgerDate(group.key, DateTime.now()),
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SurfaceGroup(
              separatorInset: 68,
              children: [
                for (final transaction in group.value)
                  TransactionListTile(
                    key: ValueKey('ledger_transaction_${transaction.id}'),
                    transaction: transaction,
                    onTap: () =>
                        _showTransactionActions(context, ref, transaction),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
      ],
    );
  }

  Future<void> _showTransactionActions(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry transaction,
  ) async {
    final action = await showCupertinoModalPopup<_TransactionAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(transaction.categoryName ?? 'Transaction'),
        message: Text(
          '${formatMoney(transaction.amount)} · '
          '${formatShortDate(transaction.timestamp)}',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _TransactionAction.edit),
            child: const Text('Edit transaction'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, _TransactionAction.delete),
            child: const Text('Delete transaction'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _TransactionAction.edit:
        await _editTransaction(context, ref, transaction);
        return;
      case _TransactionAction.delete:
        await _confirmDelete(context, ref, transaction);
        return;
    }
  }

  Future<void> _editTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry transaction,
  ) async {
    final categories = await ref
        .read(transactionRepositoryProvider)
        .getCategories(includeArchived: true);
    if (!context.mounted) return;

    final options = categories
        .where(
          (category) =>
              !category.isArchived || category.id == transaction.categoryId,
        )
        .map(
          (category) => TransactionCategoryOption(
            id: category.id,
            name: category.name,
            icon: categoryIconFromKey(category.icon),
            color: Color(category.color),
            type: category.type,
          ),
        )
        .toList(growable: false);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    await Navigator.of(context).push<bool>(
      FinanceEntryRoute(
        reduceMotion: reduceMotion,
        builder: (_) => RiverpodTransactionEntryScreen(
          categories: options,
          initialTransaction: transaction,
        ),
      ),
    );
    if (context.mounted) {
      await ref.read(ledgerStateProvider.notifier).refresh();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry transaction,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text(
          'This removes it from your balance and reports. This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(ledgerStateProvider.notifier).delete(transaction.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this transaction')),
      );
    }
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => SurfaceGroup(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('history_previous_month'),
              tooltip: 'Previous month',
              onPressed: onPrevious,
              icon: const Icon(CupertinoIcons.chevron_left, size: 19),
            ),
            Expanded(
              child: Text(
                formatMonth(month),
                textAlign: TextAlign.center,
                style: AppTheme.section,
              ),
            ),
            IconButton(
              key: const ValueKey('history_next_month'),
              tooltip: 'Next month',
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(CupertinoIcons.chevron_right, size: 19),
            ),
          ],
        ),
      ),
    ],
  );
}

enum _TransactionAction { edit, delete }
