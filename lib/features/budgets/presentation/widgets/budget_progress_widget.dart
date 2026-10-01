import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/presentation/utils/category_icon_mapper.dart';
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
        const Text(
          'Monthly budgets',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        progress.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, _) => _BudgetLoadError(
            onRetry: () => ref.invalidate(monthlyBudgetProgressProvider(month)),
          ),
          data: (items) => items.isEmpty
              ? const _EmptyBudgets()
              : Column(
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BudgetProgressWidget(progress: item),
                      ),
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
    final categoryColor = Color(progress.categoryColor);
    final stateColor = switch (progress.warningState) {
      BudgetWarningState.safe => categoryColor,
      BudgetWarningState.warning => const Color(0xFFE59A13),
      BudgetWarningState.exceeded => const Color(0xFFD84D4D),
    };
    final status = switch (progress.warningState) {
      BudgetWarningState.safe => '${formatMoney(progress.remaining)} left',
      BudgetWarningState.warning => 'Approaching limit',
      BudgetWarningState.exceeded =>
        '${formatMoney(progress.actualSpent - progress.amountLimit)} over',
    };

    return Semantics(
      label:
          '${progress.categoryName} budget, ${progress.progressPercentage.toStringAsFixed(0)} percent used, $status',
      child: Container(
        key: ValueKey('budget_progress_${progress.budgetId}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: stateColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    categoryIconFromKey(progress.categoryIcon),
                    color: categoryColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.categoryName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatMoney(progress.actualSpent)} of ${formatMoney(progress.amountLimit)}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${progress.progressPercentage.toStringAsFixed(0)}%',
                    key: ValueKey('budget_percentage_${progress.budgetId}'),
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 8,
                color: stateColor,
                backgroundColor: const Color(0xFFE8ECE9),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                status,
                style: TextStyle(
                  color: stateColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.savings_outlined, color: Colors.black38),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No category budgets set for this month.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetLoadError extends StatelessWidget {
  const _BudgetLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Expanded(child: Text('Could not load monthly budgets.')),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
