import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_consumption.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late TripRepository tripRepository;
  late CashLotRepository cashLotRepository;
  late CashLotConsumptionRepository consumptionRepository;
  late CurrencyExchangeRepository exchangeRepository;
  late ExpenseRepository expenseRepository;
  late ExpenseRefundRepository refundRepository;
  late CashWalletRepository cashWalletRepository;

  late Trip testTrip;

  setUp(() async {
    appDatabase = createIsolatedAppDatabase(prefix: 'sprint_2');
    tripRepository = TripRepository(appDatabase);
    cashLotRepository = CashLotRepository(appDatabase);
    consumptionRepository = CashLotConsumptionRepository(appDatabase);
    exchangeRepository = CurrencyExchangeRepository(appDatabase);
    expenseRepository = ExpenseRepository(appDatabase);
    refundRepository = ExpenseRefundRepository(appDatabase);
    cashWalletRepository = CashWalletRepository(appDatabase);

    testTrip = await tripRepository.createTrip(
      Trip.create(
        id: 'trip-s2',
        name: 'Sprint 2 Trip',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  // ---------------------------------------------------------------------------
  // CashLotRepository
  // ---------------------------------------------------------------------------

  group('CashLotRepository', () {
    CashLot buildLot({
      String id = '',
      String currency = 'JPY',
      double amount = 10000,
      String sourceRefId = 'tx-001',
    }) {
      return CashLot.create(
        id: id,
        tripId: testTrip.id,
        sourceType: 'initial_cash',
        sourceRefType: 'cash_transaction',
        sourceRefId: sourceRefId,
        currencyCode: currency,
        originalAmount: amount,
      );
    }

    test('insertCashLot assigns id when empty and persists', () async {
      final lot = await cashLotRepository.insertCashLot(buildLot());
      expect(lot.id, isNotEmpty);

      final fetched = await cashLotRepository.getCashLotById(lot.id);
      expect(fetched, isNotNull);
      expect(fetched!.tripId, testTrip.id);
      expect(fetched.currencyCode, 'JPY');
      expect(fetched.originalAmount, 10000);
      expect(fetched.remainingAmount, 10000);
      expect(fetched.isReversed, isFalse);
      expect(fetched.isFullyConsumed, isFalse);
    });

    test('insertCashLot preserves provided id', () async {
      final lot = await cashLotRepository.insertCashLot(
        buildLot(id: 'lot-fixed-id'),
      );
      expect(lot.id, 'lot-fixed-id');
    });

    test('getCashLotById returns null for unknown id', () async {
      final result = await cashLotRepository.getCashLotById('no-such-lot');
      expect(result, isNull);
    });

    test('getOpenLotsForCurrency returns only open lots ordered oldest-first', () async {
      final lot1 = await cashLotRepository.insertCashLot(buildLot(sourceRefId: 'tx-1'));
      final lot2 = await cashLotRepository.insertCashLot(buildLot(sourceRefId: 'tx-2'));
      // Insert a reversed lot — must not appear
      final lot3 = await cashLotRepository.insertCashLot(buildLot(sourceRefId: 'tx-3'));
      await cashLotRepository.markLotReversed(lot3.id);

      final open = await cashLotRepository.getOpenLotsForCurrency(testTrip.id, 'JPY');
      final ids = open.map((l) => l.id).toList();
      expect(ids, containsAllInOrder([lot1.id, lot2.id]));
      expect(ids, isNot(contains(lot3.id)));
    });

    test('getOpenLotsForCurrency excludes fully consumed lots', () async {
      final lot = await cashLotRepository.insertCashLot(buildLot());
      await cashLotRepository.updateLotRemainingAmount(lot.id, 0);

      final open = await cashLotRepository.getOpenLotsForCurrency(testTrip.id, 'JPY');
      expect(open, isEmpty);
    });

    test('updateLotRemainingAmount sets remaining and marks fully consumed when zero', () async {
      final lot = await cashLotRepository.insertCashLot(buildLot(amount: 5000));
      await cashLotRepository.updateLotRemainingAmount(lot.id, 0);

      final fetched = await cashLotRepository.getCashLotById(lot.id);
      expect(fetched!.remainingAmount, 0);
      expect(fetched.isFullyConsumed, isTrue);
    });

    test('updateLotRemainingAmount partial draw does not mark fully consumed', () async {
      final lot = await cashLotRepository.insertCashLot(buildLot(amount: 5000));
      await cashLotRepository.updateLotRemainingAmount(lot.id, 2000);

      final fetched = await cashLotRepository.getCashLotById(lot.id);
      expect(fetched!.remainingAmount, 2000);
      expect(fetched.isFullyConsumed, isFalse);
    });

    test('markLotReversed sets is_reversed and remaining to zero', () async {
      final lot = await cashLotRepository.insertCashLot(buildLot());
      await cashLotRepository.markLotReversed(lot.id);

      final fetched = await cashLotRepository.getCashLotById(lot.id);
      expect(fetched!.isReversed, isTrue);
      expect(fetched.reversedAt, isNotNull);
      expect(fetched.remainingAmount, 0);
      expect(fetched.isFullyConsumed, isTrue);
    });

    test('getLotsBySourceRef returns lots with matching source ref', () async {
      final lot = await cashLotRepository.insertCashLot(buildLot(sourceRefId: 'tx-abc'));
      await cashLotRepository.insertCashLot(buildLot(sourceRefId: 'tx-xyz'));

      final results = await cashLotRepository.getLotsBySourceRef(
        'cash_transaction',
        'tx-abc',
      );
      expect(results, hasLength(1));
      expect(results.first.id, lot.id);
    });
  });

  // ---------------------------------------------------------------------------
  // CashLotConsumptionRepository
  // ---------------------------------------------------------------------------

  group('CashLotConsumptionRepository', () {
    late CashLot parentLot;

    setUp(() async {
      parentLot = await cashLotRepository.insertCashLot(
        CashLot.create(
          tripId: testTrip.id,
          sourceType: 'initial_cash',
          sourceRefType: 'cash_transaction',
          sourceRefId: 'tx-parent',
          currencyCode: 'JPY',
          originalAmount: 50000,
        ),
      );
    });

    CashLotConsumption buildConsumption({
      String? expenseId,
      String? exchangeId,
      String consumptionType = 'cash_expense',
      double amount = 1000,
    }) {
      return CashLotConsumption.create(
        lotId: parentLot.id,
        consumptionType: consumptionType,
        expenseId: expenseId,
        exchangeId: exchangeId,
        consumedAmount: amount,
      );
    }

    test('insertConsumption assigns id and persists', () async {
      final expense = await expenseRepository.createExpense(
        Expense.create(
          id: 'exp-c1',
          tripId: testTrip.id,
          title: 'Ramen',
          amount: 1000,
          currencyCode: 'JPY',
          paymentMethod: 'Cash',
        ),
      );

      final consumption = await consumptionRepository.insertConsumption(
        buildConsumption(expenseId: expense.id),
      );
      expect(consumption.id, isNotEmpty);

      final fetched = await consumptionRepository.getConsumptionsByExpenseId(expense.id);
      expect(fetched, hasLength(1));
      expect(fetched.first.lotId, parentLot.id);
      expect(fetched.first.consumedAmount, 1000);
      expect(fetched.first.isReversed, isFalse);
    });

    test('getConsumptionsByLotId returns all consumptions for lot', () async {
      final exp1 = await expenseRepository.createExpense(
        Expense.create(
          id: 'exp-l1',
          tripId: testTrip.id,
          title: 'A',
          amount: 500,
          currencyCode: 'JPY',
          paymentMethod: 'Cash',
        ),
      );
      final exp2 = await expenseRepository.createExpense(
        Expense.create(
          id: 'exp-l2',
          tripId: testTrip.id,
          title: 'B',
          amount: 300,
          currencyCode: 'JPY',
          paymentMethod: 'Cash',
        ),
      );

      await consumptionRepository.insertConsumption(
        buildConsumption(expenseId: exp1.id, amount: 500),
      );
      await consumptionRepository.insertConsumption(
        buildConsumption(expenseId: exp2.id, amount: 300),
      );

      final results = await consumptionRepository.getConsumptionsByLotId(parentLot.id);
      expect(results, hasLength(2));
    });

    test('markConsumptionsReversedForExpense marks matching rows only', () async {
      final exp = await expenseRepository.createExpense(
        Expense.create(
          id: 'exp-rev',
          tripId: testTrip.id,
          title: 'Rev',
          amount: 800,
          currencyCode: 'JPY',
          paymentMethod: 'Cash',
        ),
      );
      final other = await expenseRepository.createExpense(
        Expense.create(
          id: 'exp-other',
          tripId: testTrip.id,
          title: 'Other',
          amount: 200,
          currencyCode: 'JPY',
          paymentMethod: 'Cash',
        ),
      );

      await consumptionRepository.insertConsumption(
        buildConsumption(expenseId: exp.id, amount: 800),
      );
      await consumptionRepository.insertConsumption(
        buildConsumption(expenseId: other.id, amount: 200),
      );

      final db = await appDatabase.database;
      await db.transaction((txn) async {
        await consumptionRepository.markConsumptionsReversedForExpense(txn, exp.id);
      });

      final reversed = await consumptionRepository.getConsumptionsByExpenseId(exp.id);
      expect(reversed.first.isReversed, isTrue);

      final untouched = await consumptionRepository.getConsumptionsByExpenseId(other.id);
      expect(untouched.first.isReversed, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // CurrencyExchangeRepository
  // ---------------------------------------------------------------------------

  group('CurrencyExchangeRepository', () {
    Future<CashLot> insertToLot(String currency) async {
      return cashLotRepository.insertCashLot(
        CashLot.create(
          tripId: testTrip.id,
          sourceType: 'exchange_in',
          sourceRefType: 'currency_exchange',
          sourceRefId: 'ex-src',
          currencyCode: currency,
          originalAmount: 5000,
        ),
      );
    }

    test('insertCurrencyExchange assigns id and persists', () async {
      final toLot = await insertToLot('JPY');
      final exchange = await exchangeRepository.insertCurrencyExchange(
        CurrencyExchange.create(
          tripId: testTrip.id,
          fromCurrencyCode: 'SAR',
          fromAmount: 100,
          toCurrencyCode: 'JPY',
          toAmount: 4000,
          exchangeRate: 40.0,
          toLotId: toLot.id,
        ),
      );
      expect(exchange.id, isNotEmpty);

      final fetched = await exchangeRepository.getExchangeById(exchange.id);
      expect(fetched, isNotNull);
      expect(fetched!.fromCurrencyCode, 'SAR');
      expect(fetched.toCurrencyCode, 'JPY');
      expect(fetched.fromAmount, 100);
      expect(fetched.toAmount, 4000);
      expect(fetched.exchangeRate, 40.0);
      expect(fetched.isReversed, isFalse);
    });

    test('getExchangeById returns null for unknown id', () async {
      expect(await exchangeRepository.getExchangeById('no-id'), isNull);
    });

    test('getExchangesByTripId returns exchanges for trip ordered newest-first', () async {
      final toLot1 = await insertToLot('JPY');
      final toLot2 = await insertToLot('JPY');

      final ex1 = await exchangeRepository.insertCurrencyExchange(
        CurrencyExchange.create(
          tripId: testTrip.id,
          fromCurrencyCode: 'SAR',
          fromAmount: 50,
          toCurrencyCode: 'JPY',
          toAmount: 2000,
          exchangeRate: 40.0,
          toLotId: toLot1.id,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final ex2 = await exchangeRepository.insertCurrencyExchange(
        CurrencyExchange.create(
          tripId: testTrip.id,
          fromCurrencyCode: 'SAR',
          fromAmount: 50,
          toCurrencyCode: 'JPY',
          toAmount: 2000,
          exchangeRate: 40.0,
          toLotId: toLot2.id,
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      );

      final list = await exchangeRepository.getExchangesByTripId(testTrip.id);
      expect(list, hasLength(2));
      expect(list.first.id, ex2.id);
      expect(list.last.id, ex1.id);
    });

    test('markExchangeReversed sets is_reversed and reversed_at', () async {
      final toLot = await insertToLot('JPY');
      final exchange = await exchangeRepository.insertCurrencyExchange(
        CurrencyExchange.create(
          tripId: testTrip.id,
          fromCurrencyCode: 'SAR',
          fromAmount: 100,
          toCurrencyCode: 'JPY',
          toAmount: 4000,
          exchangeRate: 40.0,
          toLotId: toLot.id,
        ),
      );

      await exchangeRepository.markExchangeReversed(exchange.id);

      final fetched = await exchangeRepository.getExchangeById(exchange.id);
      expect(fetched!.isReversed, isTrue);
      expect(fetched.reversedAt, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // CashTransaction — lotId / exchangeId exposed
  // ---------------------------------------------------------------------------

  group('CashTransaction lotId and exchangeId', () {
    test(
        'fromMap exposes lot_id created by addCashTransaction (Sprint 9A) '
        'and null exchange_id', () async {
      await cashWalletRepository.addCashTransaction(
        tripId: testTrip.id,
        type: CashTransactionType.initialCash,
        amount: 5000,
        currencyCode: 'JPY',
      );

      final txns = await cashWalletRepository.getRecentTransactionsByTrip(testTrip.id);
      expect(txns, hasLength(1));
      // Since Sprint 9A, manual cash inflows are lot-backed.
      expect(txns.first.lotId, isNotNull);
      expect(txns.first.exchangeId, isNull);
    });

    test('toMap includes lot_id and exchange_id when set', () async {
      final lot = await cashLotRepository.insertCashLot(
        CashLot.create(
          tripId: testTrip.id,
          sourceType: 'initial_cash',
          sourceRefType: 'cash_transaction',
          sourceRefId: 'placeholder',
          currencyCode: 'JPY',
          originalAmount: 5000,
        ),
      );

      final tx = CashTransaction.create(
        id: 'tx-with-lot',
        tripId: testTrip.id,
        type: CashTransactionType.initialCash,
        amount: 5000,
        currencyCode: 'JPY',
        lotId: lot.id,
      );

      final db = await appDatabase.database;
      await db.insert('cash_transactions', tx.toMap());

      final rows = await db.query(
        'cash_transactions',
        where: 'id = ?',
        whereArgs: ['tx-with-lot'],
      );
      expect(rows.first['lot_id'], lot.id);
      expect(rows.first['exchange_id'], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Expense — isReversed / reversedAt exposed
  // ---------------------------------------------------------------------------

  group('Expense isReversed and reversedAt', () {
    test('new expense is not reversed by default', () async {
      final expense = await expenseRepository.createExpense(
        Expense.create(
          id: 'exp-ir',
          tripId: testTrip.id,
          title: 'Not reversed',
          amount: 500,
          currencyCode: 'JPY',
          paymentMethod: 'Cash',
        ),
      );

      final fetched = await expenseRepository.getExpenseById(expense.id);
      expect(fetched!.isReversed, isFalse);
      expect(fetched.reversedAt, isNull);
    });

    test('toMap writes is_reversed=0 and reversed_at=null for active expense', () {
      final expense = Expense.create(
        id: 'exp-map',
        tripId: 'trip-x',
        title: 'T',
        amount: 100,
        currencyCode: 'JPY',
        paymentMethod: 'Cash',
      );
      final map = expense.toMap();
      expect(map['is_reversed'], 0);
      expect(map['reversed_at'], isNull);
    });

    test('fromMap reads is_reversed=1 correctly', () {
      final now = DateTime.utc(2026, 6, 10, 12, 0, 0);
      final expense = Expense.create(
        id: 'exp-rev',
        tripId: 'trip-x',
        title: 'Reversed',
        amount: 100,
        currencyCode: 'JPY',
        paymentMethod: 'Cash',
      );
      final map = expense.toMap()
        ..['is_reversed'] = 1
        ..['reversed_at'] = now.toIso8601String();

      final loaded = Expense.fromMap(map);
      expect(loaded.isReversed, isTrue);
      expect(loaded.reversedAt, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ExpenseRefund — returnedLotId exposed
  // ---------------------------------------------------------------------------

  group('ExpenseRefund returnedLotId', () {
    test('card refund has null returnedLotId', () async {
      final refund = await refundRepository.createCardRefund(
        tripId: testTrip.id,
        amount: 200,
        currencyCode: 'JPY',
      );
      expect(refund.returnedLotId, isNull);
    });

    test('toMap includes returned_lot_id when set', () {
      final refund = ExpenseRefund.create(
        id: 'ref-lot',
        tripId: 'trip-x',
        amount: 500,
        currencyCode: 'JPY',
        destination: RefundDestination.card,
        returnedLotId: 'lot-xyz',
      );
      expect(refund.toMap()['returned_lot_id'], 'lot-xyz');
    });

    test('fromMap reads returned_lot_id', () {
      final refund = ExpenseRefund.create(
        id: 'ref-map',
        tripId: 'trip-x',
        amount: 500,
        currencyCode: 'JPY',
        destination: RefundDestination.card,
      );
      final map = refund.toMap()..['returned_lot_id'] = 'lot-abc';
      final loaded = ExpenseRefund.fromMap(map);
      expect(loaded.returnedLotId, 'lot-abc');
    });
  });
}

