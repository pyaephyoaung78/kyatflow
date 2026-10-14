import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/theme/app_theme.dart';
import 'package:kyatflow/features/recurring/domain/entities/recurring_rule.dart';
import 'package:kyatflow/features/recurring/domain/repositories/recurring_rule_repository.dart';
import 'package:kyatflow/features/recurring/presentation/providers/recurring_rule_providers.dart';
import 'package:kyatflow/features/recurring/presentation/screens/recurring_rules_screen.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_entry.dart';
import 'package:kyatflow/features/transactions/presentation/providers/transaction_providers.dart';

import '../../support/finance_fixtures.dart';

void main() {
  testWidgets('shows, pauses, and opens a recurring transaction', (
    tester,
  ) async {
    final repository = _FakeRecurringRuleRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            TestTransactionRepository(),
          ),
          recurringRuleRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RecurringRulesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home internet'), findsOneWidget);
    expect(find.text('30,000 Mmk · Monthly'), findsOneWidget);
    expect(find.text('Next Nov 1, 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recurring_toggle_1')));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Paused · Next Nov 1, 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recurring_rule_1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit recurring transaction'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Fiber plan'), findsOneWidget);
    expect(find.text('First due date'), findsOneWidget);
    expect(find.text('Next transaction'), findsOneWidget);
  });
}

class _FakeRecurringRuleRepository implements RecurringRuleRepository {
  final _controller = StreamController<int>.broadcast(sync: true);
  var _revision = 0;
  var _rules = <RecurringRule>[
    RecurringRule(
      id: 1,
      name: 'Home internet',
      amount: 30000,
      categoryId: 2,
      type: TransactionType.expense,
      frequency: RecurringFrequency.monthly,
      firstDue: DateTime(2026, 11, 1),
      nextDue: DateTime(2026, 11, 1),
      isActive: true,
      note: 'Fiber plan',
      categoryName: 'Food',
      categoryIcon: 'restaurant',
      categoryColor: 0xFFFF9800,
    ),
  ];

  @override
  Stream<int> get changes => _controller.stream;

  @override
  Future<List<RecurringRule>> getAll() async => List.unmodifiable(_rules);

  @override
  Future<int> insert(RecurringRuleDraft rule) async => 2;

  @override
  Future<void> edit(RecurringRule rule) async {
    _rules = [
      for (final item in _rules)
        if (item.id == rule.id) rule else item,
    ];
    _publish();
  }

  @override
  Future<void> setActive(int id, {required bool active}) async {
    _rules = [
      for (final rule in _rules)
        if (rule.id == id)
          RecurringRule(
            id: rule.id,
            name: rule.name,
            amount: rule.amount,
            categoryId: rule.categoryId,
            type: rule.type,
            frequency: rule.frequency,
            firstDue: rule.firstDue,
            nextDue: rule.nextDue,
            lastExecuted: rule.lastExecuted,
            isActive: active,
            note: rule.note,
            categoryName: rule.categoryName,
            categoryIcon: rule.categoryIcon,
            categoryColor: rule.categoryColor,
          )
        else
          rule,
    ];
    _publish();
  }

  @override
  Future<void> delete(int id) async {
    _rules = _rules.where((rule) => rule.id != id).toList();
    _publish();
  }

  void _publish() => _controller.add(++_revision);

  @override
  void dispose() => _controller.close();
}
