import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_entry_route.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../domain/entities/transaction_category.dart';
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
    final categories = ref.watch(managedCategoriesProvider(true));
    final categoryItems = categories.asData?.value ?? const [];
    final selectedCategory = categoryItems
        .where((category) => category.id == state.categoryId)
        .firstOrNull;
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
          customStart: state.customStart,
          customEnd: state.customEnd,
          onPrevious: state.hasCustomDateRange
              ? null
              : () =>
                    ref.read(ledgerStateProvider.notifier).showPreviousMonth(),
          onNext: state.hasCustomDateRange || !state.canGoNext
              ? null
              : () => ref.read(ledgerStateProvider.notifier).showNextMonth(),
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
          onChanged: (value) async {
            final category = selectedCategory;
            final transactionType = value.transactionType;
            if (category != null &&
                transactionType != null &&
                category.type != transactionType) {
              await ref.read(ledgerStateProvider.notifier).setCategory(null);
            }
            await ref.read(ledgerStateProvider.notifier).setFilter(value);
          },
        ),
        const SizedBox(height: 12),
        _HistoryFilterBar(
          dateLabel: state.hasCustomDateRange
              ? formatDateRange(state.customStart!, state.customEnd!)
              : 'Date',
          categoryLabel: selectedCategory?.name ?? 'Category',
          dateActive: state.hasCustomDateRange,
          categoryActive: state.categoryId != null,
          onDateTap: () => _showDateFilter(context, ref, state),
          onCategoryTap: () => _showCategoryFilter(context, ref, state),
          onClear: state.activeFilterCount == 0
              ? null
              : () => ref
                    .read(ledgerStateProvider.notifier)
                    .clearAdvancedFilters(),
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
            title: state.hasCustomDateRange
                ? 'No transactions from '
                      '${formatDateRange(state.customStart!, state.customEnd!)}'
                : 'No transactions in ${formatMonth(state.activeMonth)}',
            message: state.activeFilterCount > 0
                ? 'Clear a filter or choose a different date range.'
                : 'Try another month or add a new entry.',
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

  Future<void> _showDateFilter(
    BuildContext context,
    WidgetRef ref,
    LedgerState state,
  ) async {
    final action = await showCupertinoModalPopup<_DateFilterAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filter by date'),
        message: const Text('Choose a quick range or select exact dates.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(context, _DateFilterAction.entireMonth),
            child: Text('Entire ${formatMonth(state.activeMonth)}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _DateFilterAction.today),
            child: const Text('Today'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(context, _DateFilterAction.lastSevenDays),
            child: const Text('Last 7 days'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _DateFilterAction.custom),
            child: const Text('Choose date range'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final notifier = ref.read(ledgerStateProvider.notifier);
    switch (action) {
      case _DateFilterAction.entireMonth:
        await notifier.clearDateRange();
        return;
      case _DateFilterAction.today:
        await notifier.showToday();
        return;
      case _DateFilterAction.lastSevenDays:
        await notifier.showLastSevenDays();
        return;
      case _DateFilterAction.custom:
        final now = DateTime.now();
        final initialStart = state.customStart ?? state.activeMonth;
        final initialEnd = state.customEnd?.subtract(const Duration(days: 1));
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year + 1, 12, 31),
          initialDateRange: DateTimeRange(
            start: initialStart,
            end: initialEnd ?? initialStart,
          ),
          helpText: 'Choose transaction dates',
          saveText: 'Apply',
        );
        if (range != null) {
          await notifier.setDateRange(range.start, range.end);
        }
        return;
    }
  }

  Future<void> _showCategoryFilter(
    BuildContext context,
    WidgetRef ref,
    LedgerState state,
  ) async {
    try {
      final categories = await ref
          .read(transactionRepositoryProvider)
          .getCategories(includeArchived: true);
      if (!context.mounted) return;
      final transactionType = state.filter.transactionType;
      final available = categories
          .where(
            (category) =>
                transactionType == null || category.type == transactionType,
          )
          .toList(growable: false);
      final selected = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: AppTheme.background,
        showDragHandle: true,
        builder: (context) => _CategoryFilterSheet(
          categories: available,
          selectedId: state.categoryId,
          showType: transactionType == null,
        ),
      );
      if (selected == null) return;
      await ref
          .read(ledgerStateProvider.notifier)
          .setCategory(selected == _allCategoriesId ? null : selected);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load categories')),
      );
    }
  }

  Future<void> _showTransactionActions(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry transaction,
  ) async {
    final note = transaction.note?.trim();
    final action = await showCupertinoModalPopup<_TransactionAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(transaction.categoryName ?? 'Transaction'),
        message: Text(
          '${formatMoney(transaction.amount)} · '
          '${formatShortDate(transaction.timestamp)}'
          '${note == null || note.isEmpty ? '' : '\n$note'}',
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
    required this.customStart,
    required this.customEnd,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoNext;
  final DateTime? customStart;
  final DateTime? customEnd;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

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
                customStart != null && customEnd != null
                    ? formatDateRange(customStart!, customEnd!)
                    : formatMonth(month),
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

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.dateLabel,
    required this.categoryLabel,
    required this.dateActive,
    required this.categoryActive,
    required this.onDateTap,
    required this.onCategoryTap,
    required this.onClear,
  });

  final String dateLabel;
  final String categoryLabel;
  final bool dateActive;
  final bool categoryActive;
  final VoidCallback onDateTap;
  final VoidCallback onCategoryTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _FilterButton(
          key: const ValueKey('history_date_filter'),
          icon: CupertinoIcons.calendar,
          label: dateLabel,
          active: dateActive,
          onTap: onDateTap,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _FilterButton(
          key: const ValueKey('history_category_filter'),
          icon: CupertinoIcons.square_grid_2x2,
          label: categoryLabel,
          active: categoryActive,
          onTap: onCategoryTap,
        ),
      ),
      if (onClear != null) ...[
        const SizedBox(width: 4),
        CupertinoButton(
          key: const ValueKey('clear_history_filters'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          onPressed: onClear,
          child: const Text('Clear', style: TextStyle(fontSize: 13)),
        ),
      ],
    ],
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppTheme.motion(context, 180),
    decoration: BoxDecoration(
      color: active ? AppTheme.accentSoft : AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: active ? AppTheme.accent : AppTheme.secondary,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? AppTheme.accent : AppTheme.ink,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryFilterSheet extends StatelessWidget {
  const _CategoryFilterSheet({
    required this.categories,
    required this.selectedId,
    required this.showType,
  });

  final List<TransactionCategory> categories;
  final int? selectedId;
  final bool showType;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.68,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Text('Filter by category', style: AppTheme.section),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                _CategoryFilterRow(
                  key: const ValueKey('history_category_all'),
                  icon: CupertinoIcons.square_grid_2x2,
                  title: 'All categories',
                  selected: selectedId == null,
                  onTap: () => Navigator.pop(context, _allCategoriesId),
                ),
                for (final category in categories)
                  _CategoryFilterRow(
                    key: ValueKey('history_category_${category.id}'),
                    icon: categoryIconFromKey(category.icon),
                    title: category.name,
                    subtitle: showType
                        ? (category.type == TransactionType.income
                              ? 'Income'
                              : 'Expense')
                        : null,
                    selected: selectedId == category.id,
                    onTap: () => Navigator.pop(context, category.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTheme.caption),
                ],
              ],
            ),
          ),
          if (selected)
            const Icon(
              CupertinoIcons.check_mark,
              size: 18,
              color: AppTheme.accent,
            ),
        ],
      ),
    ),
  );
}

const _allCategoriesId = -1;

enum _DateFilterAction { entireMonth, today, lastSevenDays, custom }

enum _TransactionAction { edit, delete }
