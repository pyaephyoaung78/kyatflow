import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/features/budgets/domain/entities/budget.dart';
import 'package:kyatflow/features/budgets/presentation/widgets/budget_progress_widget.dart';

void main() {
  testWidgets('shows exceeded budget amount and clamped visual progress', (
    tester,
  ) async {
    const progress = BudgetProgress(
      budgetId: 7,
      categoryId: 2,
      categoryName: 'Food',
      categoryIcon: 'restaurant',
      categoryColor: 0xFFFF9800,
      amountLimit: 200,
      actualSpent: 250,
      month: 10,
      year: 2026,
      alertPercentage: 80,
      progressPercentage: 125,
      warningState: BudgetWarningState.exceeded,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: BudgetProgressWidget(progress: progress),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('MMK 250 of MMK 200'), findsOneWidget);
    expect(find.text('125%'), findsOneWidget);
    expect(find.text('MMK 50 over'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 1);
  });
}
