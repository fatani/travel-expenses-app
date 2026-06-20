import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_result.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_correction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_correction_service.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_not_correctable_exception.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/reverse_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';
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
  late CashLotConsumptionRepository consumptionRepo;
  late CurrencyExchangeRepository exchangeRepo;
  late ExpenseRepository expenseRepo;
  late RecordCurrencyExchangeUseCase recordExchange;
  late RecordCashExpenseUseCase recordCashExpense;
  late ReverseCurrencyExchangeUseCase reverseExchange;
  late ExchangeCorrectionService correctionService;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'reverse_exchange');
    tripRepo = TripRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    consumptionRepo = CashLotConsumptionRepository(db);
    exchangeRepo = CurrencyExchangeRepository(db);
    expenseRepo = ExpenseRepository(db);

    final fifo = CashLotFifoEngine(lotRepo);
    final engine = CurrencyExchangeEngine(fifo);
    recordExchange = RecordCurrencyExchangeUseCase(
      appDatabase: db,
      exchangeEngine: engine,
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      exchangeRepository: exchangeRepo,
    );
    recordCashExpense = RecordCashExpenseUseCase(
      appDatabase: db,
      expenseRepository: expenseRepo,
      cashWalletRepository: walletRepo,
      fifoEngine: fifo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
    );
    correctionService = ExchangeCorrectionService(
      exchangeRepository: exchangeRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      expenseRepository: expenseRepo,
    );
    reverseExchange = ReverseCurrencyExchangeUseCase(
      appDatabase: db,
      correctionService: correctionService,
      exchangeRepository: exchangeRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      cashWalletRepository: walletRepo,
    );

    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-rev',
        name: 'Reverse Trip',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  // Adds a real JPY initial-cash inflow (lot + balance) of [amount].
  Future<void> addJpy(double amount, {double? homeAmount}) {
    return walletRepo.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.initialCash,
      amount: amount,
      currencyCode: 'JPY',
      homeCurrencyAmount: homeAmount,
      homeCurrencyCode: homeAmount != null ? 'SAR' : null,
    );
  }

  Future<double> balanceOf(String currency) async {
    final balances = await walletRepo.getBalancesByTrip(trip.id);
    for (final b in balances) {
      if (b.currencyCode == currency) {
        return b.balanceAmount;
      }
    }
    return 0;
  }

  // Exchange 5000 JPY -> 720 CNY (single source lot).
  Future<CurrencyExchangeResult> exchangeJpyToCny({
    double from = 5000,
    double to = 720,
  }) {
    return recordExchange.execute(
      tripId: trip.id,
      fromCurrencyCode: 'JPY',
      fromAmount: from,
      toCurrencyCode: 'CNY',
      toAmount: to,
    );
  }

  // ── 1. Undo unused exchange ────────────────────────────────────────────────

  group('1 — undo unused exchange', () {
    test('restores source, removes destination, reverses everything', () async {
      await addJpy(10000, homeAmount: 270);
      final result = await exchangeJpyToCny();

      // Sanity: post-exchange state.
      expect(await balanceOf('JPY'), closeTo(5000, 1e-6));
      expect(await balanceOf('CNY'), closeTo(720, 1e-6));

      await reverseExchange.execute(result.exchange.id);

      // Balances behave as if the exchange never happened.
      expect(await balanceOf('JPY'), closeTo(10000, 1e-6));
      expect(await balanceOf('CNY'), closeTo(0, 1e-6));

      // Exchange row reversed.
      final exchange = await exchangeRepo.getExchangeById(result.exchange.id);
      expect(exchange!.isReversed, isTrue);
      expect(exchange.reversedAt, isNotNull);

      // Destination lot reversed.
      final destLot = await lotRepo.getCashLotById(result.destinationLot.id);
      expect(destLot!.isReversed, isTrue);
      expect(destLot.remainingAmount, closeTo(0, 1e-6));

      // Source lot remaining restored.
      final sourceLotId = result.consumptions.first.lotId;
      final sourceLot = await lotRepo.getCashLotById(sourceLotId);
      expect(sourceLot!.remainingAmount, closeTo(10000, 1e-6));
      expect(sourceLot.isFullyConsumed, isFalse);

      // Source consumptions reversed.
      final activeConsumptions =
          await consumptionRepo.getActiveConsumptionsByExchangeId(
        result.exchange.id,
      );
      expect(activeConsumptions, isEmpty);

      // Both exchange cash transactions reversed (excluded from active list).
      final active = await walletRepo.getRecentTransactionsByTrip(
        trip.id,
        limit: 50,
      );
      expect(
        active.where((t) =>
            t.type == CashTransactionType.currencyExchangeIn ||
            t.type == CashTransactionType.currencyExchangeOut),
        isEmpty,
      );
    });
  });

  // ── 2. Undo blocked when destination cash used ─────────────────────────────

  group('2 — undo blocked when destination consumed', () {
    test('typed exception, nothing reversed, balances unchanged', () async {
      await addJpy(10000, homeAmount: 270);
      final result = await exchangeJpyToCny();

      // Spend part of the received CNY with a cash expense → consumes dest lot.
      await recordCashExpense.execute(
        Expense.create(
          tripId: trip.id,
          title: 'Dumplings',
          amount: 100,
          currencyCode: 'CNY',
          transactionAmount: 100,
          transactionCurrency: 'CNY',
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Food',
        ),
      );

      final jpyBefore = await balanceOf('JPY');
      final cnyBefore = await balanceOf('CNY');

      await expectLater(
        reverseExchange.execute(result.exchange.id),
        throwsA(isA<ExchangeNotCorrectableException>().having(
          (e) => e.reason,
          'reason',
          ExchangeCorrectionReason.destinationCashUsed,
        )),
      );

      // Nothing reversed.
      final exchange = await exchangeRepo.getExchangeById(result.exchange.id);
      expect(exchange!.isReversed, isFalse);
      final destLot = await lotRepo.getCashLotById(result.destinationLot.id);
      expect(destLot!.isReversed, isFalse);

      // Balances unchanged by the failed undo.
      expect(await balanceOf('JPY'), closeTo(jpyBefore, 1e-6));
      expect(await balanceOf('CNY'), closeTo(cnyBefore, 1e-6));
    });

    test('correction status surfaces affected transactions', () async {
      await addJpy(10000, homeAmount: 270);
      final result = await exchangeJpyToCny();
      await recordCashExpense.execute(
        Expense.create(
          tripId: trip.id,
          title: 'Tea',
          amount: 50,
          currencyCode: 'CNY',
          transactionAmount: 50,
          transactionCurrency: 'CNY',
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Food',
        ),
      );

      final status = await correctionService.getStatus(result.exchange.id);
      expect(status.canUndo, isFalse);
      expect(status.canCorrect, isFalse);
      expect(status.reasonCode, ExchangeCorrectionReason.destinationCashUsed);
      expect(status.affectedTransactions, isNotEmpty);
      final affected = status.affectedTransactions.first;
      expect(affected.type, AffectedCashUseType.cashExpense);
      expect(affected.currencyCode, 'CNY');
      expect(affected.amount, closeTo(50, 1e-6));
      expect(affected.title, 'Tea');
    });
  });

  // ── 3. Multiple source lots ────────────────────────────────────────────────

  group('3 — multiple source lots', () {
    test('undo restores all source lots correctly', () async {
      final t0 = DateTime.utc(2026, 1, 1);
      final t1 = DateTime.utc(2026, 1, 2);
      // Two JPY lots, oldest-first FIFO.
      await lotRepo.insertCashLot(CashLot.create(
        tripId: trip.id,
        sourceType: 'initial_cash',
        sourceRefType: 'cash_transaction',
        sourceRefId: 'tx-1',
        currencyCode: 'JPY',
        originalAmount: 3000,
        remainingAmount: 3000,
        homeCurrencyAmount: 81,
        homeCurrencyCode: 'SAR',
        effectiveRate: 81 / 3000,
        createdAt: t0,
      ));
      await lotRepo.insertCashLot(CashLot.create(
        tripId: trip.id,
        sourceType: 'initial_cash',
        sourceRefType: 'cash_transaction',
        sourceRefId: 'tx-2',
        currencyCode: 'JPY',
        originalAmount: 5000,
        remainingAmount: 5000,
        homeCurrencyAmount: 135,
        homeCurrencyCode: 'SAR',
        effectiveRate: 135 / 5000,
        createdAt: t1,
      ));
      // Seed balance to match the lots.
      final rawDb = await db.database;
      await rawDb.insert('trip_cash_balances', {
        'trip_id': trip.id,
        'currency_code': 'JPY',
        'balance_amount': 8000,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final result = await exchangeJpyToCny(from: 4000, to: 560);
      expect(result.consumptions, hasLength(2));

      await reverseExchange.execute(result.exchange.id);

      for (final consumption in result.consumptions) {
        final lot = await lotRepo.getCashLotById(consumption.lotId);
        expect(lot!.remainingAmount, closeTo(lot.originalAmount, 1e-6));
        expect(lot.isReversed, isFalse);
      }
      expect(await balanceOf('JPY'), closeTo(8000, 1e-6));
      expect(await balanceOf('CNY'), closeTo(0, 1e-6));
    });
  });

  // ── 4. Null home basis source lot ──────────────────────────────────────────

  group('4 — null home basis', () {
    test('undo remains safe when source lot has no cost basis', () async {
      await lotRepo.insertCashLot(CashLot.create(
        tripId: trip.id,
        sourceType: 'initial_cash',
        sourceRefType: 'cash_transaction',
        sourceRefId: 'tx-nb',
        currencyCode: 'JPY',
        originalAmount: 5000,
        remainingAmount: 5000,
        // no basis
      ));
      final rawDb = await db.database;
      await rawDb.insert('trip_cash_balances', {
        'trip_id': trip.id,
        'currency_code': 'JPY',
        'balance_amount': 5000,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final result = await exchangeJpyToCny(from: 5000, to: 700);
      await reverseExchange.execute(result.exchange.id);

      expect(await balanceOf('JPY'), closeTo(5000, 1e-6));
      expect(await balanceOf('CNY'), closeTo(0, 1e-6));
      final destLot = await lotRepo.getCashLotById(result.destinationLot.id);
      expect(destLot!.isReversed, isTrue);
    });
  });

  // ── 5. Idempotency ─────────────────────────────────────────────────────────

  group('5 — idempotency', () {
    test('reversing an already-reversed exchange does not double-restore',
        () async {
      await addJpy(10000, homeAmount: 270);
      final result = await exchangeJpyToCny();

      await reverseExchange.execute(result.exchange.id);
      expect(await balanceOf('JPY'), closeTo(10000, 1e-6));

      // Second reverse must throw and not mutate balances again.
      await expectLater(
        reverseExchange.execute(result.exchange.id),
        throwsA(isA<ExchangeNotCorrectableException>().having(
          (e) => e.reason,
          'reason',
          ExchangeCorrectionReason.exchangeAlreadyReversed,
        )),
      );
      expect(await balanceOf('JPY'), closeTo(10000, 1e-6));
      expect(await balanceOf('CNY'), closeTo(0, 1e-6));
    });

    test('missing exchange throws not-found', () async {
      await expectLater(
        reverseExchange.execute('no-such-exchange'),
        throwsA(isA<ExchangeNotCorrectableException>().having(
          (e) => e.reason,
          'reason',
          ExchangeCorrectionReason.exchangeNotFound,
        )),
      );
    });
  });
}
