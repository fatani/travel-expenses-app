// Sprint 9A — F-C wiring fix: initial/manual cash added through the
// production UI paths (trip setup, Add Cash sheet) must create FIFO cash
// lots so the cash is spendable and visible to lot-based reporting.
//
// Both UI paths call CashWalletRepository.addCashTransaction(), which is the
// unit under test here.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:uuid/uuid.dart';

import '../../../support/isolated_app_database.dart';

/// Uuid stub returning a fixed sequence of ids, used to force a primary-key
/// collision deep inside the transaction (atomic-rollback test).
class _SequenceUuid implements Uuid {
  _SequenceUuid(this._values);

  final List<String> _values;
  var _index = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (_index < _values.length) {
      return _values[_index++];
    }
    return 'overflow-${_index++}';
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late TripRepository tripRepo;
  late CashWalletRepository walletRepo;
  late CashLotRepository lotRepo;
  late CashLotConsumptionRepository consumptionRepo;
  late ExpenseRepository expenseRepo;
  late RecordCashExpenseUseCase recordCashExpense;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'sprint9a_cash_lot');
    tripRepo = TripRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    consumptionRepo = CashLotConsumptionRepository(db);
    expenseRepo = ExpenseRepository(db);
    recordCashExpense = RecordCashExpenseUseCase(
      appDatabase: db,
      expenseRepository: expenseRepo,
      cashWalletRepository: walletRepo,
      fifoEngine: CashLotFifoEngine(lotRepo),
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
    );

    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-9a',
        name: 'Sprint 9A Trip',
        destination: 'Thailand',
        baseCurrency: 'THB',
        destinationCurrency: 'THB',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  Future<CashTransaction> latestTransaction() async {
    final txns = await walletRepo.getRecentTransactionsByTrip(trip.id);
    return txns.first;
  }

  Future<List<Map<String, Object?>>> lotRows() async {
    final database = await db.database;
    return database.query(
      AppDatabase.cashLotsTable,
      where: 'trip_id = ?',
      whereArgs: [trip.id],
    );
  }

  // ---------------------------------------------------------------------------
  // 1 + 2 — Trip setup initial cash path (no cost basis collected there)
  // ---------------------------------------------------------------------------

  group('1/2 — trip setup initial cash creates a linked cash lot', () {
    test('addCashTransaction(initialCash) creates a cash_lots row', () async {
      // Mirrors trip_setup_screen.dart: amount + currency only.
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
      );

      final lots = await lotRows();
      expect(lots, hasLength(1));
      expect(lots.single['source_type'], 'initial_cash');
      expect(lots.single['currency_code'], 'USD');
      expect((lots.single['original_amount'] as num).toDouble(),
          closeTo(1000, 1e-9));
      expect((lots.single['remaining_amount'] as num).toDouble(),
          closeTo(1000, 1e-9));
      expect(lots.single['is_reversed'], 0);
    });

    test('initial cash lot links to its cash transaction (both directions)',
        () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
      );

      final txn = await latestTransaction();
      final lots = await lotRows();
      expect(txn.lotId, lots.single['id']);
      expect(lots.single['source_ref_type'], 'cash_transaction');
      expect(lots.single['source_ref_id'], txn.id);
    });
  });

  // ---------------------------------------------------------------------------
  // 3 + 4 — Cost basis rule
  // ---------------------------------------------------------------------------

  group('3/4 — cost basis rule', () {
    test('initial cash with cost basis sets effective_rate = home / cash',
        () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
        homeCurrencyAmount: 3750,
        homeCurrencyCode: 'SAR',
      );

      final lot = CashLot.fromMap((await lotRows()).single);
      expect(lot.homeCurrencyAmount, closeTo(3750, 1e-9));
      expect(lot.homeCurrencyCode, 'SAR');
      expect(lot.effectiveRate, closeTo(3.75, 1e-12));
    });

    test('initial cash without cost basis creates lot with null basis',
        () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
      );

      final lot = CashLot.fromMap((await lotRows()).single);
      expect(lot.homeCurrencyAmount, isNull);
      expect(lot.homeCurrencyCode, isNull);
      expect(lot.effectiveRate, isNull);
    });

    test('zero-amount initial cash creates no lot', () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 0,
        currencyCode: 'USD',
      );

      expect(await lotRows(), isEmpty);
      final txn = await latestTransaction();
      expect(txn.lotId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 5 + 6 — Manual Add Cash sheet path
  // ---------------------------------------------------------------------------

  group('5/6 — manual add cash creates a linked cash lot', () {
    test('manualAdjustment creates a manual_adjustment lot', () async {
      // Mirrors trip_cash_wallet_screen.dart Add Cash sheet fallback branch.
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.manualAdjustment,
        amount: 500,
        currencyCode: 'THB',
        homeCurrencyAmount: 60,
        homeCurrencyCode: 'SAR',
        note: 'leftover from friend',
      );

      final lot = CashLot.fromMap((await lotRows()).single);
      expect(lot.sourceType, 'manual_adjustment');
      expect(lot.originalAmount, closeTo(500, 1e-9));
      expect(lot.remainingAmount, closeTo(500, 1e-9));
      expect(lot.effectiveRate, closeTo(0.12, 1e-12));
      expect(lot.note, 'leftover from friend');
    });

    test('manual lot source_ref_id equals the cash_transaction id', () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.manualAdjustment,
        amount: 500,
        currencyCode: 'THB',
      );

      final txn = await latestTransaction();
      final lot = CashLot.fromMap((await lotRows()).single);
      expect(lot.sourceRefType, 'cash_transaction');
      expect(lot.sourceRefId, txn.id);
      expect(txn.lotId, lot.id);
    });
  });

  // ---------------------------------------------------------------------------
  // 7 — Cash added via UI path is spendable by RecordCashExpenseUseCase
  // ---------------------------------------------------------------------------

  group('7 — UI-path cash is spendable via FIFO', () {
    test('cash expense consumes the initial-cash lot with FIFO cost basis',
        () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
        homeCurrencyAmount: 3750,
        homeCurrencyCode: 'SAR',
      );

      final result = await recordCashExpense.execute(
        Expense.create(
          tripId: trip.id,
          title: 'Dinner',
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
      expect(result.expense.conversionRate, closeTo(3.75, 1e-12));

      final lot = CashLot.fromMap((await lotRows()).single);
      expect(lot.remainingAmount, closeTo(800, 1e-9));

      final consumptions =
          await consumptionRepo.getConsumptionsByExpenseId(result.expense.id);
      expect(consumptions, hasLength(1));
      expect(consumptions.single.lotId, lot.id);
      expect(consumptions.single.homeAmount, closeTo(750, 1e-9));

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      expect(balances.single.balanceAmount, closeTo(800, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // 8 — Remaining cash value sees initial/manual cash lots
  // ---------------------------------------------------------------------------

  group('8 — remaining cash value', () {
    test('computeLotCurrencySummaries includes UI-added cash', () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
        homeCurrencyAmount: 3750,
        homeCurrencyCode: 'SAR',
      );
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.manualAdjustment,
        amount: 500,
        currencyCode: 'THB',
        homeCurrencyAmount: 60,
        homeCurrencyCode: 'SAR',
      );

      final summaries = await lotRepo.computeLotCurrencySummaries(
        tripId: trip.id,
        homeCurrencyCode: 'SAR',
      );
      final byCurrency = {for (final s in summaries) s.currencyCode: s};
      expect(byCurrency['USD']!.totalRemainingAmount, closeTo(1000, 1e-9));
      expect(byCurrency['USD']!.totalHomeAmount, closeTo(3750, 1e-9));
      expect(byCurrency['THB']!.totalRemainingAmount, closeTo(500, 1e-9));
      expect(byCurrency['THB']!.totalHomeAmount, closeTo(60, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // 9 — Atomic rollback on failure
  // ---------------------------------------------------------------------------

  group('9 — atomic rollback', () {
    test('mid-transaction failure leaves no partial lot, transaction, '
        'or balance update', () async {
      // The lot row is written first; force the subsequent cash_transactions
      // insert to collide on its primary key so the transaction rolls back
      // AFTER the lot write — the lot must not survive.
      final collidingWallet = CashWalletRepository(
        db,
        uuid: _SequenceUuid([
          'txn-9a-1', 'lot-9a-1', // first call succeeds
          'txn-9a-1', 'lot-9a-2', // second call collides on txn id
        ]),
      );

      await collidingWallet.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
      );

      await expectLater(
        collidingWallet.addCashTransaction(
          tripId: trip.id,
          type: CashTransactionType.initialCash,
          amount: 700,
          currencyCode: 'USD',
        ),
        throwsA(anything),
      );

      // Only the first transaction exists.
      final txns = await walletRepo.getRecentTransactionsByTrip(
        trip.id,
        includeReversed: true,
      );
      expect(txns, hasLength(1));
      expect(txns.single.id, 'txn-9a-1');

      // The second call's lot was rolled back.
      final lots = await lotRows();
      expect(lots, hasLength(1));
      expect(lots.single['id'], 'lot-9a-1');

      // Balance reflects only the first addition.
      final balances = await walletRepo.getBalancesByTrip(trip.id);
      expect(balances.single.balanceAmount, closeTo(1000, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // 10 — No duplicate lots for one cash transaction
  // ---------------------------------------------------------------------------

  group('10 — no duplicate lots', () {
    test('one addCashTransaction call creates exactly one lot', () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
      );

      final txn = await latestTransaction();
      final linked = await lotRepo.getLotsBySourceRef(
        'cash_transaction',
        txn.id,
      );
      expect(linked, hasLength(1));
      expect(await lotRows(), hasLength(1));
    });

    test('two separate additions create one lot each', () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
      );
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.manualAdjustment,
        amount: 500,
        currencyCode: 'USD',
      );

      final lots = await lotRows();
      expect(lots, hasLength(2));
      final refIds = lots.map((l) => l['source_ref_id']).toSet();
      expect(refIds, hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // Lot ledger consistency on reverse / edit of manual transactions
  // ---------------------------------------------------------------------------

  group('reverse/edit keeps the lot ledger consistent', () {
    test('reversing a manual transaction reverses its unconsumed lot',
        () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.manualAdjustment,
        amount: 500,
        currencyCode: 'THB',
      );
      final txn = await latestTransaction();

      await walletRepo.reverseManualCashTransaction(transaction: txn);

      final lot = CashLot.fromMap((await lotRows()).single);
      expect(lot.isReversed, isTrue);
      expect(lot.remainingAmount, 0);
      // FIFO no longer sees this cash.
      final open = await lotRepo.getOpenLotsForCurrency(trip.id, 'THB');
      expect(open, isEmpty);
      final balances = await walletRepo.getBalancesByTrip(trip.id);
      expect(balances.single.balanceAmount, closeTo(0, 1e-9));
    });

    test('reversing is blocked when the lot cash was already spent', () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'USD',
        homeCurrencyAmount: 3750,
        homeCurrencyCode: 'SAR',
      );
      final txn = await latestTransaction();
      await recordCashExpense.execute(
        Expense.create(
          tripId: trip.id,
          title: 'Dinner',
          amount: 200,
          currencyCode: 'USD',
          transactionAmount: 200,
          transactionCurrency: 'USD',
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Food',
        ),
      );

      await expectLater(
        walletRepo.reverseManualCashTransaction(transaction: txn),
        throwsStateError,
      );

      // Nothing changed: transaction still active, lot still open.
      final after = await walletRepo.getRecentTransactionsByTrip(trip.id);
      expect(
        after.firstWhere((t) => t.id == txn.id).isReversed,
        isFalse,
      );
      final lot = CashLot.fromMap((await lotRows()).single);
      expect(lot.isReversed, isFalse);
      expect(lot.remainingAmount, closeTo(800, 1e-9));
    });

    test('editing a manual transaction reverses old lot and creates new one',
        () async {
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.manualAdjustment,
        amount: 500,
        currencyCode: 'THB',
        homeCurrencyAmount: 60,
        homeCurrencyCode: 'SAR',
      );
      final original = await latestTransaction();

      await walletRepo.updateManualCashTransaction(
        existingTransaction: original,
        nextType: CashTransactionType.manualAdjustment,
        nextAmount: 800,
        nextCurrencyCode: 'THB',
        nextHomeCurrencyAmount: 96,
        nextHomeCurrencyCode: 'SAR',
      );

      final lots = (await lotRows()).map(CashLot.fromMap).toList();
      expect(lots, hasLength(2));
      final reversed = lots.where((l) => l.isReversed).toList();
      final active = lots.where((l) => !l.isReversed).toList();
      expect(reversed, hasLength(1));
      expect(active, hasLength(1));
      expect(active.single.originalAmount, closeTo(800, 1e-9));
      expect(active.single.effectiveRate, closeTo(0.12, 1e-12));

      final replacement = await latestTransaction();
      expect(replacement.lotId, active.single.id);
      expect(active.single.sourceRefId, replacement.id);

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      expect(balances.single.balanceAmount, closeTo(800, 1e-9));
    });
  });
}
