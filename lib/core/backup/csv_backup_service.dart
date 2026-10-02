import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();
typedef ShareInvoker = Future<ShareResult> Function(ShareParams params);

class CsvBackupService {
  factory CsvBackupService({
    required DatabaseHelper databaseHelper,
    DocumentsDirectoryProvider? documentsDirectoryProvider,
    ShareInvoker? shareInvoker,
    DateTime Function()? clock,
  }) {
    return CsvBackupService._(
      databaseHelper,
      documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
      shareInvoker ?? SharePlus.instance.share,
      clock ?? DateTime.now,
    );
  }

  CsvBackupService._(
    this._databaseHelper,
    this._documentsDirectoryProvider,
    this._shareInvoker,
    this._clock,
  );

  final DatabaseHelper _databaseHelper;
  final DocumentsDirectoryProvider _documentsDirectoryProvider;
  final ShareInvoker _shareInvoker;
  final DateTime Function() _clock;

  Future<File> createBackup() async {
    final snapshot = await _databaseHelper.getBackupSnapshot();
    final directory = await _documentsDirectoryProvider();
    final exportDirectory = Directory(
      p.join(directory.path, 'kyatflow_exports'),
    );
    await exportDirectory.create(recursive: true);
    final generatedAt = _clock();
    final file = File(p.join(exportDirectory.path, _fileName(generatedAt)));
    await file.writeAsString(
      '\uFEFF${CsvBackupEncoder().encode(snapshot)}',
      flush: true,
    );
    return file;
  }

  Future<BackupShareResult> createAndShare({Rect? sharePositionOrigin}) async {
    final file = await createBackup();
    try {
      final shareResult = await _shareInvoker(
        ShareParams(
          title: 'Kyat Flow backup',
          subject: 'Kyat Flow local CSV backup',
          text: 'Kyat Flow local data backup',
          files: [XFile(file.path, mimeType: 'text/csv')],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return BackupShareResult(file: file, shareResult: shareResult);
    } catch (error) {
      throw BackupShareException(file: file, cause: error);
    }
  }

  String _fileName(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return 'kyatflow-backup-${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}.csv';
  }
}

class BackupShareException implements Exception {
  const BackupShareException({required this.file, required this.cause});

  final File file;
  final Object cause;

  @override
  String toString() => 'BackupShareException: $cause';
}

class BackupShareResult {
  const BackupShareResult({required this.file, required this.shareResult});

  final File file;
  final ShareResult shareResult;
}

class CsvBackupEncoder {
  static const _columns = [
    'record_type',
    'id',
    'name',
    'icon',
    'color',
    'type',
    'is_archived',
    'amount',
    'category_id',
    'timestamp_epoch_ms',
    'timestamp_iso8601',
    'note',
    'amount_limit',
    'month',
    'year',
    'alert_percentage',
    'frequency',
    'last_executed_epoch_ms',
    'last_executed_iso8601',
  ];

  String encode(DatabaseBackupSnapshot snapshot) {
    final rows = <List<Object?>>[_columns];
    for (final category in snapshot.categories) {
      rows.add(
        _row({
          'record_type': 'category',
          'id': category['id'],
          'name': category['name'],
          'icon': category['icon'],
          'color': category['color'],
          'type': category['type'],
          'is_archived': category['is_archived'],
        }),
      );
    }
    for (final transaction in snapshot.transactions) {
      final timestamp = transaction['timestamp'] as int;
      rows.add(
        _row({
          'record_type': 'transaction',
          'id': transaction['id'],
          'type': transaction['type'],
          'amount': transaction['amount'],
          'category_id': transaction['category_id'],
          'timestamp_epoch_ms': timestamp,
          'timestamp_iso8601': _iso8601(timestamp),
          'note': transaction['note'],
        }),
      );
    }
    for (final budget in snapshot.budgets) {
      rows.add(
        _row({
          'record_type': 'budget',
          'id': budget['id'],
          'category_id': budget['category_id'],
          'amount_limit': budget['amount_limit'],
          'month': budget['month'],
          'year': budget['year'],
          'alert_percentage': budget['alert_percentage'],
        }),
      );
    }
    for (final rule in snapshot.recurringRules) {
      final lastExecuted = rule['last_executed'] as int?;
      rows.add(
        _row({
          'record_type': 'recurring_rule',
          'id': rule['id'],
          'name': rule['name'],
          'type': rule['type'],
          'amount': rule['amount'],
          'category_id': rule['category_id'],
          'frequency': rule['frequency'],
          'last_executed_epoch_ms': lastExecuted,
          'last_executed_iso8601': lastExecuted == null
              ? null
              : _iso8601(lastExecuted),
        }),
      );
    }
    return rows.map(_encodeRow).join('\r\n');
  }

  List<Object?> _row(Map<String, Object?> values) {
    return _columns.map((column) => values[column]).toList(growable: false);
  }

  String _iso8601(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds).toIso8601String();
  }

  String _encodeRow(List<Object?> row) => row.map(_encodeCell).join(',');

  String _encodeCell(Object? value) {
    if (value == null) return '""';
    var text = value.toString();
    // Quoting alone does not stop spreadsheet apps from executing formulas.
    if (value is String && RegExp(r'^\s*[=+\-@]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}
