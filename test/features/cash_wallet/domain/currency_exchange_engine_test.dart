import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/insufficient_cash_exception.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CashLotRepository lotRepo;
  late CurrencyExchangeEngine engine;
  late String tripId;

  var seq = 0;
  String nextId([String prefix = 'lot']) => '$prefix-${++seq}';

  setUp(() async {
    seq = 0;
    final db = createIsolatedAppDatabase(prefix: 'exchange_engine');
    lotRepo = CashLotRepository(db);
    final fifoEngine = CashLotFifoEngine(lotRepo);
    engine = CurrencyExchangeEngine(fifoEngine);

    final tripRepo = TripRepository(db);
    final trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-ex',
        name: 'Exchange Test',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
    tripId = trip.id;
  });

  // ---------------------------------------------------------------------------
  // Helper — insert a source lot for fromCurrency
  // ---------------------------------------------------------------------------

  Future<CashLot> insertSourceLot({
    required double amount,
    required String currency,
    double? rate,
    String? homeCode,
    String? id,
    DateTime? createdAt,
  }) async {
    final lot = CashLot.create(
      id: id ?? nextId(),
      tripId: tripId,
      sourceType: 'initial_cash',
      sourceRefType: 'cash_transaction',
      sourceRefId: 'tx-${id ?? seq}',
      currencyCode: currency,
      originalAmount: amount,
      remainingAmount: amount,
      homeCurrencyAmount: (rate != null && homeCode != null) ? amount * rate : null,
      homeCurrencyCode: homeCode,
      effectiveRate: rate,
      createdAt: createdAt,
    );
    return lotRepo.insertCashLot(lot);
  }

  // ---------------------------------------------------------------------------
  // 1. Single source lot exchange
  // ---------------------------------------------------------------------------

  group('single source lot exchange', () {
    test('plan has one source entry with correct amounts', () async {
      await insertSourceLot(amount: 1000, currency: 'SAR', rate: 40.0, homeCode: 'SAR');

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'SAR',
        fromAmount: 1000,
        toCurrencyCode: 'JPY',
        toAmount: 40000,
      );

      expect(plan.fromCurrencyCode, 'SAR');
      expect(plan.fromAmount, closeTo(1000, 1e-6));
      expect(plan.toCurrencyCode, 'JPY');
      expect(plan.toAmount, closeTo(40000, 1e-6));
      expect(plan.sourcePlans, hasLength(1));
      expect(plan.sourcePlans.first.consumedAmount, closeTo(1000, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Multi-source lot exchange
  // ---------------------------------------------------------------------------

  group('multi-source lot exchange', () {
    test('plan spans two lots when first is insufficient alone', () async {
      final t0 = DateTime.utc(2026, 1, 1);
      final t1 = DateTime.utc(2026, 1, 2);
      await insertSourceLot(amount: 300, currency: 'SAR', rate: 40.0, homeCode: 'SAR', id: 'lot-a', createdAt: t0);
      await insertSourceLot(amount: 700, currency: 'SAR', rate: 40.0, homeCode: 'SAR', id: 'lot-b', createdAt: t1);

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'SAR',
        fromAmount: 1000,
        toCurrencyCode: 'JPY',
        toAmount: 40000,
      );

      expect(plan.sourcePlans, hasLength(2));
      expect(plan.sourcePlans[0].consumedAmount, closeTo(300, 1e-6));
      expect(plan.sourcePlans[1].consumedAmount, closeTo(700, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Cost basis transfer from multiple lots
  // ---------------------------------------------------------------------------

  group('cost basis transfer from multiple lots', () {
    test('transferredHomeAmount equals sum of per-lot homeAmounts', () async {
      final t0 = DateTime.utc(2026, 2, 1);
      final t1 = DateTime.utc(2026, 2, 2);
      // Lot A: 200 SAR @ 40 JPY/SAR → homeAmount when consuming 200 SAR
      // But wait, the rate here is home/foreign, i.e. SAR per SAR = 1 if same currency.
      // Let's model this properly: source is SAR, home is SAR, effectiveRate=1.
      // Actually let me use EUR→JPY exchange where home is SAR.
      // Lot A: 500 EUR held, bought at 4 SAR/EUR → effectiveRate=4
      // Lot B: 500 EUR held, bought at 4.2 SAR/EUR → effectiveRate=4.2
      await insertSourceLot(amount: 500, currency: 'EUR', rate: 4.0, homeCode: 'SAR', id: 'lot-c', createdAt: t0);
      await insertSourceLot(amount: 500, currency: 'EUR', rate: 4.2, homeCode: 'SAR', id: 'lot-d', createdAt: t1);

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'EUR',
        fromAmount: 1000,
        toCurrencyCode: 'JPY',
        toAmount: 160000,
      );

      // Lot A: 500 × 4.0 = 2000 SAR; Lot B: 500 × 4.2 = 2100 SAR → total 4100 SAR
      expect(plan.transferredHomeAmount, closeTo(4100, 1e-6));
      expect(plan.homeCurrencyCode, 'SAR');
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Source lot with null effectiveRate
  // ---------------------------------------------------------------------------

  group('source lot with null effectiveRate', () {
    test('transferredHomeAmount and destinationEffectiveRate are null', () async {
      await insertSourceLot(amount: 1000, currency: 'SAR'); // no rate/homeCode

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'SAR',
        fromAmount: 1000,
        toCurrencyCode: 'JPY',
        toAmount: 40000,
      );

      expect(plan.transferredHomeAmount, isNull);
      expect(plan.homeCurrencyCode, isNull);
      expect(plan.destinationEffectiveRate, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Mixed null and non-null homeAmount
  // ---------------------------------------------------------------------------

  group('mixed null and non-null homeAmount', () {
    test('sums only the non-null homeAmounts; null lots contribute nothing', () async {
      final t0 = DateTime.utc(2026, 3, 1);
      final t1 = DateTime.utc(2026, 3, 2);
      // First lot has no cost basis
      await insertSourceLot(amount: 400, currency: 'EUR', id: 'lot-nocost', createdAt: t0);
      // Second lot has cost basis: 600 EUR @ 4.5 SAR/EUR → 2700 SAR
      await insertSourceLot(amount: 600, currency: 'EUR', rate: 4.5, homeCode: 'SAR', id: 'lot-withcost', createdAt: t1);

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'EUR',
        fromAmount: 1000,
        toCurrencyCode: 'JPY',
        toAmount: 160000,
      );

      // Only the second lot contributes: 600 × 4.5 = 2700 SAR
      expect(plan.transferredHomeAmount, closeTo(2700, 1e-6));
      expect(plan.homeCurrencyCode, 'SAR');
      // destinationEffectiveRate = 2700 / 160000
      expect(plan.destinationEffectiveRate, closeTo(2700 / 160000, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Same currency rejected
  // ---------------------------------------------------------------------------

  group('same currency rejected', () {
    test('throws ArgumentError when fromCurrency == toCurrency', () {
      expect(
        () => engine.planExchange(
          tripId: tripId,
          fromCurrencyCode: 'JPY',
          fromAmount: 1000,
          toCurrencyCode: 'JPY',
          toAmount: 1000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('case-insensitive comparison: "jpy" == "JPY" is rejected', () {
      expect(
        () => engine.planExchange(
          tripId: tripId,
          fromCurrencyCode: 'jpy',
          fromAmount: 1000,
          toCurrencyCode: 'JPY',
          toAmount: 1000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Zero / negative fromAmount rejected
  // ---------------------------------------------------------------------------

  group('zero or negative fromAmount rejected', () {
    test('throws ArgumentError when fromAmount == 0', () {
      expect(
        () => engine.planExchange(
          tripId: tripId,
          fromCurrencyCode: 'SAR',
          fromAmount: 0,
          toCurrencyCode: 'JPY',
          toAmount: 1000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when fromAmount < 0', () {
      expect(
        () => engine.planExchange(
          tripId: tripId,
          fromCurrencyCode: 'SAR',
          fromAmount: -500,
          toCurrencyCode: 'JPY',
          toAmount: 1000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Zero / negative toAmount rejected
  // ---------------------------------------------------------------------------

  group('zero or negative toAmount rejected', () {
    test('throws ArgumentError when toAmount == 0', () {
      expect(
        () => engine.planExchange(
          tripId: tripId,
          fromCurrencyCode: 'SAR',
          fromAmount: 100,
          toCurrencyCode: 'JPY',
          toAmount: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when toAmount < 0', () {
      expect(
        () => engine.planExchange(
          tripId: tripId,
          fromCurrencyCode: 'SAR',
          fromAmount: 100,
          toCurrencyCode: 'JPY',
          toAmount: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Insufficient source balance
  // ---------------------------------------------------------------------------

  group('insufficient source balance', () {
    test('propagates InsufficientCashException from FIFO engine', () async {
      await insertSourceLot(amount: 500, currency: 'SAR');

      expect(
        () => engine.planExchange(
          tripId: tripId,
          fromCurrencyCode: 'SAR',
          fromAmount: 1000,
          toCurrencyCode: 'JPY',
          toAmount: 40000,
        ),
        throwsA(
          isA<InsufficientCashException>()
              .having((e) => e.available, 'available', closeTo(500, 1e-6))
              .having((e) => e.required, 'required', closeTo(1000, 1e-6))
              .having((e) => e.currencyCode, 'currencyCode', 'SAR'),
        ),
      );
    });

    test('throws InsufficientCashException when no lots exist for currency', () {
      expect(
        () => engine.planExchange(
          tripId: tripId,
          fromCurrencyCode: 'USD',
          fromAmount: 100,
          toCurrencyCode: 'JPY',
          toAmount: 15000,
        ),
        throwsA(isA<InsufficientCashException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 10. exchangeRate calculation
  // ---------------------------------------------------------------------------

  group('exchangeRate calculation', () {
    test('exchangeRate == toAmount / fromAmount', () async {
      await insertSourceLot(amount: 250, currency: 'SAR');

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'SAR',
        fromAmount: 250,
        toCurrencyCode: 'JPY',
        toAmount: 10000,
      );

      expect(plan.exchangeRate, closeTo(10000 / 250, 1e-9));
    });

    test('exchangeRate for fractional amounts', () async {
      await insertSourceLot(amount: 1, currency: 'SAR');

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'SAR',
        fromAmount: 1,
        toCurrencyCode: 'JPY',
        toAmount: 39.87,
      );

      expect(plan.exchangeRate, closeTo(39.87, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // 11. destinationEffectiveRate calculation
  // ---------------------------------------------------------------------------

  group('destinationEffectiveRate calculation', () {
    test('destinationEffectiveRate == transferredHomeAmount / toAmount', () async {
      // 1000 SAR @ 1.0 SAR/SAR (trivial: home = source) → 40000 JPY
      await insertSourceLot(amount: 1000, currency: 'SAR', rate: 1.0, homeCode: 'SAR');

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'SAR',
        fromAmount: 1000,
        toCurrencyCode: 'JPY',
        toAmount: 40000,
      );

      // transferredHomeAmount = 1000 * 1.0 = 1000 SAR
      expect(plan.transferredHomeAmount, closeTo(1000, 1e-6));
      // destinationEffectiveRate = 1000 / 40000 = 0.025 SAR/JPY
      expect(plan.destinationEffectiveRate, closeTo(0.025, 1e-9));
    });

    test('destinationEffectiveRate is null when no source lots have a cost basis', () async {
      await insertSourceLot(amount: 500, currency: 'SAR'); // no rate

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'SAR',
        fromAmount: 500,
        toCurrencyCode: 'JPY',
        toAmount: 20000,
      );

      expect(plan.destinationEffectiveRate, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 12. No revaluation: destination cost basis == consumed source cost basis
  // ---------------------------------------------------------------------------

  group('no revaluation — cost basis preserved exactly', () {
    test('destination cost basis equals sum of source homeAmounts exactly', () async {
      // Two EUR lots with different rates; exchange 1000 EUR → 160000 JPY
      final t0 = DateTime.utc(2026, 4, 1);
      final t1 = DateTime.utc(2026, 4, 2);
      await insertSourceLot(
        amount: 600, currency: 'EUR', rate: 4.2, homeCode: 'SAR',
        id: 'lot-p', createdAt: t0,
      );
      await insertSourceLot(
        amount: 400, currency: 'EUR', rate: 3.8, homeCode: 'SAR',
        id: 'lot-q', createdAt: t1,
      );

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'EUR',
        fromAmount: 1000,
        toCurrencyCode: 'JPY',
        toAmount: 160000,
      );

      // Source cost: 600×4.2 + 400×3.8 = 2520 + 1520 = 4040 SAR
      const expectedSourceCost = 600 * 4.2 + 400 * 3.8;
      expect(plan.transferredHomeAmount, closeTo(expectedSourceCost, 1e-6));

      // Destination cost basis = transferredHomeAmount (no revaluation)
      final reconstituted =
          (plan.destinationEffectiveRate ?? 0) * plan.toAmount;
      expect(reconstituted, closeTo(expectedSourceCost, 1e-6));

      // The market rate (exchangeRate) must differ from the cost rate to
      // confirm we are NOT using it for the basis.
      // marketRate = 160000/1000 = 160 JPY/EUR
      // costRate = 4040/160000 SAR/JPY ≠ marketRate
      expect(plan.exchangeRate, closeTo(160.0, 1e-9));
      expect(plan.destinationEffectiveRate,
          isNot(closeTo(plan.exchangeRate, 1e-3)));
    });

    test('partial basis: destination basis reflects only lots with known cost', () async {
      final t0 = DateTime.utc(2026, 5, 1);
      final t1 = DateTime.utc(2026, 5, 2);
      // First 500 EUR: unknown cost basis
      await insertSourceLot(amount: 500, currency: 'EUR', id: 'lot-nk', createdAt: t0);
      // Next 500 EUR: bought at 4.0 SAR/EUR
      await insertSourceLot(
        amount: 500, currency: 'EUR', rate: 4.0, homeCode: 'SAR',
        id: 'lot-kn', createdAt: t1,
      );

      final plan = await engine.planExchange(
        tripId: tripId,
        fromCurrencyCode: 'EUR',
        fromAmount: 1000,
        toCurrencyCode: 'JPY',
        toAmount: 160000,
      );

      // Only 500 × 4.0 = 2000 SAR is known
      expect(plan.transferredHomeAmount, closeTo(2000, 1e-6));
      // destinationEffectiveRate = 2000 / 160000
      expect(plan.destinationEffectiveRate, closeTo(2000 / 160000, 1e-9));
    });
  });
}
