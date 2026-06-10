import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';

import '../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;

  setUp(() async {
    appDatabase = createIsolatedAppDatabase(prefix: 'sprint_1a');
  });

  tearDown(() async {
    await appDatabase.close();
  });

  Future<List<Map<String, Object?>>> tableInfo(String table) async {
    final db = await appDatabase.database;
    return db.rawQuery('PRAGMA table_info($table)');
  }

  Future<List<Map<String, Object?>>> indexList(String table) async {
    final db = await appDatabase.database;
    return db.rawQuery('PRAGMA index_list($table)');
  }

  Future<bool> tableExists(String table) async {
    final db = await appDatabase.database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // currency_exchanges
  // ---------------------------------------------------------------------------

  group('currency_exchanges — table exists with correct schema', () {
    test('table is created', () async {
      expect(await tableExists(AppDatabase.currencyExchangesTable), isTrue);
    });

    test('has required columns', () async {
      final cols = (await tableInfo(AppDatabase.currencyExchangesTable))
          .map((r) => r['name'] as String)
          .toSet();
      for (final col in [
        'id',
        'trip_id',
        'from_currency_code',
        'from_amount',
        'to_currency_code',
        'to_amount',
        'exchange_rate',
        'to_lot_id',
        'is_reversed',
        'reversed_at',
        'note',
        'created_at',
      ]) {
        expect(cols, contains(col), reason: 'missing column: $col');
      }
    });

    test('has FIFO trip index', () async {
      final indexes = (await indexList(AppDatabase.currencyExchangesTable))
          .map((r) => r['name'] as String)
          .toSet();
      expect(indexes, contains('idx_exchanges_trip'));
    });

    test('rejects zero exchange_rate via CHECK constraint', () async {
      final db = await appDatabase.database;
      expect(
        () async => db.insert(AppDatabase.currencyExchangesTable, {
          'id': 'ex-bad-rate',
          'trip_id': 'any',
          'from_currency_code': 'USD',
          'from_amount': 100.0,
          'to_currency_code': 'SAR',
          'to_amount': 375.0,
          'exchange_rate': 0.0,
          'to_lot_id': 'lot-1',
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });

    test('rejects same from/to currency via CHECK constraint', () async {
      final db = await appDatabase.database;
      expect(
        () async => db.insert(AppDatabase.currencyExchangesTable, {
          'id': 'ex-same-currency',
          'trip_id': 'any',
          'from_currency_code': 'USD',
          'from_amount': 100.0,
          'to_currency_code': 'USD',
          'to_amount': 100.0,
          'exchange_rate': 1.0,
          'to_lot_id': 'lot-1',
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // cash_lots
  // ---------------------------------------------------------------------------

  group('cash_lots — table exists with correct schema', () {
    test('table is created', () async {
      expect(await tableExists(AppDatabase.cashLotsTable), isTrue);
    });

    test('has required columns', () async {
      final cols = (await tableInfo(AppDatabase.cashLotsTable))
          .map((r) => r['name'] as String)
          .toSet();
      for (final col in [
        'id',
        'trip_id',
        'source_type',
        'source_ref_type',
        'source_ref_id',
        'currency_code',
        'original_amount',
        'remaining_amount',
        'home_currency_amount',
        'home_currency_code',
        'effective_rate',
        'is_fully_consumed',
        'is_reversed',
        'reversed_at',
        'created_at',
        'note',
      ]) {
        expect(cols, contains(col), reason: 'missing column: $col');
      }
    });

    test('has FIFO index', () async {
      final indexes = (await indexList(AppDatabase.cashLotsTable))
          .map((r) => r['name'] as String)
          .toSet();
      expect(indexes, contains('idx_cash_lots_fifo'));
    });

    test('has source_ref index', () async {
      final indexes = (await indexList(AppDatabase.cashLotsTable))
          .map((r) => r['name'] as String)
          .toSet();
      expect(indexes, contains('idx_cash_lots_source_ref'));
    });

    test('has source_type index', () async {
      final indexes = (await indexList(AppDatabase.cashLotsTable))
          .map((r) => r['name'] as String)
          .toSet();
      expect(indexes, contains('idx_cash_lots_source'));
    });

    test('rejects zero original_amount via CHECK constraint', () async {
      final db = await appDatabase.database;
      expect(
        () async => db.insert(AppDatabase.cashLotsTable, {
          'id': 'lot-zero',
          'trip_id': 'any',
          'source_type': 'initial_cash',
          'source_ref_type': 'cash_transaction',
          'source_ref_id': 'tx-1',
          'currency_code': 'USD',
          'original_amount': 0.0,
          'remaining_amount': 0.0,
          'is_fully_consumed': 0,
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });

    test('rejects invalid source_type via CHECK constraint', () async {
      final db = await appDatabase.database;
      expect(
        () async => db.insert(AppDatabase.cashLotsTable, {
          'id': 'lot-bad-type',
          'trip_id': 'any',
          'source_type': 'unknown_type',
          'source_ref_type': 'cash_transaction',
          'source_ref_id': 'tx-1',
          'currency_code': 'USD',
          'original_amount': 100.0,
          'remaining_amount': 100.0,
          'is_fully_consumed': 0,
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });

    test('rejects remaining_amount exceeding original_amount via CHECK', () async {
      final db = await appDatabase.database;
      expect(
        () async => db.insert(AppDatabase.cashLotsTable, {
          'id': 'lot-over',
          'trip_id': 'any',
          'source_type': 'initial_cash',
          'source_ref_type': 'cash_transaction',
          'source_ref_id': 'tx-1',
          'currency_code': 'USD',
          'original_amount': 100.0,
          'remaining_amount': 200.0,
          'is_fully_consumed': 0,
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });

    test('accepts valid lot with all cost basis fields present', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-valid-lot';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Valid Lot Trip',
        'destination': 'Test',
        'base_currency': 'USD',
        'destination_currency': 'USD',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });
      await db.insert(AppDatabase.cashLotsTable, {
        'id': 'lot-valid',
        'trip_id': tripId,
        'source_type': 'initial_cash',
        'source_ref_type': 'cash_transaction',
        'source_ref_id': 'tx-1',
        'currency_code': 'USD',
        'original_amount': 500.0,
        'remaining_amount': 500.0,
        'home_currency_amount': 1875.0,
        'home_currency_code': 'SAR',
        'effective_rate': 3.75,
        'is_fully_consumed': 0,
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      final rows = await db.query(
        AppDatabase.cashLotsTable,
        where: 'id = ?',
        whereArgs: ['lot-valid'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['effective_rate'], closeTo(3.75, 0.0001));
    });

    test('rejects partial cost basis (only some of the three fields set)', () async {
      final db = await appDatabase.database;
      // home_currency_amount set but home_currency_code and effective_rate null
      expect(
        () async => db.insert(AppDatabase.cashLotsTable, {
          'id': 'lot-partial-basis',
          'trip_id': 'any',
          'source_type': 'initial_cash',
          'source_ref_type': 'cash_transaction',
          'source_ref_id': 'tx-1',
          'currency_code': 'USD',
          'original_amount': 100.0,
          'remaining_amount': 100.0,
          'home_currency_amount': 375.0,
          'home_currency_code': null,
          'effective_rate': null,
          'is_fully_consumed': 0,
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // cash_lot_consumptions
  // ---------------------------------------------------------------------------

  group('cash_lot_consumptions — table exists with correct schema', () {
    test('table is created', () async {
      expect(
        await tableExists(AppDatabase.cashLotConsumptionsTable),
        isTrue,
      );
    });

    test('has required columns', () async {
      final cols = (await tableInfo(AppDatabase.cashLotConsumptionsTable))
          .map((r) => r['name'] as String)
          .toSet();
      for (final col in [
        'id',
        'lot_id',
        'consumption_type',
        'expense_id',
        'exchange_id',
        'consumed_amount',
        'home_amount',
        'home_currency_code',
        'is_reversed',
        'reversed_at',
        'created_at',
      ]) {
        expect(cols, contains(col), reason: 'missing column: $col');
      }
    });

    test('has lot index', () async {
      final indexes = (await indexList(AppDatabase.cashLotConsumptionsTable))
          .map((r) => r['name'] as String)
          .toSet();
      expect(indexes, contains('idx_lot_consumptions_lot'));
    });

    test('has expense index', () async {
      final indexes = (await indexList(AppDatabase.cashLotConsumptionsTable))
          .map((r) => r['name'] as String)
          .toSet();
      expect(indexes, contains('idx_lot_consumptions_expense'));
    });

    test('has exchange index', () async {
      final indexes = (await indexList(AppDatabase.cashLotConsumptionsTable))
          .map((r) => r['name'] as String)
          .toSet();
      expect(indexes, contains('idx_lot_consumptions_exchange'));
    });

    test('rejects zero consumed_amount via CHECK constraint', () async {
      final db = await appDatabase.database;
      expect(
        () async => db.insert(AppDatabase.cashLotConsumptionsTable, {
          'id': 'con-zero',
          'lot_id': 'lot-1',
          'consumption_type': 'manual_reduction',
          'consumed_amount': 0.0,
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });

    test('rejects invalid consumption_type via CHECK constraint', () async {
      final db = await appDatabase.database;
      expect(
        () async => db.insert(AppDatabase.cashLotConsumptionsTable, {
          'id': 'con-bad-type',
          'lot_id': 'lot-1',
          'consumption_type': 'unknown',
          'consumed_amount': 50.0,
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });

    test('rejects cash_expense consumption without expense_id', () async {
      final db = await appDatabase.database;
      expect(
        () async => db.insert(AppDatabase.cashLotConsumptionsTable, {
          'id': 'con-no-expense',
          'lot_id': 'lot-1',
          'consumption_type': 'cash_expense',
          'expense_id': null,
          'exchange_id': null,
          'consumed_amount': 50.0,
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });

    test('rejects exchange_out consumption without exchange_id', () async {
      final db = await appDatabase.database;
      expect(
        () async => db.insert(AppDatabase.cashLotConsumptionsTable, {
          'id': 'con-no-exchange',
          'lot_id': 'lot-1',
          'consumption_type': 'exchange_out',
          'expense_id': null,
          'exchange_id': null,
          'consumed_amount': 50.0,
          'is_reversed': 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(anything),
      );
    });

    test('accepts valid manual_reduction consumption', () async {
      final db = await appDatabase.database;
      const tripId = 'trip-valid-consumption';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Consumption Trip',
        'destination': 'Test',
        'base_currency': 'USD',
        'destination_currency': 'USD',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });
      await db.insert(AppDatabase.cashLotsTable, {
        'id': 'lot-for-consumption',
        'trip_id': tripId,
        'source_type': 'initial_cash',
        'source_ref_type': 'cash_transaction',
        'source_ref_id': 'tx-ref',
        'currency_code': 'USD',
        'original_amount': 200.0,
        'remaining_amount': 200.0,
        'is_fully_consumed': 0,
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await db.insert(AppDatabase.cashLotConsumptionsTable, {
        'id': 'con-valid',
        'lot_id': 'lot-for-consumption',
        'consumption_type': 'manual_reduction',
        'expense_id': null,
        'exchange_id': null,
        'consumed_amount': 75.0,
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      final rows = await db.query(
        AppDatabase.cashLotConsumptionsTable,
        where: 'id = ?',
        whereArgs: ['con-valid'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['consumed_amount'], closeTo(75.0, 0.0001));
    });
  });

  // ---------------------------------------------------------------------------
  // Database version
  // ---------------------------------------------------------------------------

  group('database version', () {
    test('database version is at least 19', () async {
      final db = await appDatabase.database;
      final result = await db.rawQuery('PRAGMA user_version');
      expect(result.first['user_version'] as int, greaterThanOrEqualTo(19));
    });
  });

  // ---------------------------------------------------------------------------
  // Cascade delete — new tables are trip-scoped
  // ---------------------------------------------------------------------------

  group('CASCADE DELETE — new tables are trip-scoped', () {
    test('deleting trip removes cash_lots rows', () async {
      // Insert via raw SQL to avoid FK to currency_exchanges / cash_transactions
      // which don't have rows (polymorphic refs are app-layer enforced).
      final db = await appDatabase.database;
      const tripId = 'cascade-trip-lots';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Cascade Test',
        'destination': 'Test',
        'base_currency': 'USD',
        'destination_currency': 'USD',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });

      await db.insert(AppDatabase.cashLotsTable, {
        'id': 'lot-cascade',
        'trip_id': tripId,
        'source_type': 'initial_cash',
        'source_ref_type': 'cash_transaction',
        'source_ref_id': 'tx-cascade',
        'currency_code': 'USD',
        'original_amount': 100.0,
        'remaining_amount': 100.0,
        'is_fully_consumed': 0,
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.delete(AppDatabase.tripsTable, where: 'id = ?', whereArgs: [tripId]);

      final rows = await db.query(
        AppDatabase.cashLotsTable,
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      expect(rows, isEmpty);
    });

    test('deleting trip removes currency_exchanges rows', () async {
      final db = await appDatabase.database;
      const tripId = 'cascade-trip-exchanges';
      await db.insert(AppDatabase.tripsTable, {
        'id': tripId,
        'name': 'Cascade Test',
        'destination': 'Test',
        'base_currency': 'USD',
        'destination_currency': 'USD',
        'home_currency_snapshot': 'SAR',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_custom_title': 0,
      });

      await db.insert(AppDatabase.currencyExchangesTable, {
        'id': 'ex-cascade',
        'trip_id': tripId,
        'from_currency_code': 'USD',
        'from_amount': 100.0,
        'to_currency_code': 'SAR',
        'to_amount': 375.0,
        'exchange_rate': 3.75,
        'to_lot_id': 'lot-any',
        'is_reversed': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.delete(AppDatabase.tripsTable, where: 'id = ?', whereArgs: [tripId]);

      final rows = await db.query(
        AppDatabase.currencyExchangesTable,
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      expect(rows, isEmpty);
    });
  });
}
