import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_entry.dart';
import 'package:kyatflow/features/transactions/presentation/models/transaction_category_option.dart';
import 'package:kyatflow/features/transactions/presentation/screens/transaction_entry_screen.dart';

void main() {
  const categories = [
    TransactionCategoryOption(
      id: 1,
      name: 'Food',
      icon: Icons.restaurant_rounded,
      color: Colors.orange,
      type: TransactionType.expense,
    ),
    TransactionCategoryOption(
      id: 2,
      name: 'Transport',
      icon: Icons.directions_bus_rounded,
      color: Colors.blue,
      type: TransactionType.expense,
    ),
    TransactionCategoryOption(
      id: 3,
      name: 'Salary',
      icon: Icons.account_balance_wallet_rounded,
      color: Colors.green,
      type: TransactionType.income,
    ),
  ];
  final fixedTime = DateTime(2026, 9, 30, 18, 30);

  Future<void> pumpEntryScreen(
    WidgetTester tester, {
    required Future<void> Function(TransactionDraft) onSubmit,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionEntryScreen(
          categories: categories,
          onSubmit: onSubmit,
          clock: () => fixedTime,
        ),
      ),
    );
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey('keypad_$key'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('renders a 4x4 keypad and calculates before submission', (
    tester,
  ) async {
    TransactionDraft? submitted;
    await pumpEntryScreen(tester, onSubmit: (draft) async => submitted = draft);

    expect(find.byKey(const ValueKey('keypad_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('keypad_9')), findsOneWidget);
    expect(find.byKey(const ValueKey('keypad_.')), findsOneWidget);
    expect(find.byKey(const ValueKey('keypad_backspace')), findsOneWidget);
    expect(find.byKey(const ValueKey('keypad_+')), findsOneWidget);
    expect(find.byKey(const ValueKey('keypad_-')), findsOneWidget);
    expect(find.byKey(const ValueKey('keypad_×')), findsOneWidget);
    expect(find.byKey(const ValueKey('keypad_÷')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('category_1')));
    await tester.pump();
    for (final key in ['1', '2', '+', '3', '×', '4']) {
      await tapKey(tester, key);
    }
    expect(find.text('12 + 3 × 4'), findsOneWidget);
    expect(find.text('MMK 24'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Lunch and coffee');
    final saveButton = find.byKey(const ValueKey('save_transaction'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.amount, 24);
    expect(submitted!.type, TransactionType.expense);
    expect(submitted!.categoryId, 1);
    expect(submitted!.timestamp, fixedTime);
    expect(submitted!.note, 'Lunch and coffee');
  });

  testWidgets('type toggle animates and changes the available categories', (
    tester,
  ) async {
    await pumpEntryScreen(tester, onSubmit: (_) async {});

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('type_income')));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsNothing);
    expect(find.text('Salary'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('type_expense')));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets('validates amount, category, and division by zero', (
    tester,
  ) async {
    await pumpEntryScreen(tester, onSubmit: (_) async {});
    final saveButton = find.byKey(const ValueKey('save_transaction'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Enter an amount'), findsWidgets);
    expect(find.text('Choose a category'), findsOneWidget);

    for (final key in ['5', '÷', '0']) {
      await tapKey(tester, key);
    }
    expect(find.text('Cannot divide by zero'), findsOneWidget);
    await tapKey(tester, 'backspace');
    await tapKey(tester, '2');
    expect(find.text('MMK 2.50'), findsOneWidget);
  });
}
