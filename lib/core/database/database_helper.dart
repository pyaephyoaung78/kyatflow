import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns KyatFlow's local SQLite connection and persistence operations.
///
/// Types are `income` or `expense`. Icons are stable string keys, colors are
/// integer ARGB values, and timestamps are milliseconds since the Unix epoch.
/// Returned rows belong in the data layer; map them to domain entities there.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const databaseName = 'kyatflow.db';
  static const databaseVersion = 1;

  DatabaseFactory? _factory;
  String? _path;
  Future<Database>? _opening;

  /// Allows tests to exercise the real schema in an isolated SQLite database.
  @visibleForTesting
  DatabaseHelper.forTesting({
    required DatabaseFactory databaseFactory,
    required String databasePath,
  }) : _factory = databaseFactory,
       _path = databasePath;

  /// Concurrent callers share the same pending open operation.
  Future<Database> get database async {
    final opening = _opening ??= _open();
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<void> initialize() async {
    await database;
  }

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path =
        _path ?? p.join(await factory.getDatabasesPath(), databaseName);
    return await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
      ),
    );
  }

  // sqflite already wraps onCreate in a transaction.
  Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        icon TEXT NOT NULL CHECK (length(trim(icon)) > 0),
        color INTEGER NOT NULL CHECK (color BETWEEN 0 AND 4294967295),
        type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
        UNIQUE (id, type)
      )
    ''');
    batch.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL CHECK (amount > 0),
        type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
        category_id INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        note TEXT,
        FOREIGN KEY (category_id, type) REFERENCES categories (id, type)
          ON UPDATE RESTRICT ON DELETE RESTRICT
      )
    ''');
    // The composite foreign key also prevents assigning an expense to an
    // income category, or changing the type of a category already in use.
    batch.execute('''
      CREATE INDEX idx_categories_type_name ON categories (type, name, id)
    ''');
    batch.execute('''
      CREATE INDEX idx_transactions_timestamp
      ON transactions (timestamp DESC, id DESC)
    ''');
    batch.execute('''
      CREATE INDEX idx_transactions_type_timestamp
      ON transactions (type, timestamp DESC, id DESC)
    ''');
    batch.execute('''
      CREATE INDEX idx_transactions_category_timestamp
      ON transactions (category_id, timestamp DESC, id DESC)
    ''');
    await batch.commit(noResult: true);
  }

  Future<int> insertCategory({
    required String name,
    required String icon,
    required int color,
    required String type,
  }) async {
    final values = _categoryValues(name, icon, color, type);
    return (await database).insert('categories', values);
  }

  Future<Map<String, Object?>?> getCategory(int id) async {
    final rows = await (await database).query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getCategories({String? type}) async {
    if (type != null) _validateType(type);
    return (await database).query(
      'categories',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : [type],
      orderBy: 'name ASC, id ASC',
    );
  }

  /// Replaces editable fields and returns the number of affected rows (0 or 1).
  Future<int> updateCategory({
    required int id,
    required String name,
    required String icon,
    required int color,
    required String type,
  }) async {
    final values = _categoryValues(name, icon, color, type);
    return (await database).update(
      'categories',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Throws [DatabaseException] when transactions still reference the category.
  Future<int> deleteCategory(int id) async {
    return (await database).delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertTransaction({
    required double amount,
    required String type,
    required int categoryId,
    required DateTime timestamp,
    String? note,
  }) async {
    final values = _transactionValues(
      amount,
      type,
      categoryId,
      timestamp,
      note,
    );
    return (await database).insert('transactions', values);
  }

  Future<Map<String, Object?>?> getTransaction(int id) async {
    final rows = await (await database).query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Returns newest rows first, with stable ordering for equal timestamps.
  ///
  /// Date bounds are inclusive start, exclusive end. Pass the first day of this
  /// month and next month to query a whole calendar month.
  /// Omitting [limit] returns all matches; [offset] supports paginated screens.
  Future<List<Map<String, Object?>>> getTransactions({
    String? type,
    int? categoryId,
    DateTime? start,
    DateTime? end,
    int? limit,
    int offset = 0,
  }) async {
    if (type != null) _validateType(type);
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive');
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Must not be negative');
    }
    if (start != null && end != null && !start.isBefore(end)) {
      throw ArgumentError('start must be earlier than end');
    }
    final clauses = <String>[];
    final args = <Object?>[];
    if (type != null) {
      clauses.add('type = ?');
      args.add(type);
    }
    if (categoryId != null) {
      clauses.add('category_id = ?');
      args.add(categoryId);
    }
    if (start != null) {
      clauses.add('timestamp >= ?');
      args.add(start.millisecondsSinceEpoch);
    }
    if (end != null) {
      clauses.add('timestamp < ?');
      args.add(end.millisecondsSinceEpoch);
    }
    return (await database).query(
      'transactions',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC, id DESC',
      // SQLite requires LIMIT when using OFFSET; -1 means no upper limit.
      limit: limit ?? (offset > 0 ? -1 : null),
      offset: offset > 0 ? offset : null,
    );
  }

  /// Replaces editable fields; a null [note] clears an existing note.
  Future<int> updateTransaction({
    required int id,
    required double amount,
    required String type,
    required int categoryId,
    required DateTime timestamp,
    String? note,
  }) async {
    final values = _transactionValues(
      amount,
      type,
      categoryId,
      timestamp,
      note,
    );
    return (await database).update(
      'transactions',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    return (await database).delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Close only once database users are idle (for example, during test teardown).
  /// The next access opens the database again without deleting its contents.
  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    try {
      await (await opening).close();
    } finally {
      _opening = null;
    }
  }

  Map<String, Object?> _categoryValues(
    String name,
    String icon,
    int color,
    String type,
  ) {
    _validateType(type);
    if (name.trim().isEmpty || icon.trim().isEmpty) {
      throw ArgumentError('Category name and icon must not be empty');
    }
    if (color < 0 || color > 0xFFFFFFFF) {
      throw ArgumentError.value(color, 'color', 'Must be a 32-bit ARGB value');
    }
    return {
      'name': name.trim(),
      'icon': icon.trim(),
      'color': color,
      'type': type,
    };
  }

  Map<String, Object?> _transactionValues(
    double amount,
    String type,
    int categoryId,
    DateTime timestamp,
    String? note,
  ) {
    _validateType(type);
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Must be finite and positive',
      );
    }
    return {
      'amount': amount,
      'type': type,
      'category_id': categoryId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'note': note,
    };
  }

  void _validateType(String type) {
    if (type != 'income' && type != 'expense') {
      throw ArgumentError.value(type, 'type', 'Must be income or expense');
    }
  }
}
