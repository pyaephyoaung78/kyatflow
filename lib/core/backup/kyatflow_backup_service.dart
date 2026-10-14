import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../utils/recurrence_schedule.dart';

typedef BackupDirectoryProvider = Future<Directory> Function();
typedef BackupShareInvoker = Future<ShareResult> Function(ShareParams params);
typedef BackupFilePicker = Future<PlatformFile?> Function();

class KyatFlowBackupService {
  factory KyatFlowBackupService({
    required DatabaseHelper databaseHelper,
    BackupDirectoryProvider? documentsDirectoryProvider,
    BackupShareInvoker? shareInvoker,
    BackupFilePicker? filePicker,
    DateTime Function()? clock,
  }) {
    return KyatFlowBackupService._(
      databaseHelper,
      documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
      shareInvoker ?? SharePlus.instance.share,
      filePicker ?? _pickBackupFile,
      clock ?? DateTime.now,
    );
  }

  KyatFlowBackupService._(
    this._databaseHelper,
    this._documentsDirectoryProvider,
    this._shareInvoker,
    this._filePicker,
    this._clock,
  );

  static const maxBackupBytes = 25 * 1024 * 1024;

  final DatabaseHelper _databaseHelper;
  final BackupDirectoryProvider _documentsDirectoryProvider;
  final BackupShareInvoker _shareInvoker;
  final BackupFilePicker _filePicker;
  final DateTime Function() _clock;

  Future<File> createBackup() async {
    final snapshot = await _databaseHelper.getBackupSnapshot();
    final generatedAt = _clock();
    final document = KyatFlowBackupDocument(
      generatedAt: generatedAt,
      snapshot: snapshot,
    );
    final root = await _documentsDirectoryProvider();
    final directory = Directory(p.join(root.path, 'kyatflow_backups'));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, _fileName(generatedAt)));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document.toJson()),
      flush: true,
    );
    return file;
  }

  Future<KyatFlowBackupShareResult> createAndShare({
    Rect? sharePositionOrigin,
  }) async {
    final file = await createBackup();
    try {
      final result = await _shareInvoker(
        ShareParams(
          title: 'Kyat Flow backup',
          subject: 'Kyat Flow restorable backup',
          text: 'Kyat Flow local backup',
          files: [XFile(file.path, mimeType: 'application/json')],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return KyatFlowBackupShareResult(file: file, shareResult: result);
    } catch (error) {
      throw KyatFlowBackupShareException(file: file, cause: error);
    }
  }

  Future<SelectedKyatFlowBackup?> pickBackup() async {
    final file = await _filePicker();
    if (file == null) return null;
    final length = await file.length();
    if (length > maxBackupBytes) {
      throw const BackupValidationException(
        'This backup is larger than the supported 25 MB limit.',
      );
    }
    final bytes = await file.readAsBytes();
    return readBackup(bytes, fileName: file.name);
  }

  SelectedKyatFlowBackup readBackup(
    Uint8List bytes, {
    String fileName = 'Kyat Flow backup',
  }) {
    if (bytes.length > maxBackupBytes) {
      throw const BackupValidationException(
        'This backup is larger than the supported 25 MB limit.',
      );
    }
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      final decoded = jsonDecode(text);
      final document = KyatFlowBackupDocument.fromJson(decoded);
      return SelectedKyatFlowBackup(fileName: fileName, document: document);
    } on BackupValidationException {
      rethrow;
    } on FormatException catch (error) {
      throw BackupValidationException(
        'This file is not a valid Kyat Flow backup.',
        cause: error,
      );
    } catch (error) {
      throw BackupValidationException(
        'This file is damaged or uses an unsupported backup format.',
        cause: error,
      );
    }
  }

  Future<DatabaseRestoreResult> restore(
    SelectedKyatFlowBackup backup, {
    required DatabaseRestoreMode mode,
  }) {
    return _databaseHelper.restoreBackupSnapshot(
      backup.document.snapshot,
      mode: mode,
    );
  }

  String _fileName(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return 'kyatflow-backup-${value.year}${two(value.month)}'
        '${two(value.day)}-${two(value.hour)}${two(value.minute)}'
        '${two(value.second)}.kyatflow';
  }

  static Future<PlatformFile?> _pickBackupFile() {
    return FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['kyatflow', 'json'],
    );
  }
}

