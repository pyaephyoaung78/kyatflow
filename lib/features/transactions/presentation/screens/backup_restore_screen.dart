import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backup/kyatflow_backup_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../../budgets/presentation/providers/budget_providers.dart';
import '../providers/transaction_providers.dart';
import '../utils/finance_formatters.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  _BackupOperation? _operation;

  bool get _busy => _operation != null;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup & restore')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const SurfaceGroup(
                separated: false,
                children: [
                  Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          CupertinoIcons.lock_shield,
                          color: AppTheme.accent,
                          size: 30,
                        ),
                        SizedBox(height: 14),
                        Text('Your data stays yours', style: AppTheme.section),
                        SizedBox(height: 7),
                        Text(
                          'A Kyat Flow backup contains your categories, '
                          'transactions, budgets, and recurring rules. Save it '
                          'somewhere safe before reinstalling or changing phones.',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionHeading('Backup file'),
              SurfaceGroup(
                children: [
                  _BackupActionRow(
                    key: const ValueKey('create_kyatflow_backup'),
                    icon: CupertinoIcons.square_arrow_up,
                    title: 'Create backup',
                    detail: 'Save or share a restorable .kyatflow file',
                    busy: _operation == _BackupOperation.create,
                    onTap: _busy ? null : _createBackup,
                  ),
                  _BackupActionRow(
                    key: const ValueKey('restore_kyatflow_backup'),
                    icon: CupertinoIcons.square_arrow_down,
                    title: 'Restore backup',
                    detail: 'Preview a backup before changing local data',
                    busy: _operation == _BackupOperation.restore,
                    onTap: _busy ? null : _chooseAndRestore,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                child: Text(
                  'Merge keeps your current records and skips duplicates. '
                  'Replace removes current records and restores the backup exactly.',
                  style: AppTheme.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _createBackup() async {
    setState(() => _operation = _BackupOperation.create);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await ref
          .read(kyatFlowBackupServiceProvider)
          .createAndShare(
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          );
      if (mounted) _showMessage('Backup created');
    } on KyatFlowBackupShareException {
      if (mounted) {
        _showMessage('Backup saved, but the share menu could not open.');
      }
    } catch (_) {
      if (mounted) _showMessage('Could not create the backup.');
    } finally {
      if (mounted) setState(() => _operation = null);
    }
  }

  Future<void> _chooseAndRestore() async {
    setState(() => _operation = _BackupOperation.restore);
    SelectedKyatFlowBackup? backup;
    try {
      backup = await ref.read(kyatFlowBackupServiceProvider).pickBackup();
    } on BackupValidationException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Could not read the selected backup.');
    } finally {
      if (mounted) setState(() => _operation = null);
    }
    if (!mounted || backup == null) return;

    final mode = await _showRestorePreview(backup);
    if (!mounted || mode == null) return;
    if (mode == DatabaseRestoreMode.replace) {
      final confirmed = await _confirmReplace();
      if (!mounted || !confirmed) return;
    }

    setState(() => _operation = _BackupOperation.restore);
    try {
      final result = await ref
          .read(kyatFlowBackupServiceProvider)
          .restore(backup, mode: mode);
      _invalidateFinanceData();
      if (!mounted) return;
      await _showRestoreComplete(result);
    } catch (_) {
      if (mounted) {
        _showMessage('Restore failed. Your existing data was not changed.');
      }
    } finally {
      if (mounted) setState(() => _operation = null);
    }
  }

  Future<DatabaseRestoreMode?> _showRestorePreview(
    SelectedKyatFlowBackup backup,
  ) {
    final document = backup.document;
    final snapshot = document.snapshot;
    final generated = document.generatedAt.toLocal();
    final message =
        '${backup.fileName}\n'
        '${formatShortDate(generated)}, ${generated.year} · '
        '${formatTransactionTime(generated)}\n\n'
        '${snapshot.transactions.length} transactions · '
        '${snapshot.categories.length} categories\n'
        '${snapshot.budgets.length} budgets · '
        '${snapshot.recurringRules.length} recurring rules';
    return showCupertinoModalPopup<DatabaseRestoreMode>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Restore this backup?'),
        message: Text(message),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, DatabaseRestoreMode.merge),
            child: const Text('Merge with current data'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.pop(context, DatabaseRestoreMode.replace),
            child: const Text('Replace all current data'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<bool> _confirmReplace() async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Replace all current data?'),
            content: const Text(
              'Your current transactions, categories, budgets, and recurring '
              'rules will be removed and replaced with the backup.',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace and restore'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showRestoreComplete(DatabaseRestoreResult result) {
    final details = result.mode == DatabaseRestoreMode.replace
        ? '${result.recordsAdded} records restored.'
        : '${result.recordsAdded} records added. '
              '${result.skippedRecords} existing or duplicate records skipped.';
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Restore complete'),
        content: Text(details),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _invalidateFinanceData() {
    ref.invalidate(transactionStateProvider);
    ref.invalidate(dashboardStateProvider);
    ref.invalidate(ledgerStateProvider);
    ref.invalidate(analyticsStateProvider);
    ref.invalidate(managedCategoriesProvider);
    ref.invalidate(monthlyBudgetProgressProvider);
    ref.invalidate(monthlyBudgetIncomeProvider);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _BackupOperation { create, restore }

class _BackupActionRow extends StatelessWidget {
  const _BackupActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: busy
                ? const CupertinoActivityIndicator()
                : Icon(icon, size: 22, color: AppTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(detail, style: AppTheme.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: AppTheme.secondary,
          ),
        ],
      ),
    ),
  );
}
