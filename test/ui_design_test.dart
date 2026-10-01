import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/theme/app_theme.dart';
import 'package:kyatflow/features/budgets/domain/entities/budget.dart';
import 'package:kyatflow/features/budgets/presentation/providers/budget_providers.dart';
import 'package:kyatflow/features/transactions/domain/entities/cash_flow_summary.dart';
import 'package:kyatflow/features/transactions/domain/entities/category_spending.dart';
import 'package:kyatflow/features/transactions/domain/entities/transaction_entry.dart';
import 'package:kyatflow/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:kyatflow/features/transactions/presentation/screens/main_shell_screen.dart';
import 'support/finance_fixtures.dart';

const _capture = bool.fromEnvironment('CAPTURE_DESIGN');
const _fontDirectory = String.fromEnvironment('FLUTTER_FONT_DIRECTORY');
final _boundary = GlobalKey();

void main() {
  setUpAll(() async {
    if (!_capture || _fontDirectory.isEmpty) return;
    for (final family in [
      'Roboto',
      'Ahem',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
    ]) {
      final loader = FontLoader(family);
      loader.addFont(
        File(
          '$_fontDirectory/Roboto-Regular.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });

  Future<void> pumpApp(
    WidgetTester tester,
    Size size, {
    double scale = 1,
    bool reduced = false,
    bool empty = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            _DesignRepository(empty: empty),
          ),
          budgetRepositoryProvider.overrideWithValue(_DesignBudgets()),
        ],
        child: RepaintBoundary(
          key: _boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced,
              ),
              child: child!,
            ),
            home: const MainShellScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!_capture) return;
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/ui-previews').create(recursive: true);
      await File(
        'build/ui-previews/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'phone screens render and filters, chart, edit and add remain usable',
    (tester) async {
      await pumpApp(tester, const Size(390, 844));
      await capture(tester, 'home');
      await tester.tap(find.text('Salary').first);
      await tester.pumpAndSettle();
      expect(find.text('Edit transaction'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('analytics_tab')));
      await tester.pumpAndSettle();
      await capture(tester, 'analytics');
      await tester.tap(find.byKey(const ValueKey('analytics_period_thisWeek')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Food').last,
        140,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('ledger_tab')));
      await tester.pumpAndSettle();
      await capture(tester, 'history');
      await tester.tap(find.byKey(const ValueKey('ledger_filter_income')));
      await tester.pumpAndSettle();
      expect(find.text('Food'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('settings_tab')));
      await tester.pumpAndSettle();
      await capture(tester, 'settings');
      await tester.tap(find.byKey(const ValueKey('add_transaction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category_2')));
      for (final digit in ['1', '2', '0', '0', '0']) {
        await tester.tap(find.byKey(ValueKey('keypad_$digit')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await capture(tester, 'entry');
      expect(find.text('MMK 12,000'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('save_transaction')));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save this transaction. Please try again.'),
        findsNothing,
      );
      expect(find.text('Local-first by design'), findsOneWidget);
    },
  );

  for (final config in [
    (name: 'small', size: const Size(320, 568), scale: 1.0),
    (name: 'large-text', size: const Size(390, 844), scale: 2.0),
    (name: 'landscape', size: const Size(844, 390), scale: 1.0),
  ]) {
    testWidgets('${config.name} layouts stay usable with reduced motion', (
      tester,
    ) async {
      await pumpApp(tester, config.size, scale: config.scale, reduced: true);
      for (final tab in ['analytics_tab', 'ledger_tab', 'settings_tab']) {
        await tester.tap(find.byKey(ValueKey(tab)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tester.tap(find.byKey(const ValueKey('add_transaction')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(
        find.byType(TextFormField),
        'A note with the keyboard open',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('save_transaction')),
      );
      await tester.tap(find.byKey(const ValueKey('save_transaction')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a category'), findsWidgets);
      expect(tester.takeException(), isNull);
      await capture(tester, config.name);
    });
  }

  testWidgets(
    'empty screens present useful guidance without fabricated totals',
    (tester) async {
      await pumpApp(tester, const Size(390, 844), empty: true);
      expect(find.text('No transactions yet'), findsOneWidget);
      await capture(tester, 'home-empty');
      await tester.tap(find.byKey(const ValueKey('analytics_tab')));
      await tester.pumpAndSettle();
      expect(find.text('No expenses in this period'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ledger_tab')));
      await tester.pumpAndSettle();
      expect(find.text('No matching transactions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DesignRepository extends TestTransactionRepository {
  _DesignRepository({this.empty = false});
  final bool empty;
  final _now = DateTime.now();
  List<TransactionEntry> get entries => empty
      ? []
      : [
          TransactionEntry(
            id: 1,
            amount: 1250000,
            type: TransactionType.income,
            categoryId: 1,
            timestamp: _now,
            categoryName: 'Salary',
            categoryIcon: 'salary',
            note: 'Monthly salary',
          ),
          TransactionEntry(
            id: 2,
            amount: 12500,
            type: TransactionType.expense,
            categoryId: 2,
            timestamp: _now,
            categoryName: 'Food',
            categoryIcon: 'food',
            note: 'Lunch & coffee',
          ),
          TransactionEntry(
            id: 3,
            amount: 8000,
            type: TransactionType.expense,
            categoryId: 3,
            timestamp: _now.subtract(const Duration(days: 1)),
            categoryName: 'Transport',
            categoryIcon: 'transport',
            note: 'Taxi home',
          ),
        ];
  @override
  Future<CashFlowSummary> getDashboardCashFlow(DateTime activeMonth) async =>
      empty
      ? const CashFlowSummary.zero()
      : const CashFlowSummary(
          currentBalance: 940000,
          totalIncome: 1250000,
          totalExpense: 310000,
        );
  @override
  Future<List<TransactionEntry>> getRecentTransactions({int limit = 5}) async =>
      entries.take(limit).toList();
  @override
  Future<List<TransactionEntry>> getLedgerTransactions({
    TransactionType? type,
  }) async =>
      entries.where((entry) => type == null || entry.type == type).toList();
  @override
  Future<List<CategorySpending>> getExpenseBreakdown({
    required DateTime start,
    required DateTime end,
  }) async => empty
      ? []
      : const [
          CategorySpending(
            categoryId: 2,
            categoryName: 'Food',
            categoryIcon: 'food',
            categoryColor: 0xFF246B55,
            amount: 155000,
            transactionCount: 12,
          ),
          CategorySpending(
            categoryId: 3,
            categoryName: 'Shopping',
            categoryIcon: 'shopping',
            categoryColor: 0xFF8CA89A,
            amount: 93000,
            transactionCount: 3,
          ),
          CategorySpending(
            categoryId: 4,
            categoryName: 'Transport',
            categoryIcon: 'transport',
            categoryColor: 0xFFC2C7BD,
            amount: 62000,
            transactionCount: 8,
          ),
        ];
}

class _DesignBudgets extends TestBudgetRepository {
  @override
  Future<List<BudgetProgress>> getMonthlyProgress(DateTime month) async => [
    BudgetProgress(
      budgetId: 1,
      categoryId: 2,
      categoryName: 'Food',
      categoryIcon: 'food',
      categoryColor: 0xFF246B55,
      amountLimit: 200000,
      actualSpent: 155000,
      month: month.month,
      year: month.year,
      alertPercentage: 80,
      progressPercentage: 77.5,
      warningState: BudgetWarningState.safe,
    ),
  ];
}
