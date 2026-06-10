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
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
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
  late RecordCurrencyExchangeUseCase useCase;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'record_currency_exchange');
    tripRepo = TripRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    consumptionRepo = CashLotConsumptionRepository(db);
    exchangeRepo = CurrencyExchangeRepository(db);

    final fifoEngine = CashLotFifoEngine(lotRepo);
    final exchangeEngine = CurrencyExchangeEngine(fifoEngine);

    useCase = RecordCurrencyExchangeUseCase(
      appDatabase: db,
      exchangeEngine: exchangeEngine,
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      exchangeRepository: exchangeRepo,
    );

    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-exchange',
        name: 'Exchange Trip',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  // Helper: insert a source JPY lot with given amount and cost basis
  Future<CashLot> insertJpyLot({
    required double amount,
    double? homeCurrencyAmount,
    String homeCurrencyCode = 'SAR',
    DateTime? createdAt,
  }) async {
    final effectiveRate = (homeCurrencyAmount != null && amount > 0)
        ? homeCurrencyAmount / amount
        : null;
    return lotRepo.insertCashLot(
      CashLot.create(
        tripId: trip.id,
        sourceType: 'atm_withdrawal',
        sourceRefType: 'cash_transaction',
        sourceRefId: 'tx-placeholder',
        currencyCode: 'JPY',
        originalAmount: amount,
        remainingAmount: amount,
        homeCurrencyAmount: homeCurrencyAmount,
        homeCurrencyCode: homeCurrencyAmount != null ? homeCurrencyCode : null,
        effectiveRate: effectiveRate,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  // Helper: seed the trip_cash_balances for JPY
  Future<void> seedJpyBalance(double amount) async {
    final rawDb = await db.database;
    await rawDb.insert('trip_cash_balances', {
      'trip_id': trip.id,
      'currency_code': 'JPY',
      'balance_amount': amount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ─── 1. Exchange consumes single source lot ────────────────────────────────

  group('1 — consumes single source lot', () {
    test('source lot remaining_amount decreases by fromAmount', () async {
      final lot = await insertJpyLot(amount: 10000, homeCurrencyAmount: 270);
      await seedJpyBalance(10000);

      await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      final updated = await lotRepo.getCashLotById(lot.id);
      expect(updated!.remainingAmount, closeTo(5000, 1e-4));
    });

    test('single consumption record created', () async {
      final lot = await insertJpyLot(amount: 10000, homeCurrencyAmount: 270);
      await seedJpyBalance(10000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      expect(result.consumptions, hasLength(1));
      expect(result.consumptions.first.lotId, lot.id);
      expect(result.consumptions.first.consumedAmount, closeTo(5000, 1e-6));
    });
  });

  // ─── 2. Exchange consumes multiple source lots FIFO ────────────────────────

  group('2 — consumes multiple lots FIFO', () {
    test('older lots consumed first', () async {
      final t0 = DateTime(2024, 1, 1);
      final t1 = DateTime(2024, 1, 2);
      final lot1 = await insertJpyLot(amount: 3000, homeCurrencyAmount: 81, createdAt: t0);
      final lot2 = await insertJpyLot(amount: 5000, homeCurrencyAmount: 135, createdAt: t1);
      await seedJpyBalance(8000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 4000,
        toCurrencyCode: 'USD',
        toAmount: 26.67,
      );

      expect(result.consumptions, hasLength(2));
      expect(result.consumptions[0].lotId, lot1.id);
      expect(result.consumptions[0].consumedAmount, closeTo(3000, 1e-6));
      expect(result.consumptions[1].lotId, lot2.id);
      expect(result.consumptions[1].consumedAmount, closeTo(1000, 1e-6));
    });

    test('lot1 fully consumed, lot2 partially consumed', () async {
      final t0 = DateTime(2024, 1, 1);
      final t1 = DateTime(2024, 1, 2);
      final lot1 = await insertJpyLot(amount: 3000, homeCurrencyAmount: 81, createdAt: t0);
      final lot2 = await insertJpyLot(amount: 5000, homeCurrencyAmount: 135, createdAt: t1);
      await seedJpyBalance(8000);

      await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 4000,
        toCurrencyCode: 'USD',
        toAmount: 26.67,
      );

      final updated1 = await lotRepo.getCashLotById(lot1.id);
      final updated2 = await lotRepo.getCashLotById(lot2.id);
      expect(updated1!.remainingAmount, closeTo(0, 1e-6));
      expect(updated1.isFullyConsumed, isTrue);
      expect(updated2!.remainingAmount, closeTo(4000, 1e-4));
    });
  });

  // ─── 3. Destination lot created with transferred cost basis ────────────────

  group('3 — destination lot cost basis', () {
    test('destLot.homeCurrencyAmount = sum of consumed homeAmounts', () async {
      // 5000 JPY lot @ 270 SAR → effectiveRate = 0.054
      // Exchange 5000 JPY → USD → transferred = 270 SAR
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      expect(result.destinationLot.homeCurrencyAmount, closeTo(270, 1e-6));
      expect(result.destinationLot.homeCurrencyCode, 'SAR');
    });

    test('cost basis transfers from two lots correctly', () async {
      // lot1: 3000 JPY @ 81 SAR; lot2: 5000 JPY @ 135 SAR
      // Exchange 4000 JPY: consume 3000 fully (81 SAR) + 1000 from lot2 (135*1000/5000=27 SAR)
      // transferred = 81 + 27 = 108 SAR
      final t0 = DateTime(2024, 1, 1);
      final t1 = DateTime(2024, 1, 2);
      await insertJpyLot(amount: 3000, homeCurrencyAmount: 81, createdAt: t0);
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 135, createdAt: t1);
      await seedJpyBalance(8000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 4000,
        toCurrencyCode: 'USD',
        toAmount: 26.67,
      );

      // 81 + 27 = 108 SAR transferred
      expect(result.destinationLot.homeCurrencyAmount, closeTo(108, 1e-4));
    });
  });

  // ─── 4. Destination effective rate ────────────────────────────────────────

  group('4 — destination effective rate', () {
    test('effectiveRate = transferredHomeAmount / toAmount', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      // 270 / 33.33 ≈ 8.1
      final expectedRate = 270.0 / 33.33;
      expect(result.destinationLot.effectiveRate, closeTo(expectedRate, 1e-6));
    });
  });

  // ─── 5. currency_exchanges row created ────────────────────────────────────

  group('5 — currency_exchanges row', () {
    test('exchange row persisted with correct fields', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      final saved = await exchangeRepo.getExchangeById(result.exchange.id);
      expect(saved, isNotNull);
      expect(saved!.fromCurrencyCode, 'JPY');
      expect(saved.fromAmount, closeTo(5000, 1e-6));
      expect(saved.toCurrencyCode, 'USD');
      expect(saved.toAmount, closeTo(33.33, 1e-6));
      expect(saved.tripId, trip.id);
    });
  });

  // ─── 6. currency_exchanges.to_lot_id points to destination lot ───────────

  group('6 — exchange.toLotId', () {
    test('exchange.toLotId == destinationLot.id', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      expect(result.exchange.toLotId, result.destinationLot.id);
    });
  });

  // ─── 7. destination lot source_ref_type = 'currency_exchange' ────────────

  group('7 — destination lot source_ref_type', () {
    test("sourceRefType == 'currency_exchange'", () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      expect(result.destinationLot.sourceRefType, 'currency_exchange');
    });
  });

  // ─── 8. destination lot source_ref_id = exchange.id ──────────────────────

  group('8 — destination lot source_ref_id', () {
    test('sourceRefId == exchange.id', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      expect(result.destinationLot.sourceRefId, result.exchange.id);
    });

    test('source_ref_id persisted to DB', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      final dbLot = await lotRepo.getCashLotById(result.destinationLot.id);
      expect(dbLot!.sourceRefId, result.exchange.id);
    });
  });

  // ─── 9. cash_lot_consumptions created for each source lot ────────────────

  group('9 — consumption records', () {
    test('consumptions persisted and linked to exchange', () async {
      final t0 = DateTime(2024, 1, 1);
      final t1 = DateTime(2024, 1, 2);
      await insertJpyLot(amount: 3000, homeCurrencyAmount: 81, createdAt: t0);
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 135, createdAt: t1);
      await seedJpyBalance(8000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 4000,
        toCurrencyCode: 'USD',
        toAmount: 26.67,
      );

      final dbConsumptions =
          await consumptionRepo.getConsumptionsByExchangeId(result.exchange.id);
      expect(dbConsumptions, hasLength(2));
      for (final c in dbConsumptions) {
        expect(c.exchangeId, result.exchange.id);
        expect(c.consumptionType, 'exchange_out');
      }
    });
  });

  // ─── 10. source lots remaining amounts updated ───────────────────────────

  group('10 — source lot remaining amounts', () {
    test('fully consumed lot has remainingAmount = 0 and isFullyConsumed = true',
        () async {
      final lot = await insertJpyLot(amount: 5000, homeCurrencyAmount: 135);
      await seedJpyBalance(5000);

      await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      final updated = await lotRepo.getCashLotById(lot.id);
      expect(updated!.remainingAmount, closeTo(0, 1e-6));
      expect(updated.isFullyConsumed, isTrue);
    });

    test('partially consumed lot has reduced remainingAmount', () async {
      final lot = await insertJpyLot(amount: 10000, homeCurrencyAmount: 270);
      await seedJpyBalance(10000);

      await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 3000,
        toCurrencyCode: 'USD',
        toAmount: 20,
      );

      final updated = await lotRepo.getCashLotById(lot.id);
      expect(updated!.remainingAmount, closeTo(7000, 1e-4));
      expect(updated.isFullyConsumed, isFalse);
    });
  });

  // ─── 11. exchange_out cash_transaction created ───────────────────────────

  group('11 — exchange_out transaction', () {
    test('exchange_out row created with correct type and currency', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      expect(result.exchangeOutTransaction.type,
          CashTransactionType.currencyExchangeOut);
      expect(result.exchangeOutTransaction.currencyCode, 'JPY');
      expect(result.exchangeOutTransaction.amount, closeTo(5000, 1e-6));
    });
  });

  // ─── 12. exchange_in cash_transaction linked to destination lot ───────────

  group('12 — exchange_in transaction', () {
    test('exchange_in type, currency, and lotId correct', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      expect(result.exchangeInTransaction.type,
          CashTransactionType.currencyExchangeIn);
      expect(result.exchangeInTransaction.currencyCode, 'USD');
      expect(result.exchangeInTransaction.amount, closeTo(33.33, 1e-6));
      expect(result.exchangeInTransaction.lotId, result.destinationLot.id);
    });
  });

  // ─── 13. trip_cash_balances updated correctly ─────────────────────────────

  group('13 — trip_cash_balances', () {
    test('source currency decreases by fromAmount', () async {
      await insertJpyLot(amount: 10000, homeCurrencyAmount: 270);
      await seedJpyBalance(10000);

      await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      final jpy = balances.firstWhere((b) => b.currencyCode == 'JPY');
      expect(jpy.balanceAmount, closeTo(5000, 1e-4));
    });

    test('destination currency increases by toAmount', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      final usd = balances.firstWhere((b) => b.currencyCode == 'USD');
      expect(usd.balanceAmount, closeTo(33.33, 1e-4));
    });
  });

  // ─── 14. Same currency rejected ───────────────────────────────────────────

  group('14 — same currency rejected', () {
    test('JPY→JPY throws ArgumentError', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      expect(
        () => useCase.execute(
          tripId: trip.id,
          fromCurrencyCode: 'JPY',
          fromAmount: 5000,
          toCurrencyCode: 'JPY',
          toAmount: 5000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ─── 15. Insufficient source balance rejected ─────────────────────────────

  group('15 — insufficient balance rejected', () {
    test('throws when fromAmount exceeds available lots', () async {
      await insertJpyLot(amount: 1000, homeCurrencyAmount: 27);
      await seedJpyBalance(1000);

      expect(
        () => useCase.execute(
          tripId: trip.id,
          fromCurrencyCode: 'JPY',
          fromAmount: 5000, // more than available
          toCurrencyCode: 'USD',
          toAmount: 33.33,
        ),
        throwsA(anything), // InsufficientCashException
      );
    });

    test('no DB writes on insufficient balance', () async {
      await insertJpyLot(amount: 1000, homeCurrencyAmount: 27);
      await seedJpyBalance(1000);

      try {
        await useCase.execute(
          tripId: trip.id,
          fromCurrencyCode: 'JPY',
          fromAmount: 5000,
          toCurrencyCode: 'USD',
          toAmount: 33.33,
        );
      } catch (_) {}

      final exchanges = await exchangeRepo.getExchangesByTripId(trip.id);
      expect(exchanges, isEmpty);

      final usdLots = await lotRepo.getOpenLotsForCurrency(trip.id, 'USD');
      expect(usdLots, isEmpty);
    });
  });

  // ─── 16. Null source cost basis → destination lot without cost basis ───────

  group('16 — null source cost basis', () {
    test('destination lot has null homeCurrencyAmount when source lot has none',
        () async {
      // Lot with no cost basis
      await lotRepo.insertCashLot(
        CashLot.create(
          tripId: trip.id,
          sourceType: 'atm_withdrawal',
          sourceRefType: 'cash_transaction',
          sourceRefId: 'tx-no-basis',
          currencyCode: 'JPY',
          originalAmount: 5000,
          remainingAmount: 5000,
          // no homeCurrencyAmount / homeCurrencyCode / effectiveRate
        ),
      );
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 33.33,
      );

      expect(result.destinationLot.homeCurrencyAmount, isNull);
      expect(result.destinationLot.homeCurrencyCode, isNull);
      expect(result.destinationLot.effectiveRate, isNull);
    });
  });

  // ─── 17. Atomic rollback on failure ──────────────────────────────────────

  group('17 — atomic rollback', () {
    test('no exchange row after same-currency ArgumentError', () async {
      await insertJpyLot(amount: 5000, homeCurrencyAmount: 270);
      await seedJpyBalance(5000);

      try {
        await useCase.execute(
          tripId: trip.id,
          fromCurrencyCode: 'JPY',
          fromAmount: 5000,
          toCurrencyCode: 'JPY', // same → error
          toAmount: 5000,
        );
      } on ArgumentError {/* expected */}

      final exchanges = await exchangeRepo.getExchangesByTripId(trip.id);
      expect(exchanges, isEmpty);
    });

    test('no destination lot after validation error', () async {
      try {
        await useCase.execute(
          tripId: trip.id,
          fromCurrencyCode: 'JPY',
          fromAmount: -1, // invalid
          toCurrencyCode: 'USD',
          toAmount: 10,
        );
      } on ArgumentError {/* expected */}

      final usdLots = await lotRepo.getOpenLotsForCurrency(trip.id, 'USD');
      expect(usdLots, isEmpty);
    });

    test('source lot remaining amount unchanged after insufficient error',
        () async {
      final lot = await insertJpyLot(amount: 1000, homeCurrencyAmount: 27);
      await seedJpyBalance(1000);

      try {
        await useCase.execute(
          tripId: trip.id,
          fromCurrencyCode: 'JPY',
          fromAmount: 5000,
          toCurrencyCode: 'USD',
          toAmount: 33,
        );
      } catch (_) {}

      final unchanged = await lotRepo.getCashLotById(lot.id);
      expect(unchanged!.remainingAmount, closeTo(1000, 1e-6));
    });
  });

  // ─── 18. Spot exchange rate does not affect cost basis ────────────────────

  group('18 — spot rate does not affect cost basis', () {
    test(
        'destination lot cost basis equals transferred home amount, '
        'not spot-rate-derived value', () async {
      // Source: 5000 JPY @ 270 SAR cost → rate = 0.054 SAR/JPY
      // Exchange: 5000 JPY → 40 USD (spot = 5000/40 = 125 JPY/USD)
      // If we used spot rate: cost = 40 * (270/5000) = 2.16 — same as FIFO
      // But if someone used (toAmount * spot_exchange_rate * some factor)
      // it would be different.  We assert the value is exactly the transferred
      // home amount from FIFO, not computed from toAmount * spot_rate.
      //
      // Spot-derived value would be: 40 * (270/5000) = 2.16 → correct, they
      // happen to coincide in simple cases.  Use a two-lot scenario to make
      // the distinction clear.

      // lot1: 3000 JPY @ 90 SAR (rate=0.030)
      // lot2: 2000 JPY @ 100 SAR (rate=0.050)
      // Exchange 5000 JPY → 40 USD (spot = 5000/40 = 125 JPY/USD)
      // FIFO transferred basis = 90 + 100 = 190 SAR
      // Spot-derived would be: 40 * (avg_rate?) — not what we store
      final t0 = DateTime(2024, 1, 1);
      final t1 = DateTime(2024, 1, 2);
      await insertJpyLot(amount: 3000, homeCurrencyAmount: 90, createdAt: t0);
      await insertJpyLot(amount: 2000, homeCurrencyAmount: 100, createdAt: t1);
      await seedJpyBalance(5000);

      final result = await useCase.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'USD',
        toAmount: 40,
      );

      // Cost basis = 90 + 100 = 190 SAR (FIFO transfer, not spot revaluation)
      expect(result.destinationLot.homeCurrencyAmount, closeTo(190, 1e-6));
      // Spot rate stored correctly in exchange row
      expect(result.exchange.exchangeRate, closeTo(40.0 / 5000.0, 1e-9));
      // Effective rate for destination = 190 / 40 = 4.75 SAR/USD
      expect(result.destinationLot.effectiveRate, closeTo(4.75, 1e-9));
    });
  });
}
