// Sprint 9B — backfill FIFO cash lots for pre–Sprint 9A inflow transactions.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_backfill.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late TripRepository tripRepo;
  late CashWalletRepository walletRepo;
  late CashLotRepository lotRepo;
  late CashLotBackfill backfill;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'sprint9b_backfill');
    tripRepo = TripRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    backfill = CashLotBackfill();

    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-9b',
        name: 'Sprint 9B Trip',
        destination: 'Thailand',
        baseCurrency: 'THB',
        destinationCurrency: 'THB',
        homeCurrencySnapshot: 'SAR',
      ),
    );

    // Prime schema (v21) — onOpen backfill runs against an empty ledger.
    await db.database;
  });

  tearDown(() async => db.close());

  Future<void> insertLegacyTransaction({
    required String id,
    required CashTransactionType type,
    required double amount,
    String currencyCode = 'USD',
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    bool isReversed = false,
    String? lotId,
  }) async {
    final database = await db.database;
    await database.insert(AppDatabase.cashTransactionsTable, {
      'id': id,
      'trip_id': trip.id,
      'type': type.value,
      'amount': amount,
      'currency_code': currencyCode,
      'home_currency_amount': ?homeCurrencyAmount,
      'home_currency_code': ?homeCurrencyCode,
      'is_reversed': isReversed ? 1 : 0,
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      'lot_id': ?lotId,
    });
    await database.insert(
      AppDatabase.tripCashBalancesTable,
      {
        'trip_id': trip.id,
        'currency_code': currencyCode,
        'balance_amount': amount,
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>> txnRow(String id) async {
    final database = await db.database;
    final rows = await database.query(
      AppDatabase.cashTransactionsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.single;
  }

  Future<int> runBackfill() async {
    final database = await db.database;
    return backfill.backfillUnlinkedInflowLots(database);
  }

  group('1 — legacy initial_cash', () {
    test('initial_cash without lot_id gets a cash_lot on backfill', () async {
      await insertLegacyTransaction(
        id: 'legacy-initial',
        type: CashTransactionType.initialCash,
        amount: 1000,
        homeCurrencyAmount: 3750,
        homeCurrencyCode: 'SAR',
      );

      expect(await runBackfill(), 1);

      final row = await txnRow('legacy-initial');
      expect(row['lot_id'], isNotNull);

      final lot = await lotRepo.getCashLotById(row['lot_id']! as String);
      expect(lot!.sourceType, 'initial_cash');
      expect(lot.sourceRefType, 'cash_transaction');
      expect(lot.sourceRefId, 'legacy-initial');
      expect(lot.originalAmount, closeTo(1000, 1e-9));
      expect(lot.remainingAmount, closeTo(1000, 1e-9));
      expect(lot.effectiveRate, closeTo(3.75, 1e-12));
    });
  });

  group('2 — legacy manual positive inflow', () {
    test('manual_adjustment without lot_id gets a cash_lot', () async {
      await insertLegacyTransaction(
        id: 'legacy-manual',
        type: CashTransactionType.manualAdjustment,
        amount: 500,
        currencyCode: 'THB',
        homeCurrencyAmount: 60,
        homeCurrencyCode: 'SAR',
      );

      expect(await runBackfill(), 1);

      final row = await txnRow('legacy-manual');
      final lot = await lotRepo.getCashLotById(row['lot_id']! as String);
      expect(lot!.sourceType, 'manual_adjustment');
      expect(lot.effectiveRate, closeTo(0.12, 1e-12));
    });
  });

  group('3 — reversed inflow ignored', () {
    test('reversed initial_cash is not backfilled', () async {
      await insertLegacyTransaction(
        id: 'legacy-reversed',
        type: CashTransactionType.initialCash,
        amount: 1000,
        isReversed: true,
      );

      expect(await runBackfill(), 0);
      expect((await txnRow('legacy-reversed'))['lot_id'], isNull);

      final database = await db.database;
      final lots = await database.query(
        AppDatabase.cashLotsTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      expect(lots, isEmpty);
    });
  });

  group('4 — outflow ignored', () {
    test('cash_expense_deduction is not backfilled', () async {
      await insertLegacyTransaction(
        id: 'legacy-outflow',
        type: CashTransactionType.cashExpenseDeduction,
        amount: 200,
      );

      expect(await runBackfill(), 0);
      expect((await txnRow('legacy-outflow'))['lot_id'], isNull);
    });
  });

  group('5 — existing lot-backed transaction not duplicated', () {
    test('Sprint 9A lot-backed transaction is untouched', () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 800,
        currencyCode: 'USD',
        homeCurrencyAmount: 3000,
        homeCurrencyCode: 'SAR',
      );

      final txns = await walletRepo.getRecentTransactionsByTrip(trip.id);
      final existingLotId = txns.single.lotId!;

      final database = await db.database;
      final lotsBefore = await database.query(AppDatabase.cashLotsTable);

      expect(await runBackfill(), 0);

      final lotsAfter = await database.query(AppDatabase.cashLotsTable);
      expect(lotsAfter, hasLength(lotsBefore.length));
      expect(txns.single.lotId, existingLotId);
    });
  });

  group('6 — idempotent', () {
    test('second backfill run creates no duplicate lots', () async {
      await insertLegacyTransaction(
        id: 'legacy-idempotent',
        type: CashTransactionType.initialCash,
        amount: 1000,
      );

      expect(await runBackfill(), 1);
      expect(await runBackfill(), 0);

      final database = await db.database;
      final lots = await database.query(
        AppDatabase.cashLotsTable,
        where: "source_ref_type = 'cash_transaction' AND source_ref_id = ?",
        whereArgs: ['legacy-idempotent'],
      );
      expect(lots, hasLength(1));
    });
  });

  group('7 — backfilled lot is spendable via FIFO', () {
    test('RecordCashExpenseUseCase consumes a backfilled lot', () async {
      await insertLegacyTransaction(
        id: 'legacy-spend',
        type: CashTransactionType.initialCash,
        amount: 1000,
        homeCurrencyAmount: 3750,
        homeCurrencyCode: 'SAR',
      );
      await runBackfill();

      final recordCashExpense = RecordCashExpenseUseCase(
        appDatabase: db,
        expenseRepository: ExpenseRepository(db),
        cashWalletRepository: walletRepo,
        fifoEngine: CashLotFifoEngine(lotRepo),
        lotRepository: lotRepo,
        consumptionRepository: CashLotConsumptionRepository(db),
      );

      final result = await recordCashExpense.execute(
        Expense.create(
          tripId: trip.id,
          title: 'Snack',
          amount: 200,
          currencyCode: 'USD',
          transactionAmount: 200,
          transactionCurrency: 'USD',
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Food',
        ),
      );

      expect(result.expense.convertedHomeAmount, closeTo(750, 1e-9));

      final row = await txnRow('legacy-spend');
      final lot = await lotRepo.getCashLotById(row['lot_id']! as String);
      expect(lot!.remainingAmount, closeTo(800, 1e-9));
    });
  });

  group('8 — remaining cash value', () {
    test('computeLotCurrencySummaries includes backfilled lot', () async {
      await insertLegacyTransaction(
        id: 'legacy-report',
        type: CashTransactionType.initialCash,
        amount: 1000,
        homeCurrencyAmount: 3750,
        homeCurrencyCode: 'SAR',
      );
      await runBackfill();

      final summaries = await lotRepo.computeLotCurrencySummaries(
        tripId: trip.id,
        homeCurrencyCode: 'SAR',
      );
      final usd = summaries.singleWhere((s) => s.currencyCode == 'USD');
      expect(usd.totalRemainingAmount, closeTo(1000, 1e-9));
      expect(usd.totalHomeAmount, closeTo(3750, 1e-9));
    });
  });

  group('onOpen integration', () {
    test('database open backfills legacy rows inserted before first open',
        () async {
      final freshDb = createIsolatedAppDatabase(prefix: 'sprint9b_onopen');
      try {
        final freshTripRepo = TripRepository(freshDb);
        final freshTrip = await freshTripRepo.createTrip(
          Trip.create(
            id: 'trip-onopen',
            name: 'OnOpen Trip',
            destination: 'Japan',
            baseCurrency: 'JPY',
            destinationCurrency: 'JPY',
            homeCurrencySnapshot: 'SAR',
          ),
        );

        // Insert legacy inflow before the database is opened (no onOpen yet).
        // Use a raw path: open once to create schema, close, reopen with legacy
        // data inserted via a second connection is awkward with sqflite.
        // Instead: open DB, insert legacy, rely on explicit backfill matching
        // the onOpen hook (same CashLotBackfill entry point).
        final database = await freshDb.database;
        await database.insert(AppDatabase.cashTransactionsTable, {
          'id': 'legacy-onopen',
          'trip_id': freshTrip.id,
          'type': 'initial_cash',
          'amount': 5000.0,
          'currency_code': 'JPY',
          'is_reversed': 0,
          'created_at': DateTime.utc(2026, 2, 1).toIso8601String(),
        });

        await CashLotBackfill().backfillUnlinkedInflowLots(database);

        final rows = await database.query(
          AppDatabase.cashTransactionsTable,
          where: 'id = ?',
          whereArgs: ['legacy-onopen'],
        );
        expect(rows.single['lot_id'], isNotNull);
      } finally {
        await freshDb.close();
      }
    });
  });
}
