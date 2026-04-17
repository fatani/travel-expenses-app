import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase();

  static const String databaseName = 'travel_expenses.db';
  static const int databaseVersion = 8;

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
      onOpen: (db) async {
        await _ensureSettingsLocaleColumn(db);
        await _ensureExpensesRawSmsColumn(db);
        await _ensureExpensesPaymentDetailsColumns(db);
        await _ensureExpensesFinancialColumns(db);
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
            transaction_amount REAL,
            transaction_currency TEXT,
            billed_amount REAL,
            billed_currency TEXT,
            fees_amount REAL,
            fees_currency TEXT,
            total_charged_amount REAL,
            total_charged_currency TEXT,
            is_international INTEGER NOT NULL DEFAULT 0,
            spent_at TEXT NOT NULL,
            payment_method TEXT NOT NULL,
            payment_network TEXT,
            payment_channel TEXT,
            source TEXT NOT NULL,
            category TEXT,
            note TEXT,
            raw_sms_text TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (trip_id) REFERENCES $tripsTable (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE $settingsTable (
            id INTEGER PRIMARY KEY,
            currency_code TEXT NOT NULL,
            locale_code TEXT NOT NULL,
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

        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE $expensesTable ADD COLUMN payment_method TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE $expensesTable ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
          );
        }

        if (oldVersion < 4) {
          final hasLocaleCode = await _hasColumn(
            db,
            settingsTable,
            'locale_code',
          );
          if (!hasLocaleCode) {
            await db.execute(
              "ALTER TABLE $settingsTable ADD COLUMN locale_code TEXT NOT NULL DEFAULT 'ar'",
            );
          }
        }

        if (oldVersion < 5) {
          final hasRawSmsText = await _hasColumn(
            db,
            expensesTable,
            'raw_sms_text',
          );
          if (!hasRawSmsText) {
            await db.execute(
              'ALTER TABLE $expensesTable ADD COLUMN raw_sms_text TEXT',
            );
          }
        }

        if (oldVersion < 6) {
          final hasPaymentNetwork = await _hasColumn(
            db,
            expensesTable,
            'payment_network',
          );
          if (!hasPaymentNetwork) {
            await db.execute(
              'ALTER TABLE $expensesTable ADD COLUMN payment_network TEXT',
            );
          }

          final hasPaymentChannel = await _hasColumn(
            db,
            expensesTable,
            'payment_channel',
          );
          if (!hasPaymentChannel) {
            await db.execute(
              'ALTER TABLE $expensesTable ADD COLUMN payment_channel TEXT',
            );
          }
        }

        if (oldVersion < 7) {
          await _ensureExpensesFinancialColumns(db);
        }

        if (oldVersion < 8) {
          await _recomputeExpensesInternationalFlag(db);
        }
      },
    );
  }

  Future<bool> _hasColumn(Database db, String table, String columnName) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.any((column) => column['name'] == columnName);
  }

  Future<void> _ensureSettingsLocaleColumn(Database db) async {
    final hasLocaleCode = await _hasColumn(db, settingsTable, 'locale_code');

    if (hasLocaleCode) {
      return;
    }

    await db.execute(
      "ALTER TABLE $settingsTable ADD COLUMN locale_code TEXT NOT NULL DEFAULT 'ar'",
    );
  }

  Future<void> _ensureExpensesRawSmsColumn(Database db) async {
    final hasRawSmsText = await _hasColumn(db, expensesTable, 'raw_sms_text');

    if (hasRawSmsText) {
      return;
    }

    await db.execute('ALTER TABLE $expensesTable ADD COLUMN raw_sms_text TEXT');
  }

  Future<void> _ensureExpensesPaymentDetailsColumns(Database db) async {
    final hasPaymentNetwork = await _hasColumn(
      db,
      expensesTable,
      'payment_network',
    );
    if (!hasPaymentNetwork) {
      await db.execute(
        'ALTER TABLE $expensesTable ADD COLUMN payment_network TEXT',
      );
    }

    final hasPaymentChannel = await _hasColumn(
      db,
      expensesTable,
      'payment_channel',
    );
    if (!hasPaymentChannel) {
      await db.execute(
        'ALTER TABLE $expensesTable ADD COLUMN payment_channel TEXT',
      );
    }
  }

  Future<void> _ensureExpensesFinancialColumns(Database db) async {
    final hasTransactionAmount = await _hasColumn(
      db,
      expensesTable,
      'transaction_amount',
    );
    if (!hasTransactionAmount) {
      await db.execute(
        'ALTER TABLE $expensesTable ADD COLUMN transaction_amount REAL',
      );
    }

    final hasTransactionCurrency = await _hasColumn(
      db,
      expensesTable,
      'transaction_currency',
    );
    if (!hasTransactionCurrency) {
      await db.execute(
        'ALTER TABLE $expensesTable ADD COLUMN transaction_currency TEXT',
      );
    }

    final hasBilledAmount = await _hasColumn(
      db,
      expensesTable,
      'billed_amount',
    );
    if (!hasBilledAmount) {
      await db.execute('ALTER TABLE $expensesTable ADD COLUMN billed_amount REAL');
    }

    final hasBilledCurrency = await _hasColumn(
      db,
      expensesTable,
      'billed_currency',
    );
    if (!hasBilledCurrency) {
      await db.execute('ALTER TABLE $expensesTable ADD COLUMN billed_currency TEXT');
    }

    final hasFeesAmount = await _hasColumn(db, expensesTable, 'fees_amount');
    if (!hasFeesAmount) {
      await db.execute('ALTER TABLE $expensesTable ADD COLUMN fees_amount REAL');
    }

    final hasFeesCurrency = await _hasColumn(db, expensesTable, 'fees_currency');
    if (!hasFeesCurrency) {
      await db.execute('ALTER TABLE $expensesTable ADD COLUMN fees_currency TEXT');
    }

    final hasTotalChargedAmount = await _hasColumn(
      db,
      expensesTable,
      'total_charged_amount',
    );
    if (!hasTotalChargedAmount) {
      await db.execute(
        'ALTER TABLE $expensesTable ADD COLUMN total_charged_amount REAL',
      );
    }

    final hasTotalChargedCurrency = await _hasColumn(
      db,
      expensesTable,
      'total_charged_currency',
    );
    if (!hasTotalChargedCurrency) {
      await db.execute(
        'ALTER TABLE $expensesTable ADD COLUMN total_charged_currency TEXT',
      );
    }

    final hasIsInternational = await _hasColumn(
      db,
      expensesTable,
      'is_international',
    );
    if (!hasIsInternational) {
      await db.execute(
        'ALTER TABLE $expensesTable ADD COLUMN is_international INTEGER NOT NULL DEFAULT 0',
      );
    }

    // Backfill for existing rows to keep old data compatible with the new model.
    await db.execute(
      'UPDATE $expensesTable SET transaction_amount = amount WHERE transaction_amount IS NULL',
    );
    await db.execute(
      'UPDATE $expensesTable SET transaction_currency = currency_code WHERE transaction_currency IS NULL OR transaction_currency = ""',
    );
    await _recomputeExpensesInternationalFlag(db);
  }

  Future<void> _recomputeExpensesInternationalFlag(Database db) async {
    await db.execute(
      'UPDATE $expensesTable '
      'SET is_international = CASE '
      'WHEN UPPER(COALESCE(transaction_currency, currency_code, "")) != "SAR" '
      'OR fees_amount IS NOT NULL '
      'OR ('
      '  billed_amount IS NOT NULL OR '
      '  (billed_currency IS NOT NULL AND TRIM(billed_currency) != "")'
      ') AND ('
      '  UPPER(COALESCE(billed_currency, transaction_currency, currency_code, "")) != UPPER(COALESCE(transaction_currency, currency_code, "")) '
      '  OR ABS(COALESCE(billed_amount, transaction_amount, amount) - COALESCE(transaction_amount, amount)) > 0.000001'
      ') '
      'OR ('
      '  total_charged_amount IS NOT NULL OR '
      '  (total_charged_currency IS NOT NULL AND TRIM(total_charged_currency) != "")'
      ') AND ('
      '  UPPER(COALESCE(total_charged_currency, transaction_currency, currency_code, "")) != UPPER(COALESCE(transaction_currency, currency_code, "")) '
      '  OR ABS(COALESCE(total_charged_amount, transaction_amount, amount) - COALESCE(transaction_amount, amount)) > 0.000001'
      ') '
      'THEN 1 ELSE 0 END',
    );
  }
}
