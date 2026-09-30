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
          title: 'KyatFlow backup',
          subject: 'KyatFlow local CSV backup',
          text: 'KyatFlow local data backup',
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
    'amount',
    'category_id',
    'timestamp_epoch_ms',
    'timestamp_iso8601',
    'note',
  ];

  String encode(DatabaseBackupSnapshot snapshot) {
    final rows = <List<Object?>>[_columns];
    for (final category in snapshot.categories) {
      rows.add([
        'category',
        category['id'],
        category['name'],
        category['icon'],
        category['color'],
        category['type'],
        null,
        null,
        null,
        null,
        null,
      ]);
    }
    for (final transaction in snapshot.transactions) {
      final timestamp = transaction['timestamp'] as int;
      rows.add([
        'transaction',
        transaction['id'],
        null,
        null,
        null,
        transaction['type'],
        transaction['amount'],
        transaction['category_id'],
        timestamp,
        DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String(),
        transaction['note'],
      ]);
    }
    return rows.map(_encodeRow).join('\r\n');
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
