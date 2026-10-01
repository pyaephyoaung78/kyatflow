# KyatFlow

A local-only personal expense tracker built with Flutter, SQLite, and Riverpod.
All financial data, budgets, recurring rules, analytics, and backups remain
on the device.

## Structure

```text
lib/
  core/database/database_helper.dart
  core/theme/             # Shared colors, typography, control themes and motion
  core/widgets/           # Page layout, grouped surfaces, filters and routes
  features/budgets/       # Budget domain, SQLite repository, providers, widgets
  features/recurring/     # Local recurring transaction execution service
  features/transactions/
    data/                 # SQLite row models and repository implementation
    domain/               # Entities, date filters, repository contract
    presentation/         # Riverpod state and app screens
  main.dart
```

## Interface

The interface uses quiet grouped surfaces, large titles, a restrained green
accent, Cupertino controls, and consistent spacing. Home, Analytics, History,
Settings, transaction entry, and budget progress share the same design tokens.
Tab changes preserve each screen's scroll position. Entry opens with a native
modal transition; custom motion respects the system's reduced-animation setting.

`test/ui_design_test.dart` exercises navigation, filters, transaction editing
and saving, empty states, narrow/landscape screens, and double-sized text with
the keyboard open. Run it with `flutter test test/ui_design_test.dart`.
To also render sample-data previews into the ignored `build/ui-previews/` folder:

```bash
flutter test test/ui_design_test.dart \
  --dart-define=CAPTURE_DESIGN=true \
  --dart-define=FLUTTER_FONT_DIRECTORY=/absolute/path/to/flutter/bin/cache/artifacts/material_fonts
```

These previews load local test fonts; verify platform typography, gestures,
and haptics on a physical device with `flutter run` before shipping.

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

Categories and transactions have insert, single-row read, list, update, and delete methods.
Inserts return IDs; updates/deletes return affected row counts; missing single
rows return null. Updates replace all editable fields; omitted notes become null.
Invalid input throws `ArgumentError`; SQLite constraint failures propagate as
`DatabaseException` for the data/presentation layers to handle.

- `categories`: integer ID, text name, text icon key, integer ARGB color, text type.
- `transactions`: integer ID, REAL amount, text type, integer category ID,
  integer epoch-millisecond timestamp, nullable text note.
- `budgets`: category, positive monthly limit, month/year, and warning percentage.
- `recurring_rules`: name, amount, category/type, daily/weekly/monthly/yearly
  frequency, and nullable last-executed timestamp.
- Types are `income` and `expense`; amounts must be finite and positive.
- Foreign keys require a category of the same type. Referenced categories cannot
  be deleted or have their type changed until their transactions are reassigned
  or explicitly deleted.
- Date ranges include the start and exclude the end. Results are newest first,
  with ID as the tie-breaker. Indexes cover date, type/date, category/date, and
  category type/name queries. IDs are indexed by their primary keys.
- Amount uses REAL as requested, so it has floating-point precision limits.
- Schema version is 3. The version-3 migration adds budget and recurring-rule
  tables without rewriting existing categories or transactions.
- Call `close()` only when all database operations are idle, not on each screen
  disposal. The connection is intended to live for the application lifetime.

The standard [sqflite plugin](https://pub.dev/packages/sqflite) supports Android,
iOS, and macOS. Linux/Windows/web runtime support would require another adapter.

## Transaction state

Watch `transactionStateProvider` in a `ConsumerWidget`. Its state publishes the
filtered transaction list, active-month cash-flow summary, loading/mutation
flags, and any error. Today uses local midnight boundaries, weeks start Monday,
and all date ranges use an exclusive end boundary.

```dart
final state = ref.watch(transactionStateProvider);
final notifier = ref.read(transactionStateProvider.notifier);

Text('Balance: ${state.summary.currentBalance}');
await notifier.setFilter(TransactionDateFilter.today);
await notifier.add(TransactionDraft(
  amount: 3500,
  type: TransactionType.expense,
  categoryId: foodCategoryId,
  timestamp: DateTime.now(),
  note: 'Lunch',
));
```

`SqliteTransactionRepository` emits a revision after each successful insert,
edit, or delete. The notifier listens to those revisions, so repository writes
from another part of the app also refresh the visible list and monthly totals.
The three totals are calculated together by SQLite with `SUM(CASE ...)`; Dart
does not load every transaction to calculate the dashboard.

## Transaction entry screen

`RiverpodTransactionEntryScreen` connects the entry form directly to
`transactionStateProvider`. Pass categories loaded from SQLite as
`TransactionCategoryOption` values; each option must use its real database ID.
The reusable `TransactionEntryScreen` also accepts an `onSubmit` callback for
tests or another state-management boundary.

The form includes an animated expense/income toggle, type-filtered category
chips, a note field, and a fixed 4×4 keypad. Expressions use standard operator
precedence and are evaluated locally as the user enters them. Submitted totals
are rounded to two decimal places. Empty/incomplete expressions, division by
zero, missing categories, non-positive totals, and notes over 200 characters are
blocked before a repository write.

## Dashboard, ledger, and backup

The app now opens on a dashboard with all-time balance, current-month income and
expenses, and the five most recent entries. The History tab groups the complete
ledger by local calendar date and filters it with All, Income, and Expense
chips. Both screens listen to repository revisions and refresh after a local
insert, edit, or delete.

The dashboard export button creates one UTF-8 `.csv` file containing every row
from all four SQLite tables. A `record_type` column distinguishes categories from
transactions, allowing unused categories to remain in the backup. Values are
CSV-escaped and text that could be interpreted as a spreadsheet formula is
neutralized. Files are written under `kyatflow_exports` in the application
documents directory, then offered through the platform share/save sheet.

## Navigation and analytics

`MainShellScreen` provides five bottom destinations: Home, Analytics, an
elevated center Add action, History, and Settings. The Add action opens the same
transaction entry route from every tab and keeps the previously selected tab
active after the form closes.

Analytics uses an indexed SQLite `SUM(amount)` query grouped by expense category.
Users can switch between the current Monday-based week and current calendar
month. `fl_chart` renders the result as an interactive donut chart, while the
ranked list shows each category's amount, percentage, and transaction count.
Analytics subscribes to repository revisions, so adding, editing, or deleting a
transaction refreshes the chart without a remote service or network request.

## Budgets and recurring transactions

Monthly category budgets are aggregated inside SQLite. The query joins expense
transactions within the selected local calendar month, calculates the spent
percentage, and returns `safe`, `warning`, or `exceeded` for each limit. The
dashboard renders these results with `MonthlyBudgetProgressSection` and refreshes
when either budgets or transactions change.

`RecurringTransactionService` runs before the Flutter widget tree starts. A new
rule creates one transaction on its first check; existing rules create each
missed daily, weekly, monthly, or yearly occurrence through the current date.
Generated transactions and `last_executed` updates share one SQLite transaction,
so an interrupted run can be retried without committing duplicates. The check
has no timer, background worker, network call, or remote backend.

## Validation

```sh
flutter analyze
flutter test
```

Database tests use the development-only `sqflite_common_ffi` adapter and isolated
temporary SQLite files. They cover CRUD, date filtering, pagination, constraints,
reopening, concurrent initialization, retrying failed opens, and query plans.
