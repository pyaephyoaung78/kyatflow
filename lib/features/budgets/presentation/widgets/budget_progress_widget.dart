import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../../transactions/presentation/utils/finance_formatters.dart';
import '../../domain/entities/budget.dart';
import '../providers/budget_providers.dart';

class MonthlyBudgetProgressSection extends ConsumerWidget {
  const MonthlyBudgetProgressSection({required this.activeMonth, super.key});
  final DateTime activeMonth;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = DateTime(activeMonth.year, activeMonth.month);
    final progress = ref.watch(monthlyBudgetProgressProvider(month));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Monthly budgets'),
        progress.when(
          loading: () => const FinanceLoading(),
          error: (_, _) => FinanceEmptyState(
            icon: CupertinoIcons.exclamationmark_circle,
            title: 'Could not load monthly budgets',
            message: 'Try loading your local records again.',
            onRetry: () => ref.invalidate(monthlyBudgetProgressProvider(month)),
          ),
          data: (items) => SurfaceGroup(
            children: items.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.chart_bar,
                            size: 22,
                            color: AppTheme.secondary,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No category budgets set for this month.',
                              style: AppTheme.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                : [
                    for (final item in items)
                      BudgetProgressWidget(progress: item),
                  ],
          ),
        ),
      ],
    );
  }
}

class BudgetProgressWidget extends StatelessWidget {
  const BudgetProgressWidget({required this.progress, super.key});
  final BudgetProgress progress;
  @override
  Widget build(BuildContext context) {
    final color = switch (progress.warningState) {
      BudgetWarningState.safe => AppTheme.accent,
      BudgetWarningState.warning => AppTheme.warning,
      BudgetWarningState.exceeded => AppTheme.expense,
    };
    final status = switch (progress.warningState) {
      BudgetWarningState.safe => '${formatMoney(progress.remaining)} left',
      BudgetWarningState.warning => 'Approaching limit',
      BudgetWarningState.exceeded =>
        '${formatMoney(progress.actualSpent - progress.amountLimit)} over',
    };
    return Semantics(
      label:
          '${progress.categoryName} budget, ${progress.progressPercentage.round()} percent used, $status',
      child: Container(
        key: ValueKey('budget_progress_${progress.budgetId}'),
        color: AppTheme.surface,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress.categoryName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${progress.progressPercentage.toStringAsFixed(0)}%',
                  key: ValueKey('budget_percentage_${progress.budgetId}'),
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTheme.numbers,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${formatMoney(progress.actualSpent)} of ${formatMoney(progress.amountLimit)}',
              style: AppTheme.caption,
            ),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.progress),
              duration: AppTheme.motion(context, 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
                color: color,
                backgroundColor: AppTheme.line,
                semanticsLabel: 'Budget used',
              ),
            ),
            const SizedBox(height: 10),
            Text(status, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
