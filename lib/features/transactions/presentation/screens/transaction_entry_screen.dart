import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transaction_entry.dart';
import '../models/transaction_category_option.dart';
import '../providers/transaction_providers.dart';
import '../utils/amount_expression_evaluator.dart';

typedef TransactionDraftCallback =
    Future<void> Function(TransactionDraft transaction);

/// A reusable transaction form. Category IDs must exist in the local database.
class TransactionEntryScreen extends StatefulWidget {
  const TransactionEntryScreen({
    super.key,
    required this.categories,
    required this.onSubmit,
    this.initialTransaction,
    this.onSaved,
    this.currencyCode = 'MMK',
    this.clock,
  });

  final List<TransactionCategoryOption> categories;
  final TransactionDraftCallback onSubmit;
  final TransactionEntry? initialTransaction;
  final VoidCallback? onSaved;
  final String currencyCode;
  final DateTime Function()? clock;

  @override
  State<TransactionEntryScreen> createState() => _TransactionEntryScreenState();
}

class _TransactionEntryScreenState extends State<TransactionEntryScreen> {
  static const _maximumExpressionLength = 48;
  static const _maximumOperandDigits = 12;
  static const _maximumFractionDigits = 2;

  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _evaluator = const AmountExpressionEvaluator();

  late TransactionType _type;
  late String _expression;
  int? _selectedCategoryId;
  bool _isSubmitting = false;
  bool _didAttemptSubmit = false;
  String? _amountError;
  String? _categoryError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTransaction;
    _type = initial?.type ?? TransactionType.expense;
    _expression = initial == null ? '' : _editableAmount(initial.amount);
    _selectedCategoryId = initial?.categoryId;
    _noteController.text = initial?.note ?? '';
    _ensureValidCategorySelection();
  }

  @override
  void didUpdateWidget(covariant TransactionEntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      setState(_ensureValidCategorySelection);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<TransactionCategoryOption> get _availableCategories {
    return widget.categories
        .where((category) => category.type == _type)
        .toList(growable: false);
  }

  _AmountPreview get _preview {
    if (_expression.isEmpty) return const _AmountPreview(value: 0);
    var evaluable = _expression;
    if (_isOperator(evaluable.characters.last)) {
      evaluable = evaluable.substring(0, evaluable.length - 1);
    }
    if (evaluable.endsWith('.')) evaluable = '${evaluable}0';
    try {
      return _AmountPreview(value: _evaluator.evaluateMoney(evaluable));
    } on FormatException catch (error) {
      return _AmountPreview(value: 0, error: error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialTransaction == null
              ? 'New transaction'
              : 'Edit transaction',
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Close',
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                icon: const Icon(CupertinoIcons.xmark, size: 20),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AbsorbPointer(
              absorbing: _isSubmitting,
              child: GestureDetector(
                onTap: FocusScope.of(context).unfocus,
                child: SingleChildScrollView(
                  key: const PageStorageKey('transaction_entry'),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FinanceSegments<TransactionType>(
                        value: _type,
                        labels: const {
                          TransactionType.expense: 'Expense',
                          TransactionType.income: 'Income',
                        },
                        onChanged: _changeType,
                        keyPrefix: 'type',
                      ),
                      _AmountPanel(
                        expression: _displayExpression,
                        value: preview.value,
                        error: _amountError ?? preview.error,
                        currencyCode: widget.currencyCode,
                      ),
                      const Text('Category', style: AppTheme.caption),
                      const SizedBox(height: 8),
                      _CategorySelector(
                        categories: _availableCategories,
                        selectedId: _selectedCategoryId,
                        emptyMessage:
                            'Add an ${_type.name} category before saving.',
                        onSelected: (id) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedCategoryId = id;
                            _categoryError = null;
                            _submitError = null;
                          });
                        },
                      ),
                      if (_categoryError != null) ...[
                        const SizedBox(height: 6),
                        _InlineError(message: _categoryError!),
                      ],
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        autovalidateMode: _didAttemptSubmit
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: TextFormField(
                          controller: _noteController,
                          maxLength: 200,
                          minLines: 1,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: 'Note (optional)',
                            counterText: '',
                            prefixIcon: Icon(
                              CupertinoIcons.text_alignleft,
                              size: 19,
                            ),
                          ),
                          validator: (value) =>
                              (value?.trim().length ?? 0) > 200
                              ? 'Keep the note under 200 characters'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Keypad(onKeyPressed: _handleKeypadInput),
                      if (_submitError != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(message: _submitError!),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const ValueKey('save_transaction'),
                        onPressed: _isSubmitting ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _isSubmitting
                              ? const CupertinoActivityIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  widget.initialTransaction == null
                                      ? 'Save transaction'
                                      : 'Update transaction',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _displayExpression {
    if (_expression.isEmpty) return 'Enter an amount';
    return _expression.replaceAllMapped(
      RegExp(r'[+\-×÷]'),
      (match) => ' ${match.group(0)} ',
    );
  }

  void _changeType(TransactionType type) {
    if (_type == type) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = type;
      _selectedCategoryId = null;
      _categoryError = null;
      _submitError = null;
    });
  }

  void _handleKeypadInput(String key) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _amountError = null;
      _submitError = null;
      if (key == 'backspace') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (_isOperator(key)) {
        _appendOperator(key);
      } else if (key == '.') {
        _appendDecimalPoint();
      } else {
        _appendDigit(key);
      }
    });
  }

  void _appendDigit(String digit) {
    if (_expression.length >= _maximumExpressionLength) return;
    final operand = _currentOperand;
    if (operand.replaceAll('.', '').length >= _maximumOperandDigits) return;
    final dotIndex = operand.indexOf('.');
    if (dotIndex >= 0 &&
        operand.length - dotIndex - 1 >= _maximumFractionDigits) {
      return;
    }
    if (operand == '0' && digit != '0') {
      _expression = '${_expression.substring(0, _expression.length - 1)}$digit';
      return;
    }
    if (operand == '0' && digit == '0') return;
    _expression += digit;
  }

  void _appendDecimalPoint() {
    if (_expression.length >= _maximumExpressionLength) return;
    final operand = _currentOperand;
    if (operand.contains('.')) return;
    _expression += operand.isEmpty ? '0.' : '.';
  }

  void _appendOperator(String operator) {
    if (_expression.isEmpty) return;
    final last = _expression.characters.last;
    if (_isOperator(last)) {
      _expression =
          '${_expression.substring(0, _expression.length - 1)}$operator';
      return;
    }
    if (last == '.') _expression += '0';
    if (_expression.length < _maximumExpressionLength) _expression += operator;
  }

  String get _currentOperand {
    final lastOperator = _expression.lastIndexOf(RegExp(r'[+\-×÷]'));
    return _expression.substring(lastOperator + 1);
  }

  bool _isOperator(String value) {
    return AmountExpressionEvaluator.operators.contains(value);
  }

  Future<void> _submit() async {
    final formIsValid = _formKey.currentState?.validate() ?? false;
    double? amount;
    String? amountError;
    try {
      amount = _evaluator.evaluateMoney(_expression);
      if (amount <= 0) amountError = 'Amount must be greater than zero';
    } on FormatException catch (error) {
      amountError = error.message;
    }
    final categoryError = _selectedCategoryId == null
        ? 'Choose a category'
        : null;

    setState(() {
      _didAttemptSubmit = true;
      _amountError = amountError;
      _categoryError = categoryError;
      _submitError = null;
    });
    if (!formIsValid || amountError != null || categoryError != null) return;

    setState(() => _isSubmitting = true);
    final trimmedNote = _noteController.text.trim();
    final initial = widget.initialTransaction;
    try {
      await widget.onSubmit(
        TransactionDraft(
          amount: amount!,
          type: _type,
          categoryId: _selectedCategoryId!,
          timestamp: initial?.timestamp ?? (widget.clock ?? DateTime.now)(),
          note: trimmedNote.isEmpty ? null : trimmedNote,
        ),
      );
      if (!mounted) return;
      widget.onSaved?.call();
      if (widget.onSaved == null && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitError = 'Could not save this transaction. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _ensureValidCategorySelection() {
    final selectedExists = widget.categories.any(
      (category) =>
          category.id == _selectedCategoryId && category.type == _type,
    );
    if (!selectedExists) _selectedCategoryId = null;
  }

  String _editableAmount(double amount) {
    final fixed = amount.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

/// Connects [TransactionEntryScreen] to the feature's Riverpod notifier.
class RiverpodTransactionEntryScreen extends ConsumerWidget {
  const RiverpodTransactionEntryScreen({
    super.key,
    required this.categories,
    this.initialTransaction,
    this.onSaved,
    this.currencyCode = 'MMK',
  });

  final List<TransactionCategoryOption> categories;
  final TransactionEntry? initialTransaction;
  final VoidCallback? onSaved;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the auto-disposed notifier alive until this form is closed.
    final notifier = ref.watch(transactionStateProvider.notifier);
    return TransactionEntryScreen(
      categories: categories,
      initialTransaction: initialTransaction,
      currencyCode: currencyCode,
      onSaved: onSaved,
      onSubmit: (draft) async {
        final initial = initialTransaction;
        if (initial == null) {
          await notifier.add(draft);
          return;
        }
        await notifier.edit(
          TransactionEntry(
            id: initial.id,
            amount: draft.amount,
            type: draft.type,
            categoryId: draft.categoryId,
            timestamp: draft.timestamp,
            note: draft.note,
          ),
        );
      },
    );
  }
}

class _AmountPanel extends StatelessWidget {
  const _AmountPanel({
    required this.expression,
    required this.value,
    required this.error,
    required this.currencyCode,
  });
  final String expression;
  final double value;
  final String? error;
  final String currencyCode;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Text(
          expression,
          key: const ValueKey('amount_expression'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.caption,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$currencyCode ${_formatMoney(value)}',
              key: const ValueKey('amount_total'),
              style: const TextStyle(
                fontSize: 42,
                height: 1.2,
                fontWeight: FontWeight.w500,
                letterSpacing: -1.8,
                color: AppTheme.ink,
                fontFeatures: AppTheme.numbers,
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.expense, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selectedId,
    required this.emptyMessage,
    required this.onSelected,
  });
  final List<TransactionCategoryOption> categories;
  final int? selectedId;
  final String emptyMessage;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return Text(emptyMessage, style: AppTheme.caption);
    final height = MediaQuery.textScalerOf(context).scale(14) + 32;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          final selected = item.id == selectedId;
          return Semantics(
            selected: selected,
            child: AnimatedContainer(
              duration: AppTheme.motion(context, 180),
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoButton(
                key: ValueKey('category_${item.id}'),
                onPressed: () => onSelected(item.id),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 18,
                      color: selected ? Colors.white : AppTheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : AppTheme.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKeyPressed});
  final ValueChanged<String> onKeyPressed;
  static const _keys = [
    '7',
    '8',
    '9',
    '÷',
    '4',
    '5',
    '6',
    '×',
    '1',
    '2',
    '3',
    '-',
    '.',
    '0',
    'backspace',
    '+',
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 18) / 4;
      final height = (MediaQuery.textScalerOf(context).scale(25) + 22).clamp(
        52.0,
        88.0,
      );
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var index = 0; index < _keys.length; index++)
            SizedBox(
              width: width,
              height: height,
              child: CupertinoButton(
                key: ValueKey('keypad_${_keys[index]}'),
                padding: EdgeInsets.zero,
                color: index % 4 == 3 ? AppTheme.accentSoft : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                onPressed: () => onKeyPressed(_keys[index]),
                child: Semantics(
                  label: switch (_keys[index]) {
                    '÷' => 'Divide',
                    '×' => 'Multiply',
                    '-' => 'Subtract',
                    '+' => 'Add',
                    'backspace' => 'Backspace',
                    _ => _keys[index],
                  },
                  excludeSemantics: true,
                  child: _keys[index] == 'backspace'
                      ? const Icon(
                          CupertinoIcons.delete_left,
                          size: 23,
                          color: AppTheme.ink,
                        )
                      : Text(
                          _keys[index],
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w400,
                            color: index % 4 == 3
                                ? AppTheme.accent
                                : AppTheme.ink,
                          ),
                        ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: const TextStyle(color: AppTheme.expense, fontSize: 13),
    ),
  );
}

class _AmountPreview {
  const _AmountPreview({required this.value, this.error});

  final double value;
  final String? error;
}

String _formatMoney(double value) {
  final negative = value < 0;
  final absolute = value.abs();
  final fixed = absolute.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  final fraction = parts[1] == '00' ? '' : '.${parts[1]}';
  return '${negative ? '-' : ''}$grouped$fraction';
}
