import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              'Transaction history',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            Text(
              'Every local entry, in one place',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              scrollDirection: Axis.horizontal,
              children: LedgerTypeFilter.values
                  .map((filter) {
                    final selected = state.filter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: ValueKey('ledger_filter_${filter.name}'),
                        selected: selected,
                        showCheckmark: false,
                        label: Text(_filterLabel(filter)),
                        avatar: Icon(_filterIcon(filter), size: 17),
                        onSelected: (_) => ref
                            .read(ledgerStateProvider.notifier)
                            .setFilter(filter),
                        selectedColor: const Color(0xFFDCEAE4),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF5B8E7B)
                              : const Color(0xFFE1E6DF),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          Expanded(child: _LedgerBody(state: state)),
        ],
      ),
    );
  }

  String _filterLabel(LedgerTypeFilter filter) => switch (filter) {
    LedgerTypeFilter.all => 'All',
    LedgerTypeFilter.income => 'Income',
    LedgerTypeFilter.expense => 'Expense',
  };

  IconData _filterIcon(LedgerTypeFilter filter) => switch (filter) {
    LedgerTypeFilter.all => Icons.swap_vert_rounded,
    LedgerTypeFilter.income => Icons.south_west_rounded,
    LedgerTypeFilter.expense => Icons.north_east_rounded,
  };
}

class _LedgerBody extends ConsumerWidget {
  const _LedgerBody({required this.state});

  final LedgerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.status == LedgerLoadStatus.loading &&
        state.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == LedgerLoadStatus.failure &&
        state.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            const Text('Could not load transaction history'),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => ref.read(ledgerStateProvider.notifier).refresh(),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (state.transactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(ledgerStateProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.receipt_long_outlined, size: 46, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              'No matching transactions',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    final groups = _groupByDay(state.transactions);
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: () => ref.read(ledgerStateProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == groups.length - 1 ? 0 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatLedgerDate(group.date, now),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${group.transactions.length} ${group.transactions.length == 1 ? 'entry' : 'entries'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ...group.transactions.map(
                  (transaction) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TransactionListTile(transaction: transaction),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_TransactionDayGroup> _groupByDay(List<TransactionEntry> transactions) {
    final groups = <_TransactionDayGroup>[];
    for (final transaction in transactions) {
      final timestamp = transaction.timestamp;
      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
      if (groups.isEmpty || groups.last.date != day) {
        groups.add(_TransactionDayGroup(day, [transaction]));
      } else {
        groups.last.transactions.add(transaction);
      }
    }
    return groups;
  }
}

class _TransactionDayGroup {
  _TransactionDayGroup(this.date, this.transactions);

  final DateTime date;
  final List<TransactionEntry> transactions;
}
