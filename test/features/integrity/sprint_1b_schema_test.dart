import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';

import '../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;

  setUp(() async {
    appDatabase = createIsolatedAppDatabase(prefix: 'sprint_1b');
  });

  tearDown(() async {
    await appDatabase.close();
  });

  Future<Set<String>> columnNames(String table) async {
    final db = await appDatabase.database;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.map((r) => r['name'] as String).toSet();
  }

  // ---------------------------------------------------------------------------
  // Database version
  // ---------------------------------------------------------------------------

  group('database version', () {
    test('database version is 22', () async {
      final db = await appDatabase.database;
      final result = await db.rawQuery('PRAGMA user_version');
      expect(result.first['user_version'], 22);
    });
  });

  // ---------------------------------------------------------------------------
  // expenses — is_reversed + reversed_at
  // ---------------------------------------------------------------------------

  group('expenses — reversal columns', () {
    test('expenses has is_reversed column', () async {
      expect(await columnNames(AppDatabase.expensesTable), contains('is_reversed'));
    });

    test('expenses has reversed_at column', () async {
      expect(await columnNames(AppDatabase.expensesTable), contains('reversed_at'));
    });

    test('is_reversed defaults to 0 for new rows', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-expense-reversal';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Reversal Test',
        'destination': 'Test',
        'base_currency': 'SAR',
        'destination_currency': 'SAR',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });
      await db.insert(AppDatabase.expensesTable, {
        'id': 'exp-default-reversal',
        'trip_id': tripId,
        'title': 'Coffee',
        'amount': 15.0,
        'currency_code': 'SAR',
        'transaction_amount': 15.0,
        'transaction_currency': 'SAR',
        'is_international': 0,
        'spent_at': DateTime.now().toUtc().toIso8601String(),
        'payment_method': 'Cash',
        'source': 'manual',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      final rows = await db.query(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: ['exp-default-reversal'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['is_reversed'], 0);
      expect(rows.first['reversed_at'], isNull);
    });

    test('is_reversed can be set to 1 with a reversed_at timestamp', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-expense-reversed';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Reversed Trip',
        'destination': 'Test',
        'base_currency': 'SAR',
        'destination_currency': 'SAR',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });
      final reversedAt = DateTime.now().toUtc().toIso8601String();
      await db.insert(AppDatabase.expensesTable, {
        'id': 'exp-reversed',
        'trip_id': tripId,
        'title': 'Reversed Expense',
        'amount': 50.0,
        'currency_code': 'SAR',
        'transaction_amount': 50.0,
        'transaction_currency': 'SAR',
        'is_international': 0,
        'spent_at': DateTime.now().toUtc().toIso8601String(),
        'payment_method': 'Cash',
        'source': 'manual',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_reversed': 1,
        'reversed_at': reversedAt,
      });
      final rows = await db.query(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: ['exp-reversed'],
      );
      expect(rows.first['is_reversed'], 1);
      expect(rows.first['reversed_at'], reversedAt);
    });

    test('active and reversed expenses are queryable separately', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-filter-reversal';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Filter Trip',
        'destination': 'Test',
        'base_currency': 'SAR',
        'destination_currency': 'SAR',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });

      for (var i = 0; i < 3; i++) {
        await db.insert(AppDatabase.expensesTable, {
          'id': 'exp-active-$i',
          'trip_id': tripId,
          'title': 'Active $i',
          'amount': 10.0,
          'currency_code': 'SAR',
          'transaction_amount': 10.0,
          'transaction_currency': 'SAR',
          'is_international': 0,
          'spent_at': DateTime.now().toUtc().toIso8601String(),
          'payment_method': 'Cash',
          'source': 'manual',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'is_reversed': 0,
        });
      }
      await db.insert(AppDatabase.expensesTable, {
        'id': 'exp-reversed-1',
        'trip_id': tripId,
        'title': 'Reversed',
        'amount': 20.0,
        'currency_code': 'SAR',
        'transaction_amount': 20.0,
        'transaction_currency': 'SAR',
        'is_international': 0,
        'spent_at': DateTime.now().toUtc().toIso8601String(),
        'payment_method': 'Cash',
        'source': 'manual',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_reversed': 1,
        'reversed_at': DateTime.now().toUtc().toIso8601String(),
      });

      final active = await db.query(
        AppDatabase.expensesTable,
        where: 'trip_id = ? AND is_reversed = 0',
        whereArgs: [tripId],
      );
      final reversed = await db.query(
        AppDatabase.expensesTable,
        where: 'trip_id = ? AND is_reversed = 1',
        whereArgs: [tripId],
      );
      expect(active, hasLength(3));
      expect(reversed, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // cash_transactions — lot_id + exchange_id
  // ---------------------------------------------------------------------------

  group('cash_transactions — FIFO linkage columns', () {
    test('cash_transactions has lot_id column', () async {
      expect(
        await columnNames(AppDatabase.cashTransactionsTable),
        contains('lot_id'),
      );
    });

    test('cash_transactions has exchange_id column', () async {
      expect(
        await columnNames(AppDatabase.cashTransactionsTable),
        contains('exchange_id'),
      );
    });

    test('lot_id and exchange_id are nullable (NULL by default)', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-cash-tx-fifo';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'FIFO Tx Trip',
        'destination': 'Test',
        'base_currency': 'USD',
        'destination_currency': 'USD',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });
      await db.insert(AppDatabase.cashTransactionsTable, {
        'id': 'tx-no-lot',
        'trip_id': tripId,
        'type': 'initial_cash',
        'amount': 200.0,
        'currency_code': 'USD',
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      final rows = await db.query(
        AppDatabase.cashTransactionsTable,
        where: 'id = ?',
        whereArgs: ['tx-no-lot'],
      );
      expect(rows.first['lot_id'], isNull);
      expect(rows.first['exchange_id'], isNull);
    });

    test('lot_id can reference an existing cash_lot', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-cash-tx-lot-ref';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Lot Ref Trip',
        'destination': 'Test',
        'base_currency': 'USD',
        'destination_currency': 'USD',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });
      await db.insert(AppDatabase.cashLotsTable, {
        'id': 'lot-for-tx',
        'trip_id': tripId,
        'source_type': 'initial_cash',
        'source_ref_type': 'cash_transaction',
        'source_ref_id': 'tx-ref-lot',
        'currency_code': 'USD',
        'original_amount': 500.0,
        'remaining_amount': 500.0,
        'is_fully_consumed': 0,
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await db.insert(AppDatabase.cashTransactionsTable, {
        'id': 'tx-with-lot',
        'trip_id': tripId,
        'type': 'initial_cash',
        'amount': 500.0,
        'currency_code': 'USD',
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'lot_id': 'lot-for-tx',
      });
      final rows = await db.query(
        AppDatabase.cashTransactionsTable,
        where: 'id = ?',
        whereArgs: ['tx-with-lot'],
      );
      expect(rows.first['lot_id'], 'lot-for-tx');
    });

    test('existing cash_transactions columns are unchanged', () async {
      final cols = await columnNames(AppDatabase.cashTransactionsTable);
      for (final col in [
        'id', 'trip_id', 'expense_id', 'type', 'amount',
        'currency_code', 'home_currency_amount', 'home_currency_code',
        'is_reversed', 'reversed_at', 'note', 'created_at',
      ]) {
        expect(cols, contains(col), reason: 'missing pre-existing column: $col');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // expense_refunds — returned_lot_id
  // ---------------------------------------------------------------------------

  group('expense_refunds — returned_lot_id column', () {
    test('expense_refunds has returned_lot_id column', () async {
      expect(
        await columnNames(AppDatabase.expenseRefundsTable),
        contains('returned_lot_id'),
      );
    });

    test('returned_lot_id is nullable (NULL by default for card refunds)', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-refund-lot';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Refund Trip',
        'destination': 'Test',
        'base_currency': 'SAR',
        'destination_currency': 'SAR',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });
      await db.insert(AppDatabase.expenseRefundsTable, {
        'id': 'refund-card',
        'trip_id': tripId,
        'amount': 100.0,
        'currency_code': 'SAR',
        'destination': 'card',
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      final rows = await db.query(
        AppDatabase.expenseRefundsTable,
        where: 'id = ?',
        whereArgs: ['refund-card'],
      );
      expect(rows.first['returned_lot_id'], isNull);
    });

    test('returned_lot_id can reference a cash_lot for cash refunds', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-cash-refund-lot';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Cash Refund Trip',
        'destination': 'Test',
        'base_currency': 'SAR',
        'destination_currency': 'SAR',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });
      await db.insert(AppDatabase.cashLotsTable, {
        'id': 'lot-refund',
        'trip_id': tripId,
        'source_type': 'cash_refund',
        'source_ref_type': 'expense_refund',
        'source_ref_id': 'refund-cash',
        'currency_code': 'SAR',
        'original_amount': 100.0,
        'remaining_amount': 100.0,
        'is_fully_consumed': 0,
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await db.insert(AppDatabase.expenseRefundsTable, {
        'id': 'refund-cash',
        'trip_id': tripId,
        'amount': 100.0,
        'currency_code': 'SAR',
        'destination': 'cash',
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'returned_lot_id': 'lot-refund',
      });
      final rows = await db.query(
        AppDatabase.expenseRefundsTable,
        where: 'id = ?',
        whereArgs: ['refund-cash'],
      );
      expect(rows.first['returned_lot_id'], 'lot-refund');
    });

    test('existing expense_refunds columns are unchanged', () async {
      final cols = await columnNames(AppDatabase.expenseRefundsTable);
      for (final col in [
        'id', 'trip_id', 'expense_id', 'amount', 'currency_code',
        'home_amount', 'home_currency', 'destination', 'note',
        'is_reversed', 'reversed_at', 'created_at',
      ]) {
        expect(cols, contains(col), reason: 'missing pre-existing column: $col');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // CASCADE DELETE — new columns don't break existing cascade
  // ---------------------------------------------------------------------------

  group('CASCADE DELETE — trip deletion still cleans up', () {
    test('deleting trip removes expenses including reversed ones', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-cascade-expenses';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Cascade',
        'destination': 'Test',
        'base_currency': 'SAR',
        'destination_currency': 'SAR',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });
      for (var i = 0; i < 2; i++) {
        await db.insert(AppDatabase.expensesTable, {
          'id': 'exp-cascade-$i',
          'trip_id': tripId,
          'title': 'E$i',
          'amount': 10.0,
          'currency_code': 'SAR',
          'transaction_amount': 10.0,
          'transaction_currency': 'SAR',
          'is_international': 0,
          'spent_at': DateTime.now().toUtc().toIso8601String(),
          'payment_method': 'Cash',
          'source': 'manual',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'is_reversed': i,
          'reversed_at': i == 1 ? DateTime.now().toUtc().toIso8601String() : null,
        });
      }

      await db.delete(AppDatabase.tripsTable, where: 'id = ?', whereArgs: [tripId]);

      final remaining = await db.query(
        AppDatabase.expensesTable,
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      expect(remaining, isEmpty);
    });
  });
}
