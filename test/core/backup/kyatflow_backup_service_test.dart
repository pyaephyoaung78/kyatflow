import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/backup/kyatflow_backup_service.dart';
import 'package:kyatflow/core/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late DatabaseHelper source;
  late DatabaseHelper destination;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kyatflow_restore_test_');
    source = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'source.db'),
    );
    destination = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'destination.db'),
    );
  });

  tearDown(() async {
    await source.close();
    await destination.close();
    await directory.delete(recursive: true);
  });

  test('creates and reads a versioned restorable backup', () async {
    await _addSourceRecords(source);
    final service = KyatFlowBackupService(
      databaseHelper: source,
      documentsDirectoryProvider: () async => directory,
      clock: () => DateTime(2026, 10, 14, 9, 8, 7),
    );

    final file = await service.createBackup();
    final selected = service.readBackup(
      await file.readAsBytes(),
      fileName: p.basename(file.path),
    );

    expect(file.path, endsWith('kyatflow-backup-20261014-090807.kyatflow'));
    expect(selected.document.generatedAt, DateTime(2026, 10, 14, 9, 8, 7));
    expect(selected.document.snapshot.categories, hasLength(11));
    expect(selected.document.snapshot.transactions, hasLength(1));
    expect(selected.document.snapshot.budgets, hasLength(1));
    expect(selected.document.snapshot.recurringRules, hasLength(1));
  });

  test(
    'replace restores the backup exactly and removes current data',
    () async {
      await _addSourceRecords(source);
      final sourceSnapshot = await source.getBackupSnapshot();
      final backup = SelectedKyatFlowBackup(
        fileName: 'replace.kyatflow',
        document: KyatFlowBackupDocument(
          generatedAt: DateTime(2026, 10, 14),
          snapshot: sourceSnapshot,
        ),
      );
      final localCategory = await destination.insertCategory(
        name: 'Local only',
        icon: 'category',
        color: 0xFF112233,
        type: 'expense',
      );
      await destination.insertTransaction(
        amount: 999,
        type: 'expense',
        categoryId: localCategory,
        timestamp: DateTime(2026, 10, 1),
        note: 'Remove me',
      );

      final result = await KyatFlowBackupService(
        databaseHelper: destination,
      ).restore(backup, mode: DatabaseRestoreMode.replace);
      final restored = await destination.getBackupSnapshot();

      expect(result.recordsAdded, 14);
      expect(restored.categories, sourceSnapshot.categories);
      expect(restored.transactions, sourceSnapshot.transactions);
      expect(restored.budgets, sourceSnapshot.budgets);
      expect(restored.recurringRules, sourceSnapshot.recurringRules);
    },
  );

  test('merge remaps category IDs and remains idempotent', () async {
    await _addSourceRecords(source);
    final sourceSnapshot = await source.getBackupSnapshot();
    final backup = SelectedKyatFlowBackup(
      fileName: 'merge.kyatflow',
      document: KyatFlowBackupDocument(
        generatedAt: DateTime(2026, 10, 14),
        snapshot: sourceSnapshot,
      ),
    );
    final collidingId = await destination.insertCategory(
      name: 'Local only',
      icon: 'category',
      color: 0xFF112233,
      type: 'expense',
    );
    expect(collidingId, 11);
    final service = KyatFlowBackupService(databaseHelper: destination);

    final first = await service.restore(
      backup,
      mode: DatabaseRestoreMode.merge,
    );
    final categories = await destination.getCategories(includeArchived: true);
    final coffee = categories.singleWhere((row) => row['name'] == 'Coffee');
    final transactions = await destination.getTransactions();

    expect(first.recordsAdded, 4);
    expect(first.skippedRecords, 10);
    expect(coffee['id'], isNot(collidingId));
    expect(transactions.single['category_id'], coffee['id']);

    final second = await service.restore(
      backup,
      mode: DatabaseRestoreMode.merge,
    );
    expect(second.recordsAdded, 0);
    expect(second.skippedRecords, 14);
  });

  test('rejects a backup with a missing category relationship', () {
    final data = {
      'format': KyatFlowBackupDocument.formatName,
      'format_version': KyatFlowBackupDocument.formatVersion,
      'database_schema_version': DatabaseHelper.databaseVersion,
      'generated_at': '2026-10-14T09:00:00.000',
      'data': {
        'categories': [
          {
            'id': 1,
            'name': 'Food',
            'icon': 'restaurant',
            'color': 0xFFFF9800,
            'type': 'expense',
            'is_archived': 0,
          },
        ],
        'transactions': [
          {
            'id': 1,
            'amount': 1000,
            'type': 'expense',
            'category_id': 99,
            'timestamp': 1,
            'note': null,
          },
        ],
        'budgets': <Object?>[],
        'recurring_rules': <Object?>[],
      },
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    final service = KyatFlowBackupService(databaseHelper: destination);

    expect(
      () => service.readBackup(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.message,
          'message',
          contains('category that is missing'),
        ),
      ),
    );
  });

  test('reads version 1 backups and upgrades recurring schedules', () {
    final lastExecuted = DateTime(2026, 1, 31).millisecondsSinceEpoch;
    final data = {
      'format': KyatFlowBackupDocument.formatName,
      'format_version': 1,
      'database_schema_version': 4,
      'generated_at': '2026-10-14T09:00:00.000',
      'data': {
        'categories': [
          {
            'id': 1,
            'name': 'Bills',
            'icon': 'receipt_long',
            'color': 0xFF123456,
            'type': 'expense',
            'is_archived': 0,
          },
        ],
        'transactions': <Object?>[],
        'budgets': <Object?>[],
        'recurring_rules': [
          {
            'id': 1,
            'name': 'Internet',
            'amount': 30000,
            'category_id': 1,
            'type': 'expense',
            'frequency': 'monthly',
            'last_executed': lastExecuted,
          },
        ],
      },
    };
    final service = KyatFlowBackupService(databaseHelper: destination);
    final backup = service.readBackup(
      Uint8List.fromList(utf8.encode(jsonEncode(data))),
    );
    final rule = backup.document.snapshot.recurringRules.single;

    expect(rule['first_due'], lastExecuted);
    expect(rule['next_due'], DateTime(2026, 2, 28).millisecondsSinceEpoch);
    expect(rule['is_active'], 1);
    expect(rule['note'], isNull);
  });
}

Future<void> _addSourceRecords(DatabaseHelper database) async {
  final coffeeId = await database.insertCategory(
    name: 'Coffee',
    icon: 'restaurant',
    color: 0xFF765432,
    type: 'expense',
  );
  await database.insertTransaction(
    amount: 2500,
    type: 'expense',
    categoryId: coffeeId,
    timestamp: DateTime(2026, 10, 14, 8, 30),
    note: 'Morning coffee',
  );
  await database.insertBudget(
    categoryId: coffeeId,
    amountLimit: 30000,
    month: 10,
    year: 2026,
  );
  await database.insertRecurringRule(
    name: 'Coffee beans',
    amount: 12000,
    categoryId: coffeeId,
    type: 'expense',
    frequency: 'monthly',
    lastExecuted: DateTime(2026, 10, 1),
  );
}
