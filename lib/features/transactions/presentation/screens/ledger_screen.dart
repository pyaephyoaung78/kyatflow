import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../domain/entities/transaction_entry.dart';
import '../providers/transaction_providers.dart';
import '../state/ledger_state.dart';
import '../utils/finance_formatters.dart';
import '../widgets/transaction_list_tile.dart';

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ledgerStateProvider);
    final groups = <DateTime, List<TransactionEntry>>{};
    for (final transaction in state.transactions) {
      final t = transaction.timestamp;
      final day = DateTime(t.year, t.month, t.day);
      (groups[day] ??= []).add(transaction);
    }
    return FinancePage(
      title: 'Transaction history',
      onRefresh: () => ref.read(ledgerStateProvider.notifier).refresh(),
      children: [
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
        const SizedBox(height: 24),
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
          const FinanceEmptyState(
            icon: CupertinoIcons.doc_text,
            title: 'No matching transactions',
            message: 'Your entries will appear here, organized by date.',
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
                  TransactionListTile(transaction: transaction),
              ],
            ),
            const SizedBox(height: 24),
          ],
      ],
    );
  }
}
