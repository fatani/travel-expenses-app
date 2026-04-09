import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase();

  static const String databaseName = 'travel_expenses.db';
  static const int databaseVersion = 2;

  static const String tripsTable = 'trips';
  static const String expensesTable = 'expenses';
  static const String settingsTable = 'settings';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final databasePath = p.join(databasesPath, databaseName);

    return openDatabase(
      databasePath,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tripsTable (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            destination TEXT NOT NULL,
            start_date TEXT,
            end_date TEXT,
            base_currency TEXT NOT NULL,
            budget REAL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $expensesTable (
            id TEXT PRIMARY KEY,
            trip_id TEXT NOT NULL,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            currency_code TEXT NOT NULL,
            spent_at TEXT NOT NULL,
            category TEXT,
            note TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (trip_id) REFERENCES $tripsTable (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE $settingsTable (
            id INTEGER PRIMARY KEY,
            currency_code TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $tripsTable ADD COLUMN destination TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE $tripsTable ADD COLUMN base_currency TEXT NOT NULL DEFAULT ''",
          );
          await db.execute('ALTER TABLE $tripsTable ADD COLUMN budget REAL');
        }
      },
    );
  }
}
