import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_entry.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../providers/transaction_providers.dart';
import '../utils/category_icon_mapper.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  TransactionType _type = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(managedCategoriesProvider(true));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            key: const ValueKey('add_category'),
            tooltip: 'Add category',
            onPressed: () => _openEditor(),
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
              onRefresh: _reload,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  FinanceSegments<TransactionType>(
                    value: _type,
                    labels: const {
                      TransactionType.expense: 'Expense',
                      TransactionType.income: 'Income',
                    },
                    onChanged: (value) => setState(() => _type = value),
                    keyPrefix: 'manage_category_type',
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 12, 4, 28),
                    child: Text(
                      'Archived categories stay on old transactions and reports, '
                      'but no longer appear when adding a new entry.',
                      style: AppTheme.caption,
                    ),
                  ),
                  categories.when(
                    loading: () => const FinanceLoading(),
                    error: (_, _) => FinanceEmptyState(
                      icon: CupertinoIcons.exclamationmark_circle,
                      title: 'Could not load categories',
                      message: 'Pull down to try again.',
                      onRetry: _reload,
                    ),
                    data: (items) {
                      final visible = items
                          .where((category) => category.type == _type)
                          .toList(growable: false);
                      final active = visible
                          .where((category) => !category.isArchived)
                          .toList(growable: false);
                      final archived = visible
                          .where((category) => category.isArchived)
                          .toList(growable: false);
                      if (visible.isEmpty) {
                        return FinanceEmptyState(
                          icon: CupertinoIcons.square_grid_2x2,
                          title: 'No ${_type.name} categories',
                          message: 'Tap + to create your first category.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (active.isNotEmpty) ...[
                            const SectionHeading('Active'),
                            _CategoryGroup(
                              categories: active,
                              onTap: _showActions,
                            ),
                          ],
                          if (archived.isNotEmpty) ...[
                            if (active.isNotEmpty) const SizedBox(height: 28),
                            const SectionHeading('Archived'),
                            _CategoryGroup(
                              categories: archived,
                              onTap: _showActions,
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

  Future<void> _reload() async {
    ref.invalidate(managedCategoriesProvider(true));
    await ref.read(managedCategoriesProvider(true).future);
  }

  Future<void> _openEditor([TransactionCategory? category]) async {
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: category == null,
        builder: (_) => _CategoryEditorScreen(
          initialCategory: category,
          initialType: _type,
        ),
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(managedCategoriesProvider(true));
    }
  }

  Future<void> _showActions(TransactionCategory category) async {
    HapticFeedback.selectionClick();
    final action = await showCupertinoModalPopup<_CategoryAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(category.name),
        message: Text(
          category.isArchived
              ? 'This category is hidden from new transactions.'
              : 'Choose how you want to manage this category.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _CategoryAction.edit),
            child: const Text('Edit category'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              context,
              category.isArchived
                  ? _CategoryAction.restore
                  : _CategoryAction.archive,
            ),
            child: Text(
              category.isArchived ? 'Restore category' : 'Archive category',
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, _CategoryAction.delete),
            child: const Text('Delete permanently'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _CategoryAction.edit:
        await _openEditor(category);
        return;
      case _CategoryAction.archive:
        await _setArchived(category, archived: true);
        return;
      case _CategoryAction.restore:
        await _setArchived(category, archived: false);
        return;
      case _CategoryAction.delete:
        await _delete(category);
        return;
    }
  }

  Future<void> _setArchived(
    TransactionCategory category, {
    required bool archived,
  }) async {
    if (archived) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Archive ${category.name}?'),
          content: const Text(
            'Old transactions and reports will keep this category. '
            'It will be hidden when you add a new transaction.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      await ref
          .read(transactionRepositoryProvider)
          .setCategoryArchived(category.id, archived: archived);
      if (!mounted) return;
      ref.invalidate(managedCategoriesProvider(true));
      _showMessage(archived ? 'Category archived' : 'Category restored');
    } catch (_) {
      if (mounted) _showMessage('Could not update this category');
    }
  }

  Future<void> _delete(TransactionCategory category) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text(
          'A category can only be deleted when no transactions, budgets, '
          'or recurring rules use it.',
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
    try {
      await ref.read(transactionRepositoryProvider).deleteCategory(category.id);
      if (!mounted) return;
      ref.invalidate(managedCategoriesProvider(true));
      _showMessage('Category deleted');
    } on CategoryInUseException {
      if (!mounted) return;
      _showMessage('This category is in use. Archive it instead.');
    } catch (_) {
      if (mounted) _showMessage('Could not delete this category');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({required this.categories, required this.onTap});

  final List<TransactionCategory> categories;
  final ValueChanged<TransactionCategory> onTap;

  @override
  Widget build(BuildContext context) => SurfaceGroup(
    separatorInset: 70,
    children: [
      for (final category in categories)
        CupertinoButton(
          key: ValueKey('manage_category_${category.id}'),
          padding: EdgeInsets.zero,
          onPressed: () => onTap(category),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(category.color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    categoryIconFromKey(category.icon),
                    color: Color(category.color),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      color: category.isArchived
                          ? AppTheme.secondary
                          : AppTheme.ink,
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
                const Icon(
                  CupertinoIcons.ellipsis,
                  color: AppTheme.secondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _CategoryEditorScreen extends ConsumerStatefulWidget {
  const _CategoryEditorScreen({
    required this.initialCategory,
    required this.initialType,
  });

  final TransactionCategory? initialCategory;
  final TransactionType initialType;

  @override
  ConsumerState<_CategoryEditorScreen> createState() =>
      _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends ConsumerState<_CategoryEditorScreen> {
  static const _icons = <String>[
    'restaurant',
    'directions_bus',
    'shopping_bag',
    'receipt_long',
    'medical_services',
    'cigarettes',
    'debt',
    'internet',
    'subscription',
    'movie',
    'rent',
    'family',
    'phone',
    'utilities',
    'drinks',
    'education',
    'travel',
    'clothing',
    'personal',
    'pets',
    'account_balance_wallet',
    'work',
    'card_giftcard',
    'savings',
    'category',
  ];
  static const _colors = <int>[
    0xFF246B55,
    0xFF2D6A9F,
    0xFF6D5AA8,
    0xFFB05D32,
    0xFFBB443A,
    0xFF88713B,
    0xFF43766C,
    0xFF8D4D72,
    0xFF1F7A8C,
    0xFF2F855A,
    0xFFB7791F,
    0xFF3F51B5,
    0xFFB23A48,
    0xFF5C677D,
    0xFF6B705C,
    0xFF9D4EDD,
    0xFFE07A5F,
    0xFF4D908E,
  ];

  late final TextEditingController _nameController;
  late TransactionType _type;
  late String _icon;
  late int _color;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _type = initial?.type ?? widget.initialType;
    _icon = initial?.icon ?? _icons.first;
    _color = initial?.color ?? _colors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialCategory != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit category' : 'New category'),
        leading: IconButton(
          tooltip: 'Cancel',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(CupertinoIcons.xmark, size: 20),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (!editing) ...[
                  FinanceSegments<TransactionType>(
                    value: _type,
                    labels: const {
                      TransactionType.expense: 'Expense',
                      TransactionType.income: 'Income',
                    },
                    onChanged: (value) => setState(() => _type = value),
                    keyPrefix: 'new_category_type',
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  key: const ValueKey('category_name'),
                  controller: _nameController,
                  autofocus: !editing,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 24),
                const SectionHeading('Icon'),
                _ChoiceGrid<String>(
                  values: _icons,
                  selected: _icon,
                  itemBuilder: (icon) => Icon(
                    categoryIconFromKey(icon),
                    color: _icon == icon ? Colors.white : AppTheme.ink,
                    size: 21,
                  ),
                  tooltipBuilder: categoryIconLabel,
                  onSelected: (icon) => setState(() => _icon = icon),
                ),
                const SizedBox(height: 28),
                const SectionHeading('Color'),
                _ChoiceGrid<int>(
                  values: _colors,
                  selected: _color,
                  itemBuilder: (color) => Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: _color == color
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                  onSelected: (color) => setState(() => _color = color),
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
                  key: const ValueKey('save_category'),
                  onPressed: _saving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _saving
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Text(editing ? 'Save changes' : 'Add category'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a category name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(transactionRepositoryProvider);
      final initial = widget.initialCategory;
      final existingCategories = await repository.getCategories(
        includeArchived: true,
      );
      final nameIsUsed = existingCategories.any(
        (category) =>
            category.id != initial?.id &&
            category.type == _type &&
            category.name.toLowerCase() == name.toLowerCase(),
      );
      if (nameIsUsed) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = 'A ${_type.name} category already uses this name.';
        });
        return;
      }
      if (initial == null) {
        await repository.addCategory(
          TransactionCategoryDraft(
            name: name,
            icon: _icon,
            color: _color,
            type: _type,
          ),
        );
      } else {
        await repository.editCategory(
          TransactionCategory(
            id: initial.id,
            name: name,
            icon: _icon,
            color: _color,
            type: initial.type,
            isArchived: initial.isArchived,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this category. Please try again.';
      });
    }
  }
}

class _ChoiceGrid<T> extends StatelessWidget {
  const _ChoiceGrid({
    required this.values,
    required this.selected,
    required this.itemBuilder,
    required this.onSelected,
    this.tooltipBuilder,
  });

  final List<T> values;
  final T selected;
  final Widget Function(T value) itemBuilder;
  final ValueChanged<T> onSelected;
  final String Function(T value)? tooltipBuilder;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [for (final value in values) _buildChoice(context, value)],
  );

  Widget _buildChoice(BuildContext context, T value) {
    final choice = AnimatedContainer(
      duration: AppTheme.motion(context, 180),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: value == selected ? AppTheme.accent : AppTheme.surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => onSelected(value),
        child: itemBuilder(value),
      ),
    );
    final label = tooltipBuilder?.call(value);
    return label == null ? choice : Tooltip(message: label, child: choice);
  }
}

enum _CategoryAction { edit, archive, restore, delete }
