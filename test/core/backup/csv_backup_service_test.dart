import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/core/backup/csv_backup_service.dart';
import 'package:kyatflow/core/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late DatabaseHelper database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kyatflow_backup_test_');
    database = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'creates a UTF-8 CSV containing every local record type',
    () async {
      final categories = await database.getCategories(type: 'expense');
      final foodId =
          categories.firstWhere((row) => row['name'] == 'Food')['id'] as int;
      await database.insertTransaction(
        amount: 1250.5,
        type: 'expense',
        categoryId: foodId,
        timestamp: DateTime(2026, 9, 30, 12, 45),
        note: '=SUM(1,2)\n"quoted"',
      );
      await database.insertBudget(
        categoryId: foodId,
        amountLimit: 50000,
        month: 9,
        year: 2026,
      );
      await database.insertRecurringRule(
        name: 'Weekly groceries',
        amount: 10000,
        categoryId: foodId,
        type: 'expense',
        frequency: 'weekly',
      );
      final service = CsvBackupService(
        databaseHelper: database,
        documentsDirectoryProvider: () async => directory,
        clock: () => DateTime(2026, 9, 30, 14, 5, 6),
      );

      final file = await service.createBackup();
      expect(file.path, endsWith('kyatflow-backup-20260930-140506.csv'));
      expect((await file.readAsBytes()).take(3), [0xEF, 0xBB, 0xBF]);
      final csv = await file.readAsString();
      expect(csv, contains('"record_type","id","name"'));
      expect(csv, contains('"category"'));
      expect(csv, contains('"transaction"'));
      expect(csv, contains('"budget"'));
      expect(csv, contains('"recurring_rule"'));
      expect(csv, contains('"Weekly groceries"'));
      expect(csv, contains('"1250.5"'));
      expect(csv, contains('"\'=SUM(1,2)\n""quoted"""'));
      expect(
        RegExp(r'^"category",', multiLine: true).allMatches(csv),
        hasLength(10),
      );
    },
  );

  test('shares the generated CSV through the injected share gateway', () async {
    ShareParams? captured;
    final service = CsvBackupService(
      databaseHelper: database,
      documentsDirectoryProvider: () async => directory,
      shareInvoker: (params) async {
        captured = params;
        return const ShareResult('test', ShareResultStatus.success);
      },
      clock: () => DateTime(2026, 9, 30),
    );

    final result = await service.createAndShare();
    expect(result.shareResult.status, ShareResultStatus.success);
    expect(captured, isNotNull);
    expect(captured!.files, hasLength(1));
    expect(captured!.files!.single.path, result.file.path);
    expect(captured!.files!.single.mimeType, 'text/csv');
  });

  test('reports the saved file when the platform cannot share it', () async {
    final service = CsvBackupService(
      databaseHelper: database,
      documentsDirectoryProvider: () async => directory,
      shareInvoker: (_) async => throw UnsupportedError('No file sharing'),
      clock: () => DateTime(2026, 9, 30),
    );

    try {
      await service.createAndShare();
      fail('Expected sharing to fail');
    } on BackupShareException catch (error) {
      expect(await error.file.exists(), isTrue);
      expect(error.cause, isA<UnsupportedError>());
    }
  });
}
