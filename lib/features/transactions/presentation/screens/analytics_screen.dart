import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
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
  int? _selectedCategoryId;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsStateProvider);
    final selectedIndex = state.categories.indexWhere(
      (item) => item.categoryId == _selectedCategoryId,
    );
    final selected = selectedIndex < 0 ? null : state.categories[selectedIndex];
    return FinancePage(
      title: 'Analytics',
      subtitle: 'See where your money goes',
      onRefresh: () => ref.read(analyticsStateProvider.notifier).refresh(),
      children: [
        FinanceSegments<AnalyticsPeriod>(
          value: state.period,
          keyPrefix: 'analytics_period',
          labels: const {
            AnalyticsPeriod.thisWeek: 'This Week',
            AnalyticsPeriod.thisMonth: 'This Month',
          },
          onChanged: (period) {
            setState(() => _selectedCategoryId = null);
            ref.read(analyticsStateProvider.notifier).setPeriod(period);
          },
        ),
        const SizedBox(height: 24),
        if (state.status == AnalyticsLoadStatus.loading &&
            state.categories.isEmpty)
          const FinanceLoading()
        else if (state.status == AnalyticsLoadStatus.failure)
          FinanceEmptyState(
            icon: CupertinoIcons.exclamationmark_circle,
            title: 'Could not calculate expense analytics',
            message: 'Pull down to try again.',
            onRetry: () => ref.read(analyticsStateProvider.notifier).refresh(),
          )
        else if (state.categories.isEmpty)
          const FinanceEmptyState(
            icon: CupertinoIcons.chart_pie,
            title: 'No expenses in this period',
            message: 'Add an expense to see your spending breakdown.',
          )
        else ...[
          SurfaceGroup(
            separated: false,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: Column(
                  children: [
                    Text(
                      '${formatShortDate(state.range.start)} – ${formatShortDate(state.range.end.subtract(const Duration(days: 1)))}',
                      style: AppTheme.caption,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selected?.categoryName ?? 'Total expenses',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final diameter = math.min(constraints.maxWidth, 250.0);
                    return Center(
                      child: SizedBox.square(
                        dimension: diameter,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Semantics(
                              label:
                                  'Expense breakdown. Select a category below for details.',
                              child: ExcludeSemantics(
                                child: PieChart(
                                  PieChartData(
                                    centerSpaceRadius: diameter * 0.35,
                                    sectionsSpace: 3,
                                    startDegreeOffset: -90,
                                    borderData: FlBorderData(show: false),
                                    pieTouchData: PieTouchData(
                                      touchCallback: (event, response) {
                                        if (event is! FlTapUpEvent) return;
                                        final index =
                                            response
                                                ?.touchedSection
                                                ?.touchedSectionIndex ??
                                            -1;
                                        setState(
                                          () => _selectedCategoryId =
                                              index >= 0 &&
                                                  index <
                                                      state.categories.length
                                              ? state
                                                    .categories[index]
                                                    .categoryId
                                              : null,
                                        );
                                      },
                                    ),
                                    sections: state.categories.indexed
                                        .map(
                                          (entry) => PieChartSectionData(
                                            value: entry.$2.amount,
                                            color: Color(
                                              entry.$2.categoryColor,
                                            ),
                                            showTitle: false,
                                            radius:
                                                diameter *
                                                (entry.$1 == selectedIndex
                                                    ? 0.125
                                                    : 0.105),
                                            cornerRadius: 3,
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                  duration: AppTheme.motion(context, 350),
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: SizedBox(
                                width: diameter * 0.62,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('MMK', style: AppTheme.caption),
                                    const SizedBox(height: 5),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        formatMoney(
                                          selected?.amount ??
                                              state.totalExpense,
                                          currencyCode: '',
                                        ).trim(),
                                        key: const ValueKey('analytics_total'),
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -1,
                                          fontFeatures: AppTheme.numbers,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeading('Spending by category'),
          SurfaceGroup(
            separatorInset: 68,
            children: [
              for (final item in state.categories)
                _CategoryRow(
                  spending: item,
                  total: state.totalExpense,
                  selected: item.categoryId == _selectedCategoryId,
                  onTap: () => setState(
                    () => _selectedCategoryId =
                        item.categoryId == _selectedCategoryId
                        ? null
                        : item.categoryId,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.spending,
    required this.total,
    required this.selected,
    required this.onTap,
  });
  final CategorySpending spending;
  final double total;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = Color(spending.categoryColor);
    final share = total == 0 ? 0.0 : spending.amount / total;
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: AppTheme.motion(context),
        color: selected ? AppTheme.accentSoft : AppTheme.surface,
        child: CupertinoButton(
          onPressed: onTap,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categoryIconFromKey(spending.categoryIcon),
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spending.categoryName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${spending.transactionCount} ${spending.transactionCount == 1 ? 'transaction' : 'transactions'}',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatMoney(spending.amount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                          fontFeatures: AppTheme.numbers,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(share * 100).toStringAsFixed(1)}%',
                      style: AppTheme.caption,
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
