import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/backup/csv_backup_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_entry_route.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../../budgets/presentation/widgets/budget_progress_widget.dart';
import '../../domain/entities/transaction_entry.dart';
import '../models/transaction_category_option.dart';
import '../providers/transaction_providers.dart';
import '../state/dashboard_state.dart';
import '../utils/category_icon_mapper.dart';
import '../utils/finance_formatters.dart';
import '../widgets/transaction_list_tile.dart';
import 'transaction_entry_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isExporting = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardStateProvider);
    return FinancePage(
      title: 'KyatFlow',
      subtitle: formatMonth(state.activeMonth),
      onRefresh: () => ref.read(dashboardStateProvider.notifier).refresh(),
      trailing: IconButton(
        key: const ValueKey('export_csv'),
        tooltip: 'Export CSV backup',
        onPressed: _isExporting ? null : _exportBackup,
        icon: _isExporting
            ? const CupertinoActivityIndicator()
            : const Icon(CupertinoIcons.square_arrow_up, size: 23),
      ),
      children: [
        if (state.status == DashboardLoadStatus.loading &&
            state.recentTransactions.isEmpty)
          const FinanceLoading()
        else if (state.status == DashboardLoadStatus.failure &&
            state.recentTransactions.isEmpty)
          FinanceEmptyState(
            icon: CupertinoIcons.exclamationmark_circle,
            title: 'Could not load your local data',
            message: 'Pull down to try again.',
            onRetry: () => ref.read(dashboardStateProvider.notifier).refresh(),
          )
        else ...[
          _Overview(state: state),
          const SizedBox(height: 28),
          const SectionHeading('Recent transactions'),
          SurfaceGroup(
            separatorInset: 68,
            children: state.recentTransactions.isEmpty
                ? [
                    const FinanceEmptyState(
                      icon: CupertinoIcons.doc_text,
                      title: 'No transactions yet',
                      message: 'Tap + to add your first income or expense.',
                    ),
                  ]
                : [
                    for (final transaction in state.recentTransactions)
                      TransactionListTile(
                        transaction: transaction,
                        showDate: true,
                        onTap: () => _openEntry(transaction),
                      ),
                  ],
          ),
          const SizedBox(height: 28),
          MonthlyBudgetProgressSection(activeMonth: state.activeMonth),
        ],
      ],
    );
  }

  Future<void> _openEntry(TransactionEntry transaction) async {
    final categories = ref.read(dashboardStateProvider).categories;
    if (categories.isEmpty) return;
    await Navigator.of(context).push<bool>(
      FinanceEntryRoute(
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        builder: (_) => RiverpodTransactionEntryScreen(
          categories: categories
              .map(
                (category) => TransactionCategoryOption(
                  id: category.id,
                  name: category.name,
                  icon: categoryIconFromKey(category.icon),
                  color: Color(category.color),
                  type: category.type,
                ),
              )
              .toList(growable: false),
          initialTransaction: transaction,
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _isExporting = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      final result = await ref
          .read(csvBackupServiceProvider)
          .createAndShare(
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup created: ${result.file.path.split('/').last}'),
        ),
      );
    } on BackupShareException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved locally: ${error.file.path}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not export the backup. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.state});
  final DashboardState state;
  @override
  Widget build(BuildContext context) => SurfaceGroup(
    separated: false,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total balance', style: AppTheme.caption),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMoney(state.summary.currentBalance),
                  key: const ValueKey('total_balance'),
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.8,
                    fontFeatures: AppTheme.numbers,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(indent: 24, endIndent: 24),
      Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final income = _Metric(
              label: 'Monthly income',
              amount: state.summary.totalIncome,
              income: true,
            );
            final expense = _Metric(
              label: 'Monthly expenses',
              amount: state.summary.totalExpense,
              income: false,
            );
            if (MediaQuery.textScalerOf(context).scale(14) > 21) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [income, const SizedBox(height: 20), expense],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: income),
                const SizedBox(width: 20),
                Expanded(child: expense),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.amount,
    required this.income,
  });
  final String label;
  final double amount;
  final bool income;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            income
                ? CupertinoIcons.arrow_down_left
                : CupertinoIcons.arrow_up_right,
            size: 14,
            color: income ? AppTheme.accent : AppTheme.expense,
          ),
          const SizedBox(width: 5),
          Expanded(child: Text(label, style: AppTheme.caption)),
        ],
      ),
      const SizedBox(height: 8),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatMoney(amount),
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontFeatures: AppTheme.numbers,
          ),
        ),
      ),
    ],
  );
}
