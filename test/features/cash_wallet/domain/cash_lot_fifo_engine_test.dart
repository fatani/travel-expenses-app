import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/insufficient_cash_exception.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CashLotRepository lotRepo;
  late CashLotFifoEngine engine;
  late TripRepository tripRepo;
  late String tripId;

  // Counter to ensure unique IDs within a test without relying on UUIDs.
  var seq = 0;
  String nextId() => 'lot-${++seq}';

  setUp(() async {
    final db = createIsolatedAppDatabase(prefix: 'fifo_engine');
    lotRepo = CashLotRepository(db);
    engine = CashLotFifoEngine(lotRepo);
    tripRepo = TripRepository(db);
    seq = 0;

    final trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-fifo',
        name: 'FIFO Test Trip',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
    tripId = trip.id;
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Insert a lot with [amount] remaining, optional [rate] + [homeCode] for
  /// cost-basis, and optional explicit [id] (for tie-breaker tests).
  Future<CashLot> insertLot({
    required double amount,
    double? rate,
    String? homeCode,
    String? id,
    String currency = 'JPY',
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
  // 1. Single lot — full consumption
  // ---------------------------------------------------------------------------

  group('single lot — full consumption', () {
    test('plan consumes entire lot when required == lot remaining', () async {
      await insertLot(amount: 5000, rate: 0.025, homeCode: 'SAR');

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 5000,
      );

      expect(plans, hasLength(1));
      final plan = plans.first;
      expect(plan.consumedAmount, closeTo(5000, 1e-6));
      expect(plan.remainingAmountAfter, closeTo(0, 1e-6));
      expect(plan.homeAmount, closeTo(125, 1e-6)); // 5000 * 0.025
      expect(plan.homeCurrencyCode, 'SAR');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Exact single lot boundary
  // ---------------------------------------------------------------------------

  group('exact single lot boundary', () {
    test('consuming exactly lot.remaining leaves remainingAmountAfter = 0', () async {
      await insertLot(amount: 1000, rate: 0.03, homeCode: 'SAR');

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 1000,
      );

      expect(plans.first.remainingAmountAfter, closeTo(0, 1e-6));
      expect(plans.first.consumedAmount, closeTo(1000, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Partial lot consumption
  // ---------------------------------------------------------------------------

  group('partial lot consumption', () {
    test('plan only touches one lot and leaves correct remainder', () async {
      await insertLot(amount: 8000, rate: 0.025, homeCode: 'SAR');

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 3000,
      );

      expect(plans, hasLength(1));
      final plan = plans.first;
      expect(plan.consumedAmount, closeTo(3000, 1e-6));
      expect(plan.remainingAmountAfter, closeTo(5000, 1e-6));
      expect(plan.homeAmount, closeTo(75, 1e-6)); // 3000 * 0.025
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Multi-lot consumption in FIFO order
  // ---------------------------------------------------------------------------

  group('multi-lot FIFO order', () {
    test('exhausts oldest lot first, then draws from next', () async {
      final t0 = DateTime.utc(2026, 1, 1);
      final t1 = DateTime.utc(2026, 1, 2);
      final lot1 = await insertLot(amount: 2000, id: 'lot-a', createdAt: t0);
      final lot2 = await insertLot(amount: 5000, id: 'lot-b', createdAt: t1);

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 4000,
      );

      expect(plans, hasLength(2));
      expect(plans[0].lotId, lot1.id);
      expect(plans[0].consumedAmount, closeTo(2000, 1e-6));
      expect(plans[0].remainingAmountAfter, closeTo(0, 1e-6));

      expect(plans[1].lotId, lot2.id);
      expect(plans[1].consumedAmount, closeTo(2000, 1e-6));
      expect(plans[1].remainingAmountAfter, closeTo(3000, 1e-6));
    });

    test('spans three lots when first two are fully exhausted', () async {
      final t0 = DateTime.utc(2026, 2, 1);
      final t1 = DateTime.utc(2026, 2, 2);
      final t2 = DateTime.utc(2026, 2, 3);
      final lot1 = await insertLot(amount: 1000, id: 'lot-1', createdAt: t0);
      final lot2 = await insertLot(amount: 1000, id: 'lot-2', createdAt: t1);
      final lot3 = await insertLot(amount: 2000, id: 'lot-3', createdAt: t2);

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 2500,
      );

      expect(plans, hasLength(3));
      expect(plans[0].lotId, lot1.id);
      expect(plans[0].consumedAmount, closeTo(1000, 1e-6));
      expect(plans[1].lotId, lot2.id);
      expect(plans[1].consumedAmount, closeTo(1000, 1e-6));
      expect(plans[2].lotId, lot3.id);
      expect(plans[2].consumedAmount, closeTo(500, 1e-6));
      expect(plans[2].remainingAmountAfter, closeTo(1500, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Multi-lot with mixed effective rates
  // ---------------------------------------------------------------------------

  group('multi-lot mixed effective rates', () {
    test('homeAmount is computed per-lot using that lot\'s own rate', () async {
      final t0 = DateTime.utc(2026, 3, 1);
      final t1 = DateTime.utc(2026, 3, 2);
      await insertLot(amount: 2000, rate: 0.030, homeCode: 'SAR', id: 'lot-r1', createdAt: t0);
      await insertLot(amount: 2000, rate: 0.025, homeCode: 'SAR', id: 'lot-r2', createdAt: t1);

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 3000,
      );

      expect(plans, hasLength(2));
      // First lot: 2000 × 0.030 = 60 SAR
      expect(plans[0].consumedAmount, closeTo(2000, 1e-6));
      expect(plans[0].homeAmount, closeTo(60.0, 1e-6));
      expect(plans[0].homeCurrencyCode, 'SAR');

      // Second lot: 1000 × 0.025 = 25 SAR
      expect(plans[1].consumedAmount, closeTo(1000, 1e-6));
      expect(plans[1].homeAmount, closeTo(25.0, 1e-6));
      expect(plans[1].homeCurrencyCode, 'SAR');
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Lot with null effectiveRate
  // ---------------------------------------------------------------------------

  group('lot with null effectiveRate', () {
    test('homeAmount and homeCurrencyCode are null when lot has no cost basis', () async {
      // No rate / homeCode → effectiveRate stays null
      await insertLot(amount: 3000);

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 1500,
      );

      expect(plans, hasLength(1));
      expect(plans.first.homeAmount, isNull);
      expect(plans.first.homeCurrencyCode, isNull);
    });

    test('mixed: first lot has no cost basis, second lot has rate', () async {
      final t0 = DateTime.utc(2026, 4, 1);
      final t1 = DateTime.utc(2026, 4, 2);
      await insertLot(amount: 1000, id: 'lot-nocost', createdAt: t0);
      await insertLot(amount: 2000, rate: 0.025, homeCode: 'SAR', id: 'lot-withcost', createdAt: t1);

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 1500,
      );

      expect(plans, hasLength(2));
      expect(plans[0].homeAmount, isNull);
      expect(plans[0].homeCurrencyCode, isNull);
      expect(plans[1].homeAmount, closeTo(12.5, 1e-6)); // 500 × 0.025
      expect(plans[1].homeCurrencyCode, 'SAR');
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Insufficient balance
  // ---------------------------------------------------------------------------

  group('insufficient balance', () {
    test('throws InsufficientCashException when lots total < required', () async {
      await insertLot(amount: 1000);

      expect(
        () => engine.planConsumption(
          tripId: tripId,
          currencyCode: 'JPY',
          requiredAmount: 5000,
        ),
        throwsA(
          isA<InsufficientCashException>()
              .having((e) => e.required, 'required', closeTo(5000, 1e-6))
              .having((e) => e.available, 'available', closeTo(1000, 1e-6))
              .having((e) => e.currencyCode, 'currencyCode', 'JPY'),
        ),
      );
    });

    test('includes sum of all lots in the available field', () async {
      await insertLot(amount: 300);
      await insertLot(amount: 400);

      expect(
        () => engine.planConsumption(
          tripId: tripId,
          currencyCode: 'JPY',
          requiredAmount: 1000,
        ),
        throwsA(
          isA<InsufficientCashException>()
              .having((e) => e.available, 'available', closeTo(700, 1e-6)),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 8. No lots
  // ---------------------------------------------------------------------------

  group('no open lots', () {
    test('throws InsufficientCashException with available=0 when no lots exist', () async {
      expect(
        () => engine.planConsumption(
          tripId: tripId,
          currencyCode: 'JPY',
          requiredAmount: 100,
        ),
        throwsA(
          isA<InsufficientCashException>()
              .having((e) => e.available, 'available', 0.0)
              .having((e) => e.currencyCode, 'currencyCode', 'JPY'),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Tie-breaker by id when created_at is equal
  // ---------------------------------------------------------------------------

  group('tie-breaker by id', () {
    test('lots with identical created_at are ordered by id ASC', () async {
      final sameTime = DateTime.utc(2026, 5, 1, 12, 0, 0);
      // Insert in reverse id order to confirm that sorting — not insertion order —
      // drives FIFO.
      await insertLot(amount: 1000, id: 'lot-zzz', createdAt: sameTime);
      await insertLot(amount: 1000, id: 'lot-aaa', createdAt: sameTime);

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 1500,
      );

      expect(plans, hasLength(2));
      // 'lot-aaa' < 'lot-zzz' lexicographically → consumed first
      expect(plans[0].lotId, 'lot-aaa');
      expect(plans[0].consumedAmount, closeTo(1000, 1e-6));
      expect(plans[1].lotId, 'lot-zzz');
      expect(plans[1].consumedAmount, closeTo(500, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Decimal precision
  // ---------------------------------------------------------------------------

  group('decimal precision', () {
    test('sub-unit amounts (e.g. 0.01 JPY) do not cause phantom plans', () async {
      await insertLot(amount: 10.5, rate: 0.025, homeCode: 'SAR');

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 10.5,
      );

      expect(plans, hasLength(1));
      expect(plans.first.consumedAmount, closeTo(10.5, 1e-6));
      expect(plans.first.remainingAmountAfter, closeTo(0, 1e-6));
    });

    test('repeating-decimal split across two lots sums exactly to required', () async {
      final t0 = DateTime.utc(2026, 6, 1);
      final t1 = DateTime.utc(2026, 6, 2);
      await insertLot(amount: 1.0 / 3.0, id: 'lot-frac-a', createdAt: t0);
      await insertLot(amount: 1.0, id: 'lot-frac-b', createdAt: t1);

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 1.0 / 3.0,
      );

      // Should be satisfied by the first lot alone.
      expect(plans, hasLength(1));
      final totalConsumed =
          plans.fold<double>(0, (s, p) => s + p.consumedAmount);
      expect(totalConsumed, closeTo(1.0 / 3.0, 1e-9));
    });

    test('home cost basis uses per-lot rate without cross-lot blending', () async {
      // 500 JPY @ 0.033 SAR/JPY + 500 JPY @ 0.028 SAR/JPY
      final t0 = DateTime.utc(2026, 6, 10);
      final t1 = DateTime.utc(2026, 6, 11);
      await insertLot(amount: 500, rate: 0.033, homeCode: 'SAR', id: 'lot-rate1', createdAt: t0);
      await insertLot(amount: 500, rate: 0.028, homeCode: 'SAR', id: 'lot-rate2', createdAt: t1);

      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'JPY',
        requiredAmount: 1000,
      );

      expect(plans, hasLength(2));
      expect(plans[0].homeAmount, closeTo(16.5, 1e-6));  // 500 × 0.033
      expect(plans[1].homeAmount, closeTo(14.0, 1e-6));  // 500 × 0.028
    });
  });

  // ---------------------------------------------------------------------------
  // Edge: currency isolation
  // ---------------------------------------------------------------------------

  group('currency isolation', () {
    test('lots in a different currency are not included in the plan', () async {
      await insertLot(amount: 5000, currency: 'JPY');
      await insertLot(amount: 100, currency: 'USD');

      // Requesting USD — should only see the 100 USD lot
      final plans = await engine.planConsumption(
        tripId: tripId,
        currencyCode: 'USD',
        requiredAmount: 50,
      );

      expect(plans, hasLength(1));
      expect(plans.first.consumedAmount, closeTo(50, 1e-6));
    });
  });
}
