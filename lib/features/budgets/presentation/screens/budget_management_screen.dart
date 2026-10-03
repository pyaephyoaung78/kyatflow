import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../../transactions/domain/entities/transaction_category.dart';
import '../../../transactions/domain/entities/transaction_entry.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/utils/category_icon_mapper.dart';
import '../../../transactions/presentation/utils/finance_formatters.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../providers/budget_providers.dart';
import '../widgets/budget_progress_widget.dart';

class BudgetManagementScreen extends ConsumerStatefulWidget {
  const BudgetManagementScreen({required this.initialMonth, super.key});

  final DateTime initialMonth;

  @override
  ConsumerState<BudgetManagementScreen> createState() =>
      _BudgetManagementScreenState();
}

class _BudgetManagementScreenState
    extends ConsumerState<BudgetManagementScreen> {
  late DateTime _activeMonth;

  @override
  void initState() {
    super.initState();
    _activeMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(monthlyBudgetProgressProvider(_activeMonth));
    final income = ref.watch(monthlyBudgetIncomeProvider(_activeMonth));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly budgets'),
        actions: [
          IconButton(
            key: const ValueKey('add_budget'),
            tooltip: 'Add budget',
            onPressed: _openEditor,
            icon: const Icon(CupertinoIcons.add, size: 23),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: RefreshIndicator(
              color: AppTheme.accent,
              onRefresh: _refresh,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _MonthNavigator(
                    month: _activeMonth,
                    onPrevious: () => _changeMonth(-1),
                    onNext: () => _changeMonth(1),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 14, 4, 28),
                    child: Text(
                      'Set one spending limit for each expense category. '
                      'Transactions are compared with the limit automatically.',
                      style: AppTheme.caption,
                    ),
                  ),
                  budgets.when(
                    loading: () => const FinanceLoading(),
                    error: (_, _) => FinanceEmptyState(
                      icon: CupertinoIcons.exclamationmark_circle,
                      title: 'Could not load budgets',
                      message: 'Pull down to try again.',
                      onRetry: _refresh,
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
                          const SizedBox(height: 28),
                          if (items.isEmpty)
                            _EmptyBudgets(
                              month: _activeMonth,
                              onAdd: _openEditor,
                            )
                          else ...[
                            SectionHeading(
                              'Category limits',
                              detail: '${items.length}',
                            ),
                            SurfaceGroup(
                              separatorInset: 20,
                              children: [
                                for (final budget in items)
                                  BudgetProgressWidget(
                                    progress: budget,
                                    onTap: () => _openEditor(budget),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _activeMonth = DateTime(_activeMonth.year, _activeMonth.month + offset);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(monthlyBudgetProgressProvider(_activeMonth));
    ref.invalidate(monthlyBudgetIncomeProvider(_activeMonth));
    await Future.wait([
      ref.read(monthlyBudgetProgressProvider(_activeMonth).future),
      ref.read(monthlyBudgetIncomeProvider(_activeMonth).future),
    ]);
  }

  Future<void> _openEditor([BudgetProgress? existing]) async {
    try {
      final categories = await ref
          .read(transactionRepositoryProvider)
          .getCategories(includeArchived: true);
      final budgets = await ref
          .read(budgetRepositoryProvider)
          .getMonthlyProgress(_activeMonth);
      if (!mounted) return;

      final usedCategoryIds = budgets
          .where((budget) => budget.budgetId != existing?.budgetId)
          .map((budget) => budget.categoryId)
          .toSet();
      final availableCategories = categories
          .where(
            (category) =>
                category.type == TransactionType.expense &&
                (!category.isArchived || category.id == existing?.categoryId) &&
                !usedCategoryIds.contains(category.id),
          )
          .toList(growable: false);

      if (availableCategories.isEmpty && existing == null) {
        _showMessage(
          'Every active expense category already has a budget for this month.',
        );
        return;
      }

      final saved = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          fullscreenDialog: existing == null,
          builder: (_) => _BudgetEditorScreen(
            month: _activeMonth,
            categories: availableCategories,
            existing: existing,
          ),
        ),
      );
      if (saved == true && mounted) {
        ref.invalidate(monthlyBudgetProgressProvider(_activeMonth));
      }
    } catch (_) {
      if (mounted) _showMessage('Could not open the budget editor');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => SurfaceGroup(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('budget_previous_month'),
              tooltip: 'Previous month',
              onPressed: onPrevious,
              icon: const Icon(CupertinoIcons.chevron_left, size: 19),
            ),
            Expanded(
              child: Text(
                formatMonth(month),
                textAlign: TextAlign.center,
                style: AppTheme.section,
              ),
            ),
            IconButton(
              key: const ValueKey('budget_next_month'),
              tooltip: 'Next month',
              onPressed: onNext,
              icon: const Icon(CupertinoIcons.chevron_right, size: 19),
            ),
          ],
        ),
      ),
    ],
  );
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets({required this.month, required this.onAdd});

  final DateTime month;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => SurfaceGroup(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.chart_bar,
              size: 30,
              color: AppTheme.secondary,
            ),
            const SizedBox(height: 14),
            Text(
              'No budgets for ${formatMonth(month)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add a category limit to start tracking your monthly plan.',
              textAlign: TextAlign.center,
              style: AppTheme.caption,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('add_first_budget'),
              onPressed: onAdd,
              icon: const Icon(CupertinoIcons.add, size: 18),
              label: const Text('Add budget'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _BudgetEditorScreen extends ConsumerStatefulWidget {
  const _BudgetEditorScreen({
    required this.month,
    required this.categories,
    required this.existing,
  });

  final DateTime month;
  final List<TransactionCategory> categories;
  final BudgetProgress? existing;

  @override
  ConsumerState<_BudgetEditorScreen> createState() =>
      _BudgetEditorScreenState();
}

class _BudgetEditorScreenState extends ConsumerState<_BudgetEditorScreen> {
  late final TextEditingController _amountController;
  late int? _categoryId;
  late int _alertPercentage;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing == null ? '' : _editableAmount(existing.amountLimit),
    );
    _categoryId = existing?.categoryId ?? widget.categories.firstOrNull?.id;
    _alertPercentage = existing?.alertPercentage.round() ?? 80;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final amount = double.tryParse(_amountController.text) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit budget' : 'New budget'),
        leading: IconButton(
          tooltip: 'Cancel',
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: const Icon(CupertinoIcons.xmark, size: 20),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    formatMonth(widget.month),
                    textAlign: TextAlign.center,
                    style: AppTheme.section,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your spending is measured from the first to the last day of this month.',
                    textAlign: TextAlign.center,
                    style: AppTheme.caption,
                  ),
                  const SizedBox(height: 28),
                  const SectionHeading('Expense category'),
                  SurfaceGroup(
                    separatorInset: 66,
                    children: [
                      for (final category in widget.categories)
                        _CategoryChoice(
                          category: category,
                          selected: category.id == _categoryId,
                          onTap: () => setState(() {
                            _categoryId = category.id;
                            _error = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const SectionHeading('Monthly limit'),
                  TextField(
                    key: const ValueKey('budget_amount'),
                    controller: _amountController,
                    autofocus: !editing,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [const _MoneyInputFormatter()],
                    decoration: const InputDecoration(
                      hintText: '0',
                      suffixText: 'Mmk',
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTheme.numbers,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  if (amount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      formatMoney(amount),
                      textAlign: TextAlign.right,
                      style: AppTheme.caption,
                    ),
                  ],
                  const SizedBox(height: 28),
                  const SectionHeading('Warn me when I reach'),
                  FinanceSegments<int>(
                    value: _alertPercentage,
                    labels: const {70: '70%', 80: '80%', 90: '90%'},
                    onChanged: (value) =>
                        setState(() => _alertPercentage = value),
                    keyPrefix: 'budget_alert',
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(
                      'The progress bar turns amber at this percentage.',
                      style: AppTheme.caption,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.expense,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const ValueKey('save_budget'),
                    onPressed: _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _saving
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : Text(editing ? 'Save changes' : 'Add budget'),
                    ),
                  ),
                  if (editing) ...[
                    const SizedBox(height: 12),
                    CupertinoButton(
                      key: const ValueKey('delete_budget'),
                      onPressed: _confirmDelete,
                      child: _deleting
                          ? const CupertinoActivityIndicator()
                          : const Text(
                              'Delete budget',
                              style: TextStyle(color: AppTheme.expense),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _busy => _saving || _deleting;

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (_categoryId == null) {
      setState(() => _error = 'Choose an expense category');
      return;
    }
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = 'Enter a budget amount greater than zero');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(budgetRepositoryProvider);
      final existing = widget.existing;
      if (existing == null) {
        await repository.insert(
          BudgetDraft(
            categoryId: _categoryId!,
            amountLimit: amount,
            month: widget.month.month,
            year: widget.month.year,
            alertPercentage: _alertPercentage.toDouble(),
          ),
        );
      } else {
        await repository.edit(
          Budget(
            id: existing.budgetId,
            categoryId: _categoryId!,
            amountLimit: amount,
            month: widget.month.month,
            year: widget.month.year,
            alertPercentage: _alertPercentage.toDouble(),
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on BudgetAlreadyExistsException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'This category already has a budget for this month.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this budget. Please try again.';
      });
    }
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete this budget?'),
        content: const Text(
          'Your transactions will stay unchanged. Only this spending limit will be removed.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(budgetRepositoryProvider).delete(existing.budgetId);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Could not delete this budget. Please try again.';
      });
    }
  }

  String _editableAmount(double amount) {
    final fixed = amount.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final TransactionCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    key: ValueKey('budget_category_${category.id}'),
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Color(category.color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              categoryIconFromKey(category.icon),
              color: Color(category.color),
              size: 19,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (category.isArchived)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Text('Archived', style: AppTheme.caption),
            ),
          Icon(
            selected
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.circle,
            color: selected ? AppTheme.accent : AppTheme.line,
            size: 22,
          ),
        ],
      ),
    ),
  );
}

class _MoneyInputFormatter extends TextInputFormatter {
  const _MoneyInputFormatter();

  static final _pattern = RegExp(r'^\d{0,12}(?:\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
