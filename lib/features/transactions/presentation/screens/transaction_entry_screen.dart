import 'package:flutter/material.dart';
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
  static const _expenseColor = Color(0xFFE85D4A);
  static const _incomeColor = Color(0xFF16866B);
  static const _surfaceColor = Color(0xFFF5F6F1);
  static const _inkColor = Color(0xFF17211D);
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

  Color get _accentColor {
    return _type == TransactionType.expense ? _expenseColor : _incomeColor;
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
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          widget.initialTransaction == null
              ? 'New transaction'
              : 'Edit transaction',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: FocusScope.of(context).unfocus,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _TransactionTypeToggle(value: _type, onChanged: _changeType),
              const SizedBox(height: 24),
              _AmountPanel(
                expression: _displayExpression,
                value: preview.value,
                calculationError: preview.error,
                validationError: _amountError,
                currencyCode: widget.currencyCode,
                accentColor: _accentColor,
              ),
              const SizedBox(height: 24),
              _SectionLabel(
                title: 'Category',
                trailing: '${_availableCategories.length} available',
              ),
              const SizedBox(height: 10),
              _CategorySelector(
                categories: _availableCategories,
                selectedId: _selectedCategoryId,
                emptyMessage: 'Add an ${_type.name} category before saving.',
                onSelected: (id) {
                  setState(() {
                    _selectedCategoryId = id;
                    _categoryError = null;
                    _submitError = null;
                  });
                },
              ),
              if (_categoryError != null) ...[
                const SizedBox(height: 8),
                _InlineError(message: _categoryError!),
              ],
              const SizedBox(height: 22),
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
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'What was this for?',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFE3E7E1)),
                    ),
                  ),
                  validator: (value) {
                    if ((value?.trim().length ?? 0) > 200) {
                      return 'Keep the note under 200 characters';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 12),
              _Keypad(onKeyPressed: _handleKeypadInput),
              if (_submitError != null) ...[
                const SizedBox(height: 14),
                _InlineError(message: _submitError!),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('save_transaction'),
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accentColor.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isSubmitting
                      ? 'Saving…'
                      : widget.initialTransaction == null
                      ? 'Save transaction'
                      : 'Update transaction',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
    setState(() {
      _type = type;
      _selectedCategoryId = null;
      _categoryError = null;
      _submitError = null;
    });
  }

  void _handleKeypadInput(String key) {
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
    return TransactionEntryScreen(
      categories: categories,
      initialTransaction: initialTransaction,
      currencyCode: currencyCode,
      onSaved: onSaved,
      onSubmit: (draft) async {
        final notifier = ref.read(transactionStateProvider.notifier);
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

class _TransactionTypeToggle extends StatelessWidget {
  const _TransactionTypeToggle({required this.value, required this.onChanged});

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value == TransactionType.expense
        ? _TransactionEntryScreenState._expenseColor
        : _TransactionEntryScreenState._incomeColor;
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E9E4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: value == TransactionType.expense
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: constraints.maxWidth / 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _TypeOption(
                    label: 'Expense',
                    icon: Icons.arrow_upward_rounded,
                    selected: value == TransactionType.expense,
                    color: color,
                    onTap: () => onChanged(TransactionType.expense),
                  ),
                  _TypeOption(
                    label: 'Income',
                    icon: Icons.arrow_downward_rounded,
                    selected: value == TransactionType.income,
                    color: color,
                    onTap: () => onChanged(TransactionType.income),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          key: ValueKey('type_${label.toLowerCase()}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: selected ? color : Colors.black45),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? _TransactionEntryScreenState._inkColor
                        : Colors.black54,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountPanel extends StatelessWidget {
  const _AmountPanel({
    required this.expression,
    required this.value,
    required this.calculationError,
    required this.validationError,
    required this.currencyCode,
    required this.accentColor,
  });

  final String expression;
  final double value;
  final String? calculationError;
  final String? validationError;
  final String currencyCode;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final error = validationError ?? calculationError;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: error == null
              ? const Color(0xFFE1E6DF)
              : const Color(0xFFD7443E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              expression,
              key: const ValueKey('amount_expression'),
              maxLines: 1,
              overflow: TextOverflow.fade,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black45, fontSize: 16),
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '$currencyCode ${_formatMoney(value)}',
              key: const ValueKey('amount_total'),
              style: TextStyle(
                color: _TransactionEntryScreenState._inkColor,
                fontSize: 38,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: error == null
                ? Row(
                    key: const ValueKey('calculation_ready'),
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        size: 16,
                        color: accentColor,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Calculated before saving',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  )
                : Text(
                    error,
                    key: ValueKey(error),
                    style: const TextStyle(
                      color: Color(0xFFD7443E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        Text(
          trailing,
          style: const TextStyle(fontSize: 12, color: Colors.black45),
        ),
      ],
    );
  }
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
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF9A6418)),
            const SizedBox(width: 10),
            Expanded(child: Text(emptyMessage)),
          ],
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.id == selectedId;
          return ChoiceChip(
            key: ValueKey('category_${category.id}'),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(category.id),
            avatar: Icon(
              category.icon,
              size: 18,
              color: selected ? category.color : Colors.black54,
            ),
            label: Text(category.name),
            labelStyle: TextStyle(
              color: selected
                  ? _TransactionEntryScreenState._inkColor
                  : Colors.black54,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            selectedColor: category.color.withValues(alpha: 0.16),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? category.color.withValues(alpha: 0.75)
                  : const Color(0xFFE1E6DF),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );
        },
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKeyPressed});

  static const _keys = [
    _KeyData('7'),
    _KeyData('8'),
    _KeyData('9'),
    _KeyData('÷', operator: true, semantics: 'Divide'),
    _KeyData('4'),
    _KeyData('5'),
    _KeyData('6'),
    _KeyData('×', operator: true, semantics: 'Multiply'),
    _KeyData('1'),
    _KeyData('2'),
    _KeyData('3'),
    _KeyData('-', operator: true, semantics: 'Subtract'),
    _KeyData('.'),
    _KeyData('0'),
    _KeyData('backspace', semantics: 'Backspace'),
    _KeyData('+', operator: true, semantics: 'Add'),
  ];

  final ValueChanged<String> onKeyPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyWidth = (constraints.maxWidth - 24) / 4;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _keys
              .map((data) {
                return SizedBox(
                  width: keyWidth,
                  height: keyWidth / 1.35,
                  child: Semantics(
                    button: true,
                    label: data.semantics ?? data.value,
                    child: Material(
                      color: data.operator
                          ? const Color(0xFFE5ECE7)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        key: ValueKey('keypad_${data.value}'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onKeyPressed(data.value),
                        child: Center(
                          child: data.value == 'backspace'
                              ? const Icon(Icons.backspace_outlined, size: 23)
                              : Text(
                                  data.value,
                                  style: TextStyle(
                                    color:
                                        _TransactionEntryScreenState._inkColor,
                                    fontSize: data.operator ? 25 : 23,
                                    fontWeight: data.operator
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 17,
          color: Color(0xFFD7443E),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFD7443E), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _KeyData {
  const _KeyData(this.value, {this.operator = false, this.semantics});

  final String value;
  final bool operator;
  final String? semantics;
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