class KyatFlowBackupDocument {
  KyatFlowBackupDocument({required this.generatedAt, required this.snapshot});

  static const formatName = 'kyatflow-backup';
  static const formatVersion = 2;
  static const minimumSupportedFormatVersion = 1;

  final DateTime generatedAt;
  final DatabaseBackupSnapshot snapshot;

  int get recordCount =>
      snapshot.categories.length +
      snapshot.transactions.length +
      snapshot.budgets.length +
      snapshot.recurringRules.length;

  Map<String, Object?> toJson() => {
    'format': formatName,
    'format_version': formatVersion,
    'database_schema_version': DatabaseHelper.databaseVersion,
    'generated_at': generatedAt.toIso8601String(),
    'data': {
      'categories': snapshot.categories,
      'transactions': snapshot.transactions,
      'budgets': snapshot.budgets,
      'recurring_rules': snapshot.recurringRules,
    },
  };

  factory KyatFlowBackupDocument.fromJson(Object? value) {
    final root = _BackupValidator.object(value, 'backup');
    if (root['format'] != formatName) {
      throw const BackupValidationException(
        'This file was not created by Kyat Flow.',
      );
    }
    final version = _BackupValidator.integer(
      root['format_version'],
      'format_version',
    );
    if (version < minimumSupportedFormatVersion || version > formatVersion) {
      throw BackupValidationException(
        'Backup version $version is not supported by this app.',
      );
    }
    final schemaVersion = _BackupValidator.integer(
      root['database_schema_version'],
      'database_schema_version',
    );
    if (schemaVersion > DatabaseHelper.databaseVersion) {
      throw const BackupValidationException(
        'This backup was created by a newer version of Kyat Flow.',
      );
    }
    final generatedAtText = _BackupValidator.string(
      root['generated_at'],
      'generated_at',
    );
    final generatedAt = DateTime.tryParse(generatedAtText);
    if (generatedAt == null) {
      throw const BackupValidationException(
        'The backup creation date is invalid.',
      );
    }
    final data = _BackupValidator.object(root['data'], 'data');
    final validator = _BackupValidator(
      legacyReference: generatedAt,
      allowLegacyRecurringFields: version == 1,
    );
    final snapshot = validator.snapshot(data);
    return KyatFlowBackupDocument(generatedAt: generatedAt, snapshot: snapshot);
  }
}

class SelectedKyatFlowBackup {
  const SelectedKyatFlowBackup({
    required this.fileName,
    required this.document,
  });

  final String fileName;
  final KyatFlowBackupDocument document;
}

class KyatFlowBackupShareResult {
  const KyatFlowBackupShareResult({
    required this.file,
    required this.shareResult,
  });

  final File file;
  final ShareResult shareResult;
}

class KyatFlowBackupShareException implements Exception {
  const KyatFlowBackupShareException({required this.file, required this.cause});

  final File file;
  final Object cause;
}

