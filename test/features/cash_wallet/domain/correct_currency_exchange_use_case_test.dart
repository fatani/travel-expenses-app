import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/correct_currency_exchange_use_case.dart';
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
  late CorrectCurrencyExchangeUseCase correctExchange;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'correct_exchange');
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
    final correctionService = ExchangeCorrectionService(
      exchangeRepository: exchangeRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      expenseRepository: expenseRepo,
    );
    final reverseExchange = ReverseCurrencyExchangeUseCase(
      appDatabase: db,
      correctionService: correctionService,
      exchangeRepository: exchangeRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      cashWalletRepository: walletRepo,
    );
    correctExchange = CorrectCurrencyExchangeUseCase(
      appDatabase: db,
      reverseUseCase: reverseExchange,
      recordUseCase: recordExchange,
    );

    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-cor',
        name: 'Correct Trip',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

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

  Future<CurrencyExchangeResult> exchange({
    double from = 100,
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

  // ── 6. Correct unused exchange ─────────────────────────────────────────────

  group('6 — correct unused exchange', () {
    test('original reversed, corrected created, final balances = corrected only',
        () async {
      // Start: JPY 100. Original: 100 JPY -> 720 CNY. Correct to 700 CNY.
      await addJpy(100, homeAmount: 27);
      final original = await exchange(from: 100, to: 720);

      expect(await balanceOf('JPY'), closeTo(0, 1e-6));
      expect(await balanceOf('CNY'), closeTo(720, 1e-6));

      final corrected = await correctExchange.execute(
        originalExchangeId: original.exchange.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 100,
        toCurrencyCode: 'CNY',
        toAmount: 700,
      );

      // Original is reversed.
      final originalRow =
          await exchangeRepo.getExchangeById(original.exchange.id);
      expect(originalRow!.isReversed, isTrue);

      // Corrected is active and distinct.
      expect(corrected.exchange.id, isNot(original.exchange.id));
      final correctedRow =
          await exchangeRepo.getExchangeById(corrected.exchange.id);
      expect(correctedRow!.isReversed, isFalse);
      expect(correctedRow.toAmount, closeTo(700, 1e-6));

      // Final balances reflect only the corrected exchange.
      expect(await balanceOf('JPY'), closeTo(0, 1e-6));
      expect(await balanceOf('CNY'), closeTo(700, 1e-6));

      // Only one active CNY exchange-in lot remains.
      final cnyLots = await lotRepo.getOpenLotsForCurrency(trip.id, 'CNY');
      expect(cnyLots, hasLength(1));
      expect(cnyLots.first.originalAmount, closeTo(700, 1e-6));
    });

    test('correcting the gave amount re-plans source FIFO', () async {
      await addJpy(100, homeAmount: 27);
      final original = await exchange(from: 100, to: 720);

      // Correct down to 80 JPY -> 700 CNY; 20 JPY returns to the wallet.
      final corrected = await correctExchange.execute(
        originalExchangeId: original.exchange.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 80,
        toCurrencyCode: 'CNY',
        toAmount: 700,
      );

      expect(await balanceOf('JPY'), closeTo(20, 1e-6));
      expect(await balanceOf('CNY'), closeTo(700, 1e-6));
      expect(corrected.exchange.fromAmount, closeTo(80, 1e-6));
    });
  });

  // ── 8. Failed correction rolls back reverse ────────────────────────────────

  group('8 — failed correction rolls back reverse', () {
    test(
        'record-step failure leaves original exchange active and balances unchanged',
        () async {
      // Spec scenario: USD 100 → 720 CNY, then a correction that fails after
      // the reverse step begins (same-currency corrected values).
      final usdTrip = await tripRepo.createTrip(
        Trip.create(
          id: 'trip-cor-rollback',
          name: 'Rollback Trip',
          destination: 'China',
          baseCurrency: 'USD',
          destinationCurrency: 'USD',
          homeCurrencySnapshot: 'SAR',
        ),
      );
      await walletRepo.addCashTransaction(
        tripId: usdTrip.id,
        type: CashTransactionType.initialCash,
        amount: 100,
        currencyCode: 'USD',
        homeCurrencyAmount: 375,
        homeCurrencyCode: 'SAR',
      );
      final original = await recordExchange.execute(
        tripId: usdTrip.id,
        fromCurrencyCode: 'USD',
        fromAmount: 100,
        toCurrencyCode: 'CNY',
        toAmount: 720,
      );

      final preCorrectionBalances = await walletRepo.getBalancesByTrip(usdTrip.id);
      double preUsd = 0;
      double preCny = 0;
      for (final b in preCorrectionBalances) {
        if (b.currencyCode == 'USD') preUsd = b.balanceAmount;
        if (b.currencyCode == 'CNY') preCny = b.balanceAmount;
      }
      expect(preUsd, closeTo(0, 1e-6));
      expect(preCny, closeTo(720, 1e-6));

      final exchangesBefore =
          await exchangeRepo.getExchangesByTripId(usdTrip.id);

      await expectLater(
        correctExchange.execute(
          originalExchangeId: original.exchange.id,
          fromCurrencyCode: 'USD',
          fromAmount: 100,
          toCurrencyCode: 'USD',
          toAmount: 720,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Original exchange still active — not half-reversed.
      final originalRow =
          await exchangeRepo.getExchangeById(original.exchange.id);
      expect(originalRow!.isReversed, isFalse);
      expect(originalRow.reversedAt, isNull);

      // Balances unchanged from the pre-correction state.
      final usdBalances = await walletRepo.getBalancesByTrip(usdTrip.id);
      double usdBalance = 0;
      double cnyBalance = 0;
      for (final b in usdBalances) {
        if (b.currencyCode == 'USD') usdBalance = b.balanceAmount;
        if (b.currencyCode == 'CNY') cnyBalance = b.balanceAmount;
      }
      expect(usdBalance, closeTo(0, 1e-6));
      expect(cnyBalance, closeTo(720, 1e-6));

      // Destination lot still active with full received amount.
      final destLot =
          await lotRepo.getCashLotById(original.destinationLot.id);
      expect(destLot!.isReversed, isFalse);
      expect(destLot.remainingAmount, closeTo(720, 1e-6));

      // Source consumptions still active.
      final activeConsumptions =
          await consumptionRepo.getActiveConsumptionsByExchangeId(
        original.exchange.id,
      );
      expect(activeConsumptions, isNotEmpty);
      expect(
        activeConsumptions.every((c) => c.isReversed == false),
        isTrue,
      );

      // No corrected exchange appended.
      final exchangesAfter =
          await exchangeRepo.getExchangesByTripId(usdTrip.id);
      expect(exchangesAfter.length, exchangesBefore.length);
    });
  });

  // ── 7. Correct blocked when destination consumed ──────────────────────────

  group('7 — correct blocked when destination consumed', () {
    test('no new exchange created, original remains active', () async {
      await addJpy(100, homeAmount: 27);
      final original = await exchange(from: 100, to: 720);

      // Spend some received CNY → destination lot consumed.
      await recordCashExpense.execute(
        Expense.create(
          tripId: trip.id,
          title: 'Snack',
          amount: 20,
          currencyCode: 'CNY',
          transactionAmount: 20,
          transactionCurrency: 'CNY',
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Food',
        ),
      );

      final exchangesBefore =
          await exchangeRepo.getExchangesByTripId(trip.id);

      await expectLater(
        correctExchange.execute(
          originalExchangeId: original.exchange.id,
          fromCurrencyCode: 'JPY',
          fromAmount: 100,
          toCurrencyCode: 'CNY',
          toAmount: 700,
        ),
        throwsA(isA<ExchangeNotCorrectableException>().having(
          (e) => e.reason,
          'reason',
          ExchangeCorrectionReason.destinationCashUsed,
        )),
      );

      // Original still active, no corrected exchange appended.
      final originalRow =
          await exchangeRepo.getExchangeById(original.exchange.id);
      expect(originalRow!.isReversed, isFalse);
      final exchangesAfter = await exchangeRepo.getExchangesByTripId(trip.id);
      expect(exchangesAfter.length, exchangesBefore.length);
    });
  });
}
