import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/category_spending.dart';
import '../providers/transaction_providers.dart';
import '../state/analytics_state.dart';
import '../utils/category_icon_mapper.dart';
import '../utils/finance_formatters.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsStateProvider);
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
              'Analytics',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            Text(
              'See where your money goes',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _PeriodSelector(
              selected: state.period,
              onSelected: (period) {
                setState(() => _touchedIndex = -1);
                ref.read(analyticsStateProvider.notifier).setPeriod(period);
              },
            ),
          ),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(AnalyticsState state) {
    if (state.status == AnalyticsLoadStatus.loading &&
        state.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == AnalyticsLoadStatus.failure &&
        state.categories.isEmpty) {
      return _AnalyticsError(
        onRetry: () => ref.read(analyticsStateProvider.notifier).refresh(),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(analyticsStateProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            _rangeLabel(state),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (state.categories.isEmpty)
            const _EmptyAnalytics()
          else ...[
            _DonutCard(
              state: state,
              touchedIndex: _touchedIndex,
              onTouched: (index) => setState(() => _touchedIndex = index),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Spending by category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${state.categories.length} categories',
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...state.categories.indexed.map(
              (indexed) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _RankedCategoryRow(
                  rank: indexed.$1 + 1,
                  spending: indexed.$2,
                  total: state.totalExpense,
                  selected: indexed.$1 == _touchedIndex,
                  onTap: () => setState(() => _touchedIndex = indexed.$1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _rangeLabel(AnalyticsState state) {
    final end = state.range.end.subtract(const Duration(days: 1));
    return '${formatShortDate(state.range.start)} – ${formatShortDate(end)}';
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E9E4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: AnalyticsPeriod.values
            .map((period) {
              final isSelected = selected == period;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 9,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: InkWell(
                    key: ValueKey('analytics_period_${period.name}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelected(period),
                    child: Center(
                      child: Text(
                        period == AnalyticsPeriod.thisWeek
                            ? 'This Week'
                            : 'This Month',
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF183D32)
                              : Colors.black45,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.state,
    required this.touchedIndex,
    required this.onTouched,
  });

  final AnalyticsState state;
  final int touchedIndex;
  final ValueChanged<int> onTouched;

  @override
  Widget build(BuildContext context) {
    final selected = touchedIndex >= 0 && touchedIndex < state.categories.length
        ? state.categories[touchedIndex]
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E9E4)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 66,
                    centerSpaceColor: Colors.white,
                    sectionsSpace: 3,
                    startDegreeOffset: -90,
                    borderData: FlBorderData(show: false),
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          onTouched(-1);
                          return;
                        }
                        onTouched(
                          response!.touchedSection!.touchedSectionIndex,
                        );
                      },
                    ),
                    sections: state.categories.indexed
                        .map((indexed) {
                          final index = indexed.$1;
                          final item = indexed.$2;
                          final isTouched = index == touchedIndex;
                          final percentage =
                              item.amount / state.totalExpense * 100;
                          return PieChartSectionData(
                            value: item.amount,
                            color: Color(item.categoryColor),
                            radius: isTouched ? 60 : 52,
                            cornerRadius: 5,
                            title: percentage >= 8
                                ? '${percentage.round()}%'
                                : '',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected?.categoryName ?? 'Expenses',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatMoney(selected?.amount ?? state.totalExpense),
                      key: const ValueKey('analytics_total'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a segment to inspect it',
            style: TextStyle(color: Colors.black38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RankedCategoryRow extends StatelessWidget {
  const _RankedCategoryRow({
    required this.rank,
    required this.spending,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final int rank;
  final CategorySpending spending;
  final double total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(spending.categoryColor);
    final share = total == 0 ? 0.0 : spending.amount / total;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.09) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.55)
              : const Color(0xFFE8EBE7),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.black38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  categoryIconFromKey(spending.categoryIcon),
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            spending.categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          formatMoney(spending.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 5,
                        color: color,
                        backgroundColor: const Color(0xFFE9ECE8),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${(share * 100).toStringAsFixed(1)}% · '
                      '${spending.transactionCount} '
                      '${spending.transactionCount == 1 ? 'transaction' : 'transactions'}',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 70),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          Icon(Icons.donut_large_rounded, size: 48, color: Colors.black26),
          SizedBox(height: 14),
          Text(
            'No expenses in this period',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 5),
          Text(
            'Expense categories will appear here after you add transactions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Colors.black38,
          ),
          const SizedBox(height: 12),
          const Text('Could not calculate expense analytics'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