class BackupValidationException implements Exception {
  const BackupValidationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class _BackupValidator {
  _BackupValidator({
    required this.legacyReference,
    required this.allowLegacyRecurringFields,
  });

  final DateTime legacyReference;
  final bool allowLegacyRecurringFields;
  final _categoryIds = <int>{};
  final _categoryTypes = <int, String>{};

  DatabaseBackupSnapshot snapshot(Map<String, Object?> data) {
    final categories = _rows(data['categories'], 'categories', _category);
    if (categories.isEmpty) {
      throw const BackupValidationException(
        'The backup must contain at least one category.',
      );
    }
    final transactions = _rows(
      data['transactions'],
      'transactions',
      _transaction,
    );
    final budgets = _rows(data['budgets'], 'budgets', _budget);
    final recurringRules = _rows(
      data['recurring_rules'],
      'recurring_rules',
      _recurringRule,
    );
    _requireUniqueIds(categories, 'categories');
    _requireUniqueIds(transactions, 'transactions');
    _requireUniqueIds(budgets, 'budgets');
    _requireUniqueIds(recurringRules, 'recurring_rules');
    _requireUniqueBudgets(budgets);
    return DatabaseBackupSnapshot(
      categories: categories,
      transactions: transactions,
      budgets: budgets,
      recurringRules: recurringRules,
    );
  }

  Map<String, Object?> _category(Map<String, Object?> row, String path) {
    final id = positiveInteger(row['id'], '$path.id');
    final type = transactionType(row['type'], '$path.type');
    if (!_categoryIds.add(id)) {
      throw BackupValidationException('Duplicate category ID $id.');
    }
    _categoryTypes[id] = type;
    final archived = integer(row['is_archived'], '$path.is_archived');
    if (archived != 0 && archived != 1) {
      throw BackupValidationException('$path.is_archived must be 0 or 1.');
    }
    final color = integer(row['color'], '$path.color');
    if (color < 0 || color > 0xFFFFFFFF) {
      throw BackupValidationException('$path.color is invalid.');
    }
    return {
      'id': id,
      'name': nonEmptyString(row['name'], '$path.name'),
      'icon': nonEmptyString(row['icon'], '$path.icon'),
      'color': color,
      'type': type,
      'is_archived': archived,
    };
  }

  Map<String, Object?> _transaction(Map<String, Object?> row, String path) {
    final categoryId = positiveInteger(row['category_id'], '$path.category_id');
    final type = transactionType(row['type'], '$path.type');
    _requireCategory(categoryId, type, path);
    final note = row['note'];
    if (note != null && note is! String) {
      throw BackupValidationException('$path.note must be text or null.');
    }
    return {
      'id': positiveInteger(row['id'], '$path.id'),
      'amount': positiveNumber(row['amount'], '$path.amount'),
      'type': type,
      'category_id': categoryId,
      'timestamp': integer(row['timestamp'], '$path.timestamp'),
      'note': note,
    };
  }

  Map<String, Object?> _budget(Map<String, Object?> row, String path) {
    final categoryId = positiveInteger(row['category_id'], '$path.category_id');
    _requireCategory(categoryId, 'expense', path);
    final month = integer(row['month'], '$path.month');
    final year = integer(row['year'], '$path.year');
    final alert = positiveNumber(
      row['alert_percentage'],
      '$path.alert_percentage',
    );
    if (month < 1 || month > 12 || year < 1 || year > 9999 || alert > 100) {
      throw BackupValidationException('$path contains invalid budget values.');
    }
    return {
      'id': positiveInteger(row['id'], '$path.id'),
      'category_id': categoryId,
      'amount_limit': positiveNumber(row['amount_limit'], '$path.amount_limit'),
      'month': month,
      'year': year,
      'alert_percentage': alert,
    };
  }

  Map<String, Object?> _recurringRule(Map<String, Object?> row, String path) {
    final categoryId = positiveInteger(row['category_id'], '$path.category_id');
    final type = transactionType(row['type'], '$path.type');
    _requireCategory(categoryId, type, path);
    final frequency = string(row['frequency'], '$path.frequency');
    if (!const {'daily', 'weekly', 'monthly', 'yearly'}.contains(frequency)) {
      throw BackupValidationException('$path.frequency is invalid.');
    }
    final lastExecuted = row['last_executed'];
    if (lastExecuted != null && lastExecuted is! int) {
      throw BackupValidationException(
        '$path.last_executed must be an integer or null.',
      );
    }
    final firstDueValue = row['first_due'];
    final nextDueValue = row['next_due'];
    final activeValue = row['is_active'];
    if (!allowLegacyRecurringFields &&
        (firstDueValue == null ||
            nextDueValue == null ||
            activeValue == null)) {
      throw BackupValidationException(
        '$path is missing recurring schedule fields.',
      );
    }
    final firstDue = firstDueValue == null
        ? (lastExecuted as int?) ?? legacyReference.millisecondsSinceEpoch
        : integer(firstDueValue, '$path.first_due');
    final nextDue = nextDueValue == null
        ? lastExecuted == null
              ? firstDue
              : RecurrenceSchedule.nextOccurrence(
                  DateTime.fromMillisecondsSinceEpoch(lastExecuted as int),
                  frequency,
                  anchor: DateTime.fromMillisecondsSinceEpoch(firstDue),
                ).millisecondsSinceEpoch
        : integer(nextDueValue, '$path.next_due');
    if (nextDue < firstDue) {
      throw BackupValidationException(
        '$path.next_due must not be before first_due.',
      );
    }
    final active = activeValue == null
        ? 1
        : integer(activeValue, '$path.is_active');
    if (active != 0 && active != 1) {
      throw BackupValidationException('$path.is_active must be 0 or 1.');
    }
    final note = row['note'];
    if (note != null && note is! String) {
      throw BackupValidationException('$path.note must be text or null.');
    }
    return {
      'id': positiveInteger(row['id'], '$path.id'),
      'name': nonEmptyString(row['name'], '$path.name'),
      'amount': positiveNumber(row['amount'], '$path.amount'),
      'category_id': categoryId,
      'type': type,
      'frequency': frequency,
      'first_due': firstDue,
      'next_due': nextDue,
      'last_executed': lastExecuted,
      'is_active': active,
      'note': note,
    };
  }

  void _requireCategory(int id, String type, String path) {
    final categoryType = _categoryTypes[id];
    if (categoryType == null) {
      throw BackupValidationException(
        '$path references a category that is missing from the backup.',
      );
    }
    if (categoryType != type) {
      throw BackupValidationException(
        '$path does not match the referenced category type.',
      );
    }
  }

  void _requireUniqueIds(List<Map<String, Object?>> rows, String table) {
    final ids = <int>{};
    for (final row in rows) {
      final id = row['id'] as int;
      if (!ids.add(id)) {
        throw BackupValidationException('Duplicate ID $id in $table.');
      }
    }
  }

  void _requireUniqueBudgets(List<Map<String, Object?>> budgets) {
    final identities = <(int, int, int)>{};
    for (final row in budgets) {
      final identity = (
        row['category_id'] as int,
        row['month'] as int,
        row['year'] as int,
      );
      if (!identities.add(identity)) {
        throw const BackupValidationException(
          'The backup contains duplicate monthly budgets.',
        );
      }
    }
  }

  List<Map<String, Object?>> _rows(
    Object? value,
    String path,
    Map<String, Object?> Function(Map<String, Object?>, String) convert,
  ) {
    if (value is! List) {
      throw BackupValidationException('$path must be a list.');
    }
    return [
      for (var index = 0; index < value.length; index++)
        convert(object(value[index], '$path[$index]'), '$path[$index]'),
    ];
  }

  static Map<String, Object?> object(Object? value, String path) {
    if (value is! Map) {
      throw BackupValidationException('$path must be an object.');
    }
    try {
      return Map<String, Object?>.from(value);
    } catch (_) {
      throw BackupValidationException('$path contains invalid keys.');
    }
  }

  static String string(Object? value, String path) {
    if (value is! String) {
      throw BackupValidationException('$path must be text.');
    }
    return value;
  }

  static String nonEmptyString(Object? value, String path) {
    final result = string(value, path).trim();
    if (result.isEmpty) {
      throw BackupValidationException('$path must not be empty.');
    }
    return result;
  }

  static int integer(Object? value, String path) {
    if (value is! int) {
      throw BackupValidationException('$path must be an integer.');
    }
    return value;
  }

  static int positiveInteger(Object? value, String path) {
    final result = integer(value, path);
    if (result <= 0) {
      throw BackupValidationException('$path must be positive.');
    }
    return result;
  }

  static double positiveNumber(Object? value, String path) {
    if (value is! num) {
      throw BackupValidationException('$path must be a number.');
    }
    final result = value.toDouble();
    if (!result.isFinite || result <= 0) {
      throw BackupValidationException('$path must be finite and positive.');
    }
    return result;
  }

  static String transactionType(Object? value, String path) {
    final result = string(value, path);
    if (result != 'income' && result != 'expense') {
      throw BackupValidationException('$path must be income or expense.');
    }
    return result;
  }
}
