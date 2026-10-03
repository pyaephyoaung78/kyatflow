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
  static const databaseVersion = 4;

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
        onUpgrade: _upgradeSchema,
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
        is_archived INTEGER NOT NULL DEFAULT 0
          CHECK (is_archived IN (0, 1)),
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
      CREATE INDEX idx_categories_archived_type_name
      ON categories (is_archived, type, name, id)
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
    _createBudgetingTables(batch);
    await batch.commit(noResult: true);
    await _seedDefaultCategories(db);
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await _seedDefaultCategories(db);
    if (oldVersion < 3) {
      final batch = db.batch();
      _createBudgetingTables(batch);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE categories
        ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0
          CHECK (is_archived IN (0, 1))
      ''');
      await db.execute('''
        CREATE INDEX idx_categories_archived_type_name
        ON categories (is_archived, type, name, id)
      ''');
    }
  }

  void _createBudgetingTables(Batch batch) {
    batch.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        amount_limit REAL NOT NULL CHECK (amount_limit > 0),
        month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
        year INTEGER NOT NULL CHECK (year BETWEEN 1 AND 9999),
        alert_percentage REAL NOT NULL DEFAULT 80
          CHECK (alert_percentage > 0 AND alert_percentage <= 100),
        FOREIGN KEY (category_id) REFERENCES categories (id)
          ON UPDATE RESTRICT ON DELETE RESTRICT,
        UNIQUE (category_id, month, year)
      )
    ''');
    batch.execute('''
      CREATE INDEX idx_budgets_year_month_category
      ON budgets (year, month, category_id)
    ''');
    batch.execute('''
      CREATE TABLE recurring_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        amount REAL NOT NULL CHECK (amount > 0),
        category_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
        frequency TEXT NOT NULL
          CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
        last_executed INTEGER,
        FOREIGN KEY (category_id, type) REFERENCES categories (id, type)
          ON UPDATE RESTRICT ON DELETE RESTRICT
      )
    ''');
    batch.execute('''
      CREATE INDEX idx_recurring_rules_last_executed
      ON recurring_rules (last_executed, id)
    ''');
    batch.execute('''
      CREATE INDEX idx_recurring_rules_category
      ON recurring_rules (category_id, id)
    ''');
  }

  Future<void> _seedDefaultCategories(DatabaseExecutor db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );
    if ((count ?? 0) > 0) return;

    final batch = db.batch();
    for (final category in _defaultCategories) {
      batch.insert('categories', category);
    }
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

  Future<List<Map<String, Object?>>> getCategories({
    String? type,
    bool includeArchived = false,
  }) async {
    if (type != null) _validateType(type);
    final clauses = <String>[];
    final arguments = <Object?>[];
    if (!includeArchived) clauses.add('is_archived = 0');
    if (type != null) {
      clauses.add('type = ?');
      arguments.add(type);
    }
    return (await database).query(
      'categories',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'is_archived ASC, name ASC, id ASC',
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

  Future<int> setCategoryArchived(int id, {required bool archived}) async {
    return (await database).update(
      'categories',
      {'is_archived': archived ? 1 : 0},
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

  /// Computes cash-flow totals in SQLite for the half-open [start, end) range.
  ///
  /// A single aggregate query is used so all three values come from the same
  /// database snapshot. `COALESCE` converts an empty period into zero totals.
  Future<Map<String, Object?>> getCashFlowSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!start.isBefore(end)) {
      throw ArgumentError('start must be earlier than end');
    }
    final rows = await (await database).rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0.0)
          AS total_income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0.0)
          AS total_expense,
        COALESCE(SUM(CASE
          WHEN type = 'income' THEN amount
          WHEN type = 'expense' THEN -amount
          ELSE 0
        END), 0.0) AS current_balance
      FROM transactions
      WHERE timestamp >= ? AND timestamp < ?
      ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return rows.single;
  }

  /// Returns all-time balance with income and expense totals for [start, end).
  Future<Map<String, Object?>> getDashboardSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!start.isBefore(end)) {
      throw ArgumentError('start must be earlier than end');
    }
    final rows = await (await database).rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE
          WHEN type = 'income' THEN amount
          WHEN type = 'expense' THEN -amount
          ELSE 0
        END), 0.0) AS current_balance,
        COALESCE(SUM(CASE
          WHEN type = 'income' AND timestamp >= ? AND timestamp < ?
            THEN amount ELSE 0
        END), 0.0) AS total_income,
        COALESCE(SUM(CASE
          WHEN type = 'expense' AND timestamp >= ? AND timestamp < ?
            THEN amount ELSE 0
        END), 0.0) AS total_expense
      FROM transactions
      ''',
      [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );
    return rows.single;
  }

  /// Returns transaction rows enriched with category presentation metadata.
  Future<List<Map<String, Object?>>> getTransactionDetails({
    String? type,
    int? categoryId,
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    if (type != null) _validateType(type);
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive');
    }
    if (start != null && end != null && !start.isBefore(end)) {
      throw ArgumentError('start must be earlier than end');
    }
    final clauses = <String>[];
    final arguments = <Object?>[];
    if (type != null) {
      clauses.add('t.type = ?');
      arguments.add(type);
    }
    if (categoryId != null) {
      clauses.add('t.category_id = ?');
      arguments.add(categoryId);
    }
    if (start != null) {
      clauses.add('t.timestamp >= ?');
      arguments.add(start.millisecondsSinceEpoch);
    }
    if (end != null) {
      clauses.add('t.timestamp < ?');
      arguments.add(end.millisecondsSinceEpoch);
    }
    if (limit != null) arguments.add(limit);
    return (await database).rawQuery('''
      SELECT
        t.id,
        t.amount,
        t.type,
        t.category_id,
        t.timestamp,
        t.note,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color
      FROM transactions AS t
      INNER JOIN categories AS c ON c.id = t.category_id
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      ORDER BY t.timestamp DESC, t.id DESC
      ${limit == null ? '' : 'LIMIT ?'}
      ''', arguments);
  }

  /// Groups expense totals by category for the half-open [start, end) range.
  Future<List<Map<String, Object?>>> getExpenseBreakdown({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!start.isBefore(end)) {
      throw ArgumentError('start must be earlier than end');
    }
    return (await database).rawQuery(
      '''
      SELECT
        c.id AS category_id,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color,
        SUM(t.amount) AS total_amount,
        COUNT(t.id) AS transaction_count
      FROM transactions AS t
      INNER JOIN categories AS c ON c.id = t.category_id
      WHERE t.type = 'expense' AND t.timestamp >= ? AND t.timestamp < ?
      GROUP BY c.id, c.name, c.icon, c.color
      ORDER BY total_amount DESC, c.name ASC
      ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
  }

  Future<int> insertBudget({
    required int categoryId,
    required double amountLimit,
    required int month,
    required int year,
    double alertPercentage = 80,
  }) async {
    final values = _budgetValues(
      categoryId,
      amountLimit,
      month,
      year,
      alertPercentage,
    );
    return (await database).transaction((txn) async {
      await _requireExpenseCategory(txn, categoryId);
      return txn.insert('budgets', values);
    });
  }

  Future<int> updateBudget({
    required int id,
    required int categoryId,
    required double amountLimit,
    required int month,
    required int year,
    required double alertPercentage,
  }) async {
    final values = _budgetValues(
      categoryId,
      amountLimit,
      month,
      year,
      alertPercentage,
    );
    return (await database).transaction((txn) async {
      await _requireExpenseCategory(txn, categoryId);
      return txn.update('budgets', values, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> deleteBudget(int id) async {
    return (await database).delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  /// Compares budget limits with expense transactions for one calendar month.
  Future<List<Map<String, Object?>>> getBudgetProgress({
    required int month,
    required int year,
  }) async {
    _validateMonthAndYear(month, year);
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (await database).rawQuery(
      '''
      WITH spending AS (
        SELECT
          b.id,
          b.category_id,
          b.amount_limit,
          b.month,
          b.year,
          b.alert_percentage,
          c.name AS category_name,
          c.icon AS category_icon,
          c.color AS category_color,
          COALESCE(SUM(t.amount), 0.0) AS actual_spent
        FROM budgets AS b
        INNER JOIN categories AS c
          ON c.id = b.category_id AND c.type = 'expense'
        LEFT JOIN transactions AS t
          ON t.category_id = b.category_id
          AND t.type = 'expense'
          AND t.timestamp >= ?
          AND t.timestamp < ?
        WHERE b.year = ? AND b.month = ?
        GROUP BY
          b.id,
          b.category_id,
          b.amount_limit,
          b.month,
          b.year,
          b.alert_percentage,
          c.name,
          c.icon,
          c.color
      )
      SELECT
        *,
        (actual_spent / amount_limit) * 100.0 AS progress_percentage,
        CASE
          WHEN actual_spent > amount_limit THEN 'exceeded'
          WHEN actual_spent >= amount_limit * alert_percentage / 100.0
            THEN 'warning'
          ELSE 'safe'
        END AS warning_state
      FROM spending
      ORDER BY progress_percentage DESC, category_name ASC
      ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, year, month],
    );
  }

  Future<int> insertRecurringRule({
    required String name,
    required double amount,
    required int categoryId,
    required String type,
    required String frequency,
    DateTime? lastExecuted,
  }) async {
    final values = _recurringRuleValues(
      name,
      amount,
      categoryId,
      type,
      frequency,
      lastExecuted,
    );
    return (await database).insert('recurring_rules', values);
  }

  Future<int> updateRecurringRule({
    required int id,
    required String name,
    required double amount,
    required int categoryId,
    required String type,
    required String frequency,
    DateTime? lastExecuted,
  }) async {
    final values = _recurringRuleValues(
      name,
      amount,
      categoryId,
      type,
      frequency,
      lastExecuted,
    );
    return (await database).update(
      'recurring_rules',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> getRecurringRules() async {
    return (await database).query('recurring_rules', orderBy: 'id ASC');
  }

  Future<int> deleteRecurringRule(int id) async {
    return (await database).delete(
      'recurring_rules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reads all local tables inside one transaction for a consistent snapshot.
  Future<DatabaseBackupSnapshot> getBackupSnapshot() async {
    return (await database).transaction((txn) async {
      final categories = await txn.query('categories', orderBy: 'id ASC');
      final transactions = await txn.query('transactions', orderBy: 'id ASC');
      final budgets = await txn.query('budgets', orderBy: 'id ASC');
      final recurringRules = await txn.query(
        'recurring_rules',
        orderBy: 'id ASC',
      );
      return DatabaseBackupSnapshot(
        categories: categories,
        transactions: transactions,
        budgets: budgets,
        recurringRules: recurringRules,
      );
    });
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

  Map<String, Object?> _budgetValues(
    int categoryId,
    double amountLimit,
    int month,
    int year,
    double alertPercentage,
  ) {
    if (!amountLimit.isFinite || amountLimit <= 0) {
      throw ArgumentError.value(
        amountLimit,
        'amountLimit',
        'Must be finite and positive',
      );
    }
    if (!alertPercentage.isFinite ||
        alertPercentage <= 0 ||
        alertPercentage > 100) {
      throw ArgumentError.value(
        alertPercentage,
        'alertPercentage',
        'Must be greater than 0 and at most 100',
      );
    }
    _validateMonthAndYear(month, year);
    return {
      'category_id': categoryId,
      'amount_limit': amountLimit,
      'month': month,
      'year': year,
      'alert_percentage': alertPercentage,
    };
  }

  Future<void> _requireExpenseCategory(
    DatabaseExecutor db,
    int categoryId,
  ) async {
    final rows = await db.query(
      'categories',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    if (rows.isEmpty || rows.single['type'] != 'expense') {
      throw ArgumentError.value(
        categoryId,
        'categoryId',
        'Budgets require an existing expense category',
      );
    }
  }

  Map<String, Object?> _recurringRuleValues(
    String name,
    double amount,
    int categoryId,
    String type,
    String frequency,
    DateTime? lastExecuted,
  ) {
    _validateType(type);
    _validateFrequency(frequency);
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Must be finite and positive',
      );
    }
    return {
      'name': name.trim(),
      'amount': amount,
      'category_id': categoryId,
      'type': type,
      'frequency': frequency,
      'last_executed': lastExecuted?.millisecondsSinceEpoch,
    };
  }

  void _validateMonthAndYear(int month, int year) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be between 1 and 12');
    }
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'Must be between 1 and 9999');
    }
  }

  void _validateFrequency(String frequency) {
    const frequencies = {'daily', 'weekly', 'monthly', 'yearly'};
    if (!frequencies.contains(frequency)) {
      throw ArgumentError.value(
        frequency,
        'frequency',
        'Must be daily, weekly, monthly, or yearly',
      );
    }
  }

  void _validateType(String type) {
    if (type != 'income' && type != 'expense') {
      throw ArgumentError.value(type, 'type', 'Must be income or expense');
    }
  }
}

class DatabaseBackupSnapshot {
  DatabaseBackupSnapshot({
    required List<Map<String, Object?>> categories,
    required List<Map<String, Object?>> transactions,
    required List<Map<String, Object?>> budgets,
    required List<Map<String, Object?>> recurringRules,
  }) : categories = List.unmodifiable(categories),
       transactions = List.unmodifiable(transactions),
       budgets = List.unmodifiable(budgets),
       recurringRules = List.unmodifiable(recurringRules);

  final List<Map<String, Object?>> categories;
  final List<Map<String, Object?>> transactions;
  final List<Map<String, Object?>> budgets;
  final List<Map<String, Object?>> recurringRules;
}

const _defaultCategories = <Map<String, Object?>>[
  {
    'name': 'Food',
    'icon': 'restaurant',
    'color': 0xFFFF9800,
    'type': 'expense',
  },
  {
    'name': 'Transport',
    'icon': 'directions_bus',
    'color': 0xFF2196F3,
    'type': 'expense',
  },
  {
    'name': 'Shopping',
    'icon': 'shopping_bag',
    'color': 0xFF8E5DB7,
    'type': 'expense',
  },
  {
    'name': 'Bills',
    'icon': 'receipt_long',
    'color': 0xFF536DFE,
    'type': 'expense',
  },
  {
    'name': 'Health',
    'icon': 'medical_services',
    'color': 0xFFEF5350,
    'type': 'expense',
  },
  {'name': 'Other', 'icon': 'category', 'color': 0xFF78909C, 'type': 'expense'},
  {
    'name': 'Salary',
    'icon': 'account_balance_wallet',
    'color': 0xFF43A047,
    'type': 'income',
  },
  {'name': 'Freelance', 'icon': 'work', 'color': 0xFF00897B, 'type': 'income'},
  {
    'name': 'Gift',
    'icon': 'card_giftcard',
    'color': 0xFFEC407A,
    'type': 'income',
  },
  {'name': 'Other', 'icon': 'savings', 'color': 0xFF7CB342, 'type': 'income'},
];
