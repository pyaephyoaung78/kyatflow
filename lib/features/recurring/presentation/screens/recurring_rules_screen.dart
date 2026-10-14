import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/recurrence_schedule.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../../transactions/domain/entities/transaction_category.dart';
import '../../../transactions/domain/entities/transaction_entry.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/utils/category_icon_mapper.dart';
import '../../../transactions/presentation/utils/finance_formatters.dart';
import '../../data/services/recurring_transaction_service.dart';
import '../../domain/entities/recurring_rule.dart';
import '../providers/recurring_rule_providers.dart';

class RecurringRulesScreen extends ConsumerWidget {
  const RecurringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring transactions'),
        actions: [
          IconButton(
            key: const ValueKey('add_recurring_rule'),
            tooltip: 'Add recurring transaction',
            onPressed: () => _openEditor(context, ref),
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
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 24),
                    child: Text(
                      'Kyat Flow automatically records active rules when they '
                      'become due. Paused rules keep their schedule without '
                      'creating transactions.',
                      style: AppTheme.caption,
                    ),
                  ),
                  rules.when(
                    loading: () => const FinanceLoading(),
                    error: (_, _) => FinanceEmptyState(
                      icon: CupertinoIcons.exclamationmark_circle,
                      title: 'Could not load recurring transactions',
                      message: 'Pull down to try again.',
                      onRetry: () => _refresh(ref),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return _EmptyRules(
                          onAdd: () => _openEditor(context, ref),
                        );
                      }
                      final active = items
                          .where((rule) => rule.isActive)
                          .toList(growable: false);
                      final paused = items
                          .where((rule) => !rule.isActive)
                          .toList(growable: false);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (active.isNotEmpty) ...[
                            SectionHeading(
                              'Active',
                              detail: '${active.length}',
                            ),
                            _RuleGroup(
                              rules: active,
                              onTap: (rule) => _openEditor(context, ref, rule),
                              onToggle: (rule, active) =>
                                  _toggle(context, ref, rule, active),
                            ),
                          ],
                          if (paused.isNotEmpty) ...[
                            if (active.isNotEmpty) const SizedBox(height: 28),
                            SectionHeading(
                              'Paused',
                              detail: '${paused.length}',
                            ),
                            _RuleGroup(
                              rules: paused,
                              onTap: (rule) => _openEditor(context, ref, rule),
                              onToggle: (rule, active) =>
                                  _toggle(context, ref, rule, active),
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

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(recurringRulesProvider);
    await ref.read(recurringRulesProvider.future);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, [
    RecurringRule? existing,
  ]) async {
    try {
      final categories = await ref
          .read(transactionRepositoryProvider)
          .getCategories(includeArchived: true);
      if (!context.mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          fullscreenDialog: existing == null,
          builder: (_) =>
              _RecurringRuleEditor(categories: categories, existing: existing),
        ),
      );
      if (saved == true) ref.invalidate(recurringRulesProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the recurring editor.')),
      );
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    RecurringRule rule,
    bool active,
  ) async {
    HapticFeedback.selectionClick();
    try {
      await ref
          .read(recurringRuleRepositoryProvider)
          .setActive(rule.id, active: active);
      if (active) {
        await RecurringTransactionService(
          databaseHelper: ref.read(databaseHelperProvider),
        ).executeDueTransactions();
        _invalidateTransactionViews(ref);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this rule.')),
      );
    }
  }
}

class _RuleGroup extends StatelessWidget {
  const _RuleGroup({
    required this.rules,
    required this.onTap,
    required this.onToggle,
  });

  final List<RecurringRule> rules;
  final ValueChanged<RecurringRule> onTap;
  final void Function(RecurringRule rule, bool active) onToggle;

  @override
  Widget build(BuildContext context) => SurfaceGroup(
    separatorInset: 68,
    children: [
      for (final rule in rules)
        CupertinoButton(
          key: ValueKey('recurring_rule_${rule.id}'),
          padding: EdgeInsets.zero,
          onPressed: () => onTap(rule),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(
                      rule.categoryColor ?? AppTheme.accent.toARGB32(),
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    categoryIconFromKey(rule.categoryIcon),
                    color: Color(
                      rule.categoryColor ?? AppTheme.accent.toARGB32(),
                    ),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatMoney(rule.amount)} · ${rule.frequency.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.caption,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rule.isActive
                            ? 'Next ${formatFullDate(rule.nextDue)}'
                            : 'Paused · Next ${formatFullDate(rule.nextDue)}',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoSwitch(
                  key: ValueKey('recurring_toggle_${rule.id}'),
                  value: rule.isActive,
                  activeTrackColor: AppTheme.accent,
                  onChanged: (value) => onToggle(rule, value),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _EmptyRules extends StatelessWidget {
  const _EmptyRules({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => SurfaceGroup(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.repeat,
              color: AppTheme.secondary,
              size: 30,
            ),
            const SizedBox(height: 14),
            const Text(
              'No recurring transactions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Automate regular income and expenses such as salary, rent, or subscriptions.',
              textAlign: TextAlign.center,
              style: AppTheme.caption,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('add_first_recurring_rule'),
              onPressed: onAdd,
              icon: const Icon(CupertinoIcons.add, size: 18),
              label: const Text('Add recurring transaction'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _RecurringRuleEditor extends ConsumerStatefulWidget {
  const _RecurringRuleEditor({
    required this.categories,
    required this.existing,
  });

  final List<TransactionCategory> categories;
  final RecurringRule? existing;

  @override
  ConsumerState<_RecurringRuleEditor> createState() =>
      _RecurringRuleEditorState();
}

class _RecurringRuleEditorState extends ConsumerState<_RecurringRuleEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late int? _categoryId;
  late RecurringFrequency _frequency;
  late DateTime _firstDue;
  late bool _isActive;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  List<TransactionCategory> get _availableCategories => widget.categories
      .where(
        (category) =>
            category.type == _type &&
            (!category.isArchived ||
                category.id == widget.existing?.categoryId),
      )
      .toList(growable: false);

  bool get _busy => _saving || _deleting;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : _editableAmount(existing.amount),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _type = existing?.type ?? TransactionType.expense;
    _categoryId = existing?.categoryId;
    _frequency = existing?.frequency ?? RecurringFrequency.monthly;
    final initialDate = existing?.firstDue ?? DateTime.now();
    _firstDue = DateTime(initialDate.year, initialDate.month, initialDate.day);
    _isActive = existing?.isActive ?? true;
    _categoryId ??= _availableCategories.firstOrNull?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final categories = _availableCategories;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? 'Edit recurring transaction' : 'New recurring transaction',
        ),
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
                  FinanceSegments<TransactionType>(
                    value: _type,
                    labels: const {
                      TransactionType.expense: 'Expense',
                      TransactionType.income: 'Income',
                    },
                    onChanged: _changeType,
                    keyPrefix: 'recurring_type',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey('recurring_name'),
                    controller: _nameController,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Home internet',
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('recurring_amount'),
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [const _MoneyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '0',
                      suffixText: 'Mmk',
                    ),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTheme.numbers,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 28),
                  const SectionHeading('Category'),
                  if (categories.isEmpty)
                    const Text(
                      'Create an active category for this transaction type first.',
                      style: AppTheme.caption,
                    )
                  else
                    SurfaceGroup(
                      separatorInset: 66,
                      children: [
                        for (final category in categories)
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
                  const SectionHeading('Frequency'),
                  FinanceSegments<RecurringFrequency>(
                    value: _frequency,
                    labels: {
                      for (final frequency in RecurringFrequency.values)
                        frequency: frequency.label,
                    },
                    onChanged: (value) => setState(() => _frequency = value),
                    keyPrefix: 'recurring_frequency',
                  ),
                  const SizedBox(height: 28),
                  const SectionHeading('Schedule'),
                  SurfaceGroup(
                    children: [
                      CupertinoButton(
                        key: const ValueKey('recurring_first_due'),
                        padding: EdgeInsets.zero,
                        onPressed: _pickFirstDue,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.calendar,
                                size: 21,
                                color: AppTheme.accent,
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'First due date',
                                  style: TextStyle(
                                    color: AppTheme.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                formatFullDate(_firstDue),
                                style: AppTheme.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.clock,
                              size: 21,
                              color: AppTheme.secondary,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Next transaction',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              formatFullDate(_nextDuePreview),
                              style: AppTheme.caption,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            CupertinoSwitch(
                              key: const ValueKey('recurring_active'),
                              value: _isActive,
                              activeTrackColor: AppTheme.accent,
                              onChanged: (value) =>
                                  setState(() => _isActive = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const SectionHeading('Note'),
                  TextField(
                    key: const ValueKey('recurring_note'),
                    controller: _noteController,
                    maxLength: 160,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Optional details',
                      counterText: '',
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
                    key: const ValueKey('save_recurring_rule'),
                    onPressed: _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _saving
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : Text(
                              editing
                                  ? 'Save changes'
                                  : 'Add recurring transaction',
                            ),
                    ),
                  ),
                  if (editing) ...[
                    const SizedBox(height: 12),
                    CupertinoButton(
                      key: const ValueKey('delete_recurring_rule'),
                      onPressed: _confirmDelete,
                      child: _deleting
                          ? const CupertinoActivityIndicator()
                          : const Text(
                              'Delete recurring transaction',
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

  void _changeType(TransactionType type) {
    setState(() {
      _type = type;
      _categoryId = _availableCategories.firstOrNull?.id;
      _error = null;
    });
  }

  Future<void> _pickFirstDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: widget.existing == null
          ? DateTime.now().subtract(const Duration(days: 1))
          : DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choose first due date',
    );
    if (picked != null && mounted) {
      setState(() => _firstDue = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text);
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }
    if (_categoryId == null) {
      setState(() => _error = 'Choose a category');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(recurringRuleRepositoryProvider);
      final existing = widget.existing;
      final note = _noteController.text.trim();
      if (existing == null) {
        await repository.insert(
          RecurringRuleDraft(
            name: name,
            amount: amount,
            categoryId: _categoryId!,
            type: _type,
            frequency: _frequency,
            firstDue: _firstDue,
            isActive: _isActive,
            note: note.isEmpty ? null : note,
          ),
        );
      } else {
        final scheduleChanged =
            existing.frequency != _frequency ||
            !_sameDay(existing.firstDue, _firstDue);
        final nextDue = scheduleChanged
            ? _nextDueAfterScheduleChange(existing)
            : existing.nextDue;
        await repository.edit(
          RecurringRule(
            id: existing.id,
            name: name,
            amount: amount,
            categoryId: _categoryId!,
            type: _type,
            frequency: _frequency,
            firstDue: _firstDue,
            nextDue: nextDue,
            lastExecuted: existing.lastExecuted,
            isActive: _isActive,
            note: note.isEmpty ? null : note,
          ),
        );
      }
      if (_isActive) {
        await RecurringTransactionService(
          databaseHelper: ref.read(databaseHelperProvider),
        ).executeDueTransactions();
        _invalidateTransactionViews(ref);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this recurring transaction.';
      });
    }
  }

  DateTime _nextDueAfterScheduleChange(RecurringRule existing) {
    final lastExecuted = existing.lastExecuted;
    if (lastExecuted == null || _firstDue.isAfter(lastExecuted)) {
      return _firstDue;
    }
    return RecurrenceSchedule.firstOccurrenceAfter(
      _firstDue,
      _frequency.name,
      lastExecuted,
    );
  }

  DateTime get _nextDuePreview {
    final existing = widget.existing;
    if (existing == null) return _firstDue;
    final scheduleChanged =
        existing.frequency != _frequency ||
        !_sameDay(existing.firstDue, _firstDue);
    return scheduleChanged
        ? _nextDueAfterScheduleChange(existing)
        : existing.nextDue;
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete this recurring transaction?'),
        content: const Text(
          'Transactions already created by this rule will remain in History.',
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
      await ref.read(recurringRuleRepositoryProvider).delete(existing.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Could not delete this recurring transaction.';
      });
    }
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

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
    key: ValueKey('recurring_category_${category.id}'),
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
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}

void _invalidateTransactionViews(WidgetRef ref) {
  ref.invalidate(transactionStateProvider);
  ref.invalidate(dashboardStateProvider);
  ref.invalidate(ledgerStateProvider);
  ref.invalidate(analyticsStateProvider);
}
