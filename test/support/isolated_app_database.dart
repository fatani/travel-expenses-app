import 'package:travel_expenses/core/database/app_database.dart';

/// Opens [AppDatabase] on a unique file so parallel test files do not contend
/// for the default [AppDatabase.databaseName] (`travel_expenses.db`).
AppDatabase createIsolatedAppDatabase({String prefix = 'test'}) {
  return AppDatabase(
    databaseFileName: '${prefix}_${DateTime.now().microsecondsSinceEpoch}.db',
  );
}
