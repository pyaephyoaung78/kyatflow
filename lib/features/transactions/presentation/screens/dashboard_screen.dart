import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backup/csv_backup_service.dart';
import '../../../budgets/presentation/widgets/budget_progress_widget.dart';
import '../../domain/entities/transaction_category.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F1),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KyatFlow',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(
              'Your money, kept locally',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('export_csv'),
            tooltip: 'Export CSV backup',
            onPressed: _isExporting ? null : _exportBackup,
            icon: _isExporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _DashboardBody(
        state: state,
        onRefresh: () => ref.read(dashboardStateProvider.notifier).refresh(),
        onTransactionTap: (transaction) => _openEntry(
          categories: state.categories,
          initialTransaction: transaction,
        ),
      ),
    );
  }

  Future<void> _openEntry({
    required List<TransactionCategory> categories,
    TransactionEntry? initialTransaction,
  }) async {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categories are still loading. Try again.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
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
          initialTransaction: initialTransaction,
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

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.state,
    required this.onRefresh,
    required this.onTransactionTap,
  });

  final DashboardState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<TransactionEntry> onTransactionTap;

  @override
  Widget build(BuildContext context) {
    if (state.status == DashboardLoadStatus.loading &&
        state.recentTransactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == DashboardLoadStatus.failure &&
        state.recentTransactions.isEmpty) {
      return _LoadError(onRetry: onRefresh);
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Text(
            formatMonth(state.activeMonth),
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _BalanceCard(balance: state.summary.currentBalance),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Monthly income',
                  amount: state.summary.totalIncome,
                  color: const Color(0xFF16866B),
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Monthly expenses',
                  amount: state.summary.totalExpense,
                  color: const Color(0xFFE85D4A),
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Recent transactions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (state.recentTransactions.isEmpty)
            const _EmptyRecent()
          else
            ...state.recentTransactions.map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: TransactionListTile(
                  transaction: transaction,
                  showDate: true,
                  onTap: () => onTransactionTap(transaction),
                ),
              ),
            ),
          const SizedBox(height: 19),
          MonthlyBudgetProgressSection(activeMonth: state.activeMonth),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF183D32), Color(0xFF2E6755)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x25183D32),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
                size: 18,
              ),
              SizedBox(width: 7),
              Text('Total balance', style: TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(balance),
              key: const ValueKey('total_balance'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 13),
          Text(
            label,
            style: const TextStyle(color: Colors.black45, fontSize: 12),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(amount),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 38, color: Colors.black26),
          SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Add your first income or expense to begin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.black38),
          const SizedBox(height: 12),
          const Text('Could not load your local data'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
