# KyatFlow

A local-only personal expense tracker built with Flutter. This first step adds
the SQLite foundation; feature models, repositories, and screens come next.

## Structure

```text
lib/
  core/database/database_helper.dart
  features/transactions/
    data/           # Row models, local sources, repository implementations
    domain/         # Plain Dart entities, contracts, business rules
    presentation/   # Screens, widgets, state management
  main.dart
```

## Local database

`DatabaseHelper.instance` lazily opens `kyatflow.db` in sqflite's database
directory. Concurrent callers share initialization; failed opens can be retried.
The app uses `sqflite` and `path` without a backend, authentication, or network
calls. The helper is ready to connect to the UI in a later step.

Initialize explicitly after `WidgetsFlutterBinding.ensureInitialized()` when
wiring startup, or let the first CRUD call open the database:

```dart
import 'package:kyatflow/core/database/database_helper.dart';

Future<void> saveExampleExpense() async {
  final database = DatabaseHelper.instance;
  final categoryId = await database.insertCategory(
    name: 'Food',
    icon: 'restaurant',
    color: 0xFFFF9800,
    type: 'expense',
  );
  await database.insertTransaction(
    amount: 3500,
    type: 'expense',
    categoryId: categoryId,
    timestamp: DateTime.now(),
    note: 'Lunch',
  );
  final expenses = await database.getTransactions(
    type: 'expense',
    start: DateTime(2026, 9, 1),
    end: DateTime(2026, 10, 1),
    limit: 50,
  );
  // Map expenses to domain entities in the feature's data layer.
}
```

Both tables have insert, single-row read, list, update, and delete methods.
Inserts return IDs; updates/deletes return affected row counts; missing single
rows return null. Updates replace all editable fields; omitted notes become null.
Invalid input throws `ArgumentError`; SQLite constraint failures propagate as
`DatabaseException` for the data/presentation layers to handle.

- `categories`: integer ID, text name, text icon key, integer ARGB color, text type.
- `transactions`: integer ID, REAL amount, text type, integer category ID,
  integer epoch-millisecond timestamp, nullable text note.
- Types are `income` and `expense`; amounts must be finite and positive.
- Foreign keys require a category of the same type. Referenced categories cannot
  be deleted or have their type changed until their transactions are reassigned
  or explicitly deleted.
- Date ranges include the start and exclude the end. Results are newest first,
  with ID as the tie-breaker. Indexes cover date, type/date, category/date, and
  category type/name queries. IDs are indexed by their primary keys.
- Amount uses REAL as requested, so it has floating-point precision limits.
- Schema version is 1. Future schema changes should increment `databaseVersion`
  and add an `onUpgrade` migration that preserves existing data.
- Call `close()` only when all database operations are idle, not on each screen
  disposal. The connection is intended to live for the application lifetime.

The standard [sqflite plugin](https://pub.dev/packages/sqflite) supports Android,
iOS, and macOS. Linux/Windows/web runtime support would require another adapter.

## Validation

```sh
flutter analyze
flutter test
```

Database tests use the development-only `sqflite_common_ffi` adapter and isolated
temporary SQLite files. They cover CRUD, date filtering, pagination, constraints,
reopening, concurrent initialization, retrying failed opens, and query plans.
