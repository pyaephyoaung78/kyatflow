import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../../transactions/presentation/utils/finance_formatters.dart';
import '../../domain/entities/budget.dart';
import '../providers/budget_providers.dart';

class MonthlyBudgetProgressSection extends ConsumerWidget {
  const MonthlyBudgetProgressSection({
    required this.activeMonth,
    required this.onManage,
    super.key,
  });
  final DateTime activeMonth;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = DateTime(activeMonth.year, activeMonth.month);
    final progress = ref.watch(monthlyBudgetProgressProvider(month));
    final income = ref.watch(monthlyBudgetIncomeProvider(month));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Monthly budgets', style: AppTheme.section),
              ),
              CupertinoButton(
                key: const ValueKey('manage_monthly_budgets'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: onManage,
                child: const Text(
                  'Manage',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        progress.when(
          loading: () => const FinanceLoading(),
          error: (_, _) => FinanceEmptyState(
            icon: CupertinoIcons.exclamationmark_circle,
            title: 'Could not load monthly budgets',
            message: 'Try loading your local records again.',
            onRetry: () => ref.invalidate(monthlyBudgetProgressProvider(month)),
          ),
          data: (items) {
            final planned = items.fold<double>(
              0,
              (total, item) => total + item.amountLimit,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BudgetPlanSummaryWidget(
                  totalPlanned: planned,
                  monthlyIncome: income.asData?.value,
                ),
                const SizedBox(height: 12),
                SurfaceGroup(
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
              ],
            );
          },
        ),
      ],
    );
  }
}

class BudgetPlanSummaryWidget extends StatelessWidget {
  const BudgetPlanSummaryWidget({
    required this.totalPlanned,
    required this.monthlyIncome,
    super.key,
  });

  final double totalPlanned;
  final double? monthlyIncome;

  @override
  Widget build(BuildContext context) {
    final income = monthlyIncome;
    final remaining = income == null ? null : income - totalPlanned;
    final overPlanned = remaining != null && remaining < 0;
    return Semantics(
      container: true,
      label: income == null
          ? 'Total planned budget, ${formatMoney(totalPlanned)}'
          : 'Total planned budget, ${formatMoney(totalPlanned)}. '
                '${overPlanned ? 'Over planned' : 'Unallocated salary'}, '
                '${formatMoney(remaining!.abs())}.',
      child: SurfaceGroup(
        separated: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total planned budget', style: AppTheme.caption),
                const SizedBox(height: 8),
                Text(
                  formatMoney(totalPlanned),
                  key: const ValueKey('total_planned_budget'),
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    color: AppTheme.ink,
                    fontFeatures: AppTheme.numbers,
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 22, endIndent: 22),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PlanMetric(label: 'Monthly income', amount: income),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _PlanMetric(
                    label: overPlanned ? 'Over planned' : 'Unallocated salary',
                    amount: remaining?.abs(),
                    color: overPlanned ? AppTheme.expense : AppTheme.accent,
                    valueKey: const ValueKey('unallocated_salary'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({
    required this.label,
    required this.amount,
    this.color = AppTheme.ink,
    this.valueKey,
  });

  final String label;
  final double? amount;
  final Color color;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTheme.caption),
      const SizedBox(height: 6),
      if (amount == null)
        const CupertinoActivityIndicator(radius: 8)
      else
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(amount!),
            key: valueKey,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTheme.numbers,
            ),
          ),
        ),
    ],
  );
}

class BudgetProgressWidget extends StatelessWidget {
  const BudgetProgressWidget({required this.progress, this.onTap, super.key});
  final BudgetProgress progress;
  final VoidCallback? onTap;
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
    final content = Container(
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
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  size: 14,
                  color: AppTheme.secondary,
                ),
              ],
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
    );
    return Semantics(
      label:
          '${progress.categoryName} budget, ${progress.progressPercentage.round()} percent used, $status',
      button: onTap != null,
      child: onTap == null
          ? content
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onTap,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: AppTheme.ink),
                child: content,
              ),
            ),
    );
  }
}
