// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_currency_summary.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/reports/domain/remaining_cash_value.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/isolated_app_database.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _calc = TripReportCalculator();

Expense _expense({
  double amount = 500.0,
  String currency = 'JPY',
  double? convertedHomeAmount,
  String? homeCurrency,
}) {
  final now = DateTime.now();
  return Expense(
    id: 'exp-${now.microsecondsSinceEpoch}',
    tripId: 'trip-1',
    title: 'test',
    amount: amount,
    currencyCode: currency,
    transactionAmount: amount,
    transactionCurrency: currency,
    originalAmount: amount,
    originalCurrency: currency,
    convertedHomeAmount: convertedHomeAmount,
    homeCurrency: homeCurrency,
    isInternational: false,
    spentAt: now,
    paymentMethod: 'cash',
    paymentNetwork: 'Visa',
    paymentChannel: 'POS',
    source: 'manual',
    category: 'Food',
    createdAt: now,
    updatedAt: now,
  );
}

/// Inserts a minimal open cash lot directly.
Future<void> _insertLot(
  CashLotRepository repo, {
  required String tripId,
  required String currency,
  required double remaining,
  required double effectiveRate,
  required String homeCurrency,
  bool isReversed = false,
}) async {
  final lot = CashLot.create(
    tripId: tripId,
    sourceType: 'atm_withdrawal',
    sourceRefType: 'cash_transaction',
    sourceRefId: 'ref-${DateTime.now().microsecondsSinceEpoch}',
    currencyCode: currency,
    originalAmount: remaining,
    remainingAmount: remaining,
    homeCurrencyAmount: remaining * effectiveRate,
    homeCurrencyCode: homeCurrency,
    effectiveRate: effectiveRate,
  );
  final inserted = await repo.insertCashLot(lot);
  if (isReversed) {
    await repo.markLotReversed(inserted.id);
  }
}

// ---------------------------------------------------------------------------
// Group 1: CashLotCurrencySummary domain type
// ---------------------------------------------------------------------------

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // ── 1. Domain type: CashLotCurrencySummary ──────────────────────────────────
  group('CashLotCurrencySummary domain type', () {
    test('T01 – holds all fields correctly', () {
      const s = CashLotCurrencySummary(
        currencyCode: 'JPY',
        totalRemainingAmount: 10000.0,
        totalHomeAmount: 250.0,
        homeCurrencyCode: 'SAR',
      );
      expect(s.currencyCode, 'JPY');
      expect(s.totalRemainingAmount, 10000.0);
      expect(s.totalHomeAmount, 250.0);
      expect(s.homeCurrencyCode, 'SAR');
    });

    test('T02 – derived rate = totalHomeAmount / totalRemainingAmount', () {
      const s = CashLotCurrencySummary(
        currencyCode: 'EUR',
        totalRemainingAmount: 200.0,
        totalHomeAmount: 800.0,
        homeCurrencyCode: 'SAR',
      );
      expect(s.totalHomeAmount / s.totalRemainingAmount, closeTo(4.0, 1e-9));
    });
  });

  // ── 2. Calculator: lotRemainingValues parameter ─────────────────────────────
  group('TripReportCalculator – lotRemainingValues', () {
    test('T03 – lotRemainingValues take precedence over cashBalanceRates', () {
      final lotValues = [
        const RemainingCashValue(
          currencyCode: 'JPY',
          balanceAmount: 10000,
          effectiveRate: 0.025,
          homeAmount: 250,
          homeCurrency: 'SAR',
        ),
      ];
      final result = _calc.calculate(
        tripId: 'trip-1',
        tripName: 'Trip',
        expenses: [],
        lotRemainingValues: lotValues,
        // cashBalanceRates intentionally empty — lot path wins
      );
      expect(result.remainingCashValues.length, 1);
      expect(result.remainingCashValues.first.currencyCode, 'JPY');
      expect(result.remainingCashValues.first.homeAmount, closeTo(250, 1e-9));
    });

    test('T04 – falls back to cashBalanceRates when lotRemainingValues empty', () {
      // Old path must still work.
      final result = _calc.calculate(
        tripId: 'trip-1',
        tripName: 'Trip',
        expenses: [],
        lotRemainingValues: const [],
      );
      expect(result.remainingCashValues, isEmpty);
    });

    test('T05 – lotRemainingValues with expenses: remainingCashValues populated',
        () {
      final lotValues = [
        const RemainingCashValue(
          currencyCode: 'EUR',
          balanceAmount: 200,
          effectiveRate: 4.0,
          homeAmount: 800,
          homeCurrency: 'SAR',
        ),
      ];
      final result = _calc.calculate(
        tripId: 'trip-1',
        tripName: 'Trip',
        expenses: [_expense(convertedHomeAmount: 1000, homeCurrency: 'SAR')],
        lotRemainingValues: lotValues,
      );
      expect(result.remainingCashValues.length, 1);
      expect(result.remainingCashValues.first.currencyCode, 'EUR');
    });
  });

  // ── 3. Net Trip Cost ─────────────────────────────────────────────────────────
  group('TripReportCalculator – netTripCostHomeAmount', () {
    test('T06 – null when grossSpendingHomeAmount is null', () {
      final result = _calc.calculate(
        tripId: 'trip-1',
        tripName: 'Trip',
        expenses: [_expense()], // no convertedHomeAmount
        lotRemainingValues: const [],
      );
      expect(result.netTripCostHomeAmount, isNull);
    });

    test('T07 – equals netSpending when no remaining cash', () {
      final result = _calc.calculate(
        tripId: 'trip-1',
        tripName: 'Trip',
        expenses: [_expense(convertedHomeAmount: 1000, homeCurrency: 'SAR')],
        lotRemainingValues: const [],
      );
      expect(result.netTripCostHomeAmount,
          closeTo(result.netSpendingHomeAmount!, 1e-9));
    });

    test('T08 – netTripCost = netSpending − remainingCashHome', () {
      final lotValues = [
        const RemainingCashValue(
          currencyCode: 'JPY',
          balanceAmount: 10000,
          effectiveRate: 0.025,
          homeAmount: 250,
          homeCurrency: 'SAR',
        ),
      ];
      final result = _calc.calculate(
        tripId: 'trip-1',
        tripName: 'Trip',
        expenses: [_expense(convertedHomeAmount: 1000, homeCurrency: 'SAR')],
        lotRemainingValues: lotValues,
      );
      // netSpending = 1000, remainingCash = 250 → netTripCost = 750
      expect(result.netTripCostHomeAmount, closeTo(750, 1e-9));
    });

    test('T09 – remaining cash in different home currency is excluded', () {
      final lotValues = [
        const RemainingCashValue(
          currencyCode: 'EUR',
          balanceAmount: 100,
          effectiveRate: 1.1,
          homeAmount: 110,
          homeCurrency: 'USD', // different from SAR gross currency
        ),
      ];
      final result = _calc.calculate(
        tripId: 'trip-1',
        tripName: 'Trip',
        expenses: [_expense(convertedHomeAmount: 500, homeCurrency: 'SAR')],
        lotRemainingValues: lotValues,
      );
      // remainingCash with USD home currency is ignored → netTripCost = 500
      expect(result.netTripCostHomeAmount, closeTo(500, 1e-9));
    });

    test('T10 – multiple cash currencies, only matching home included', () {
      final lotValues = [
        const RemainingCashValue(
          currencyCode: 'JPY',
          balanceAmount: 10000,
          effectiveRate: 0.025,
          homeAmount: 250,
          homeCurrency: 'SAR',
        ),
        const RemainingCashValue(
          currencyCode: 'EUR',
          balanceAmount: 100,
          effectiveRate: 4.0,
          homeAmount: 400,
          homeCurrency: 'SAR',
        ),
        const RemainingCashValue(
          currencyCode: 'GBP',
          balanceAmount: 50,
          effectiveRate: 5.0,
          homeAmount: 250,
          homeCurrency: 'USD', // excluded
        ),
      ];
      final result = _calc.calculate(
        tripId: 'trip-1',
        tripName: 'Trip',
        expenses: [_expense(convertedHomeAmount: 2000, homeCurrency: 'SAR')],
        lotRemainingValues: lotValues,
      );
      // remainingCash SAR = 250 + 400 = 650 → netTripCost = 2000 − 650 = 1350
      expect(result.netTripCostHomeAmount, closeTo(1350, 1e-9));
    });
  });

  // ── 4. CashLotRepository.computeLotCurrencySummaries (SQLite integration) ───
  group('CashLotRepository.computeLotCurrencySummaries', () {
    late AppDatabase db;
    late CashLotRepository repo;
    late TripRepository tripRepo;

    /// Insert a stub trip so FK constraints are satisfied.
    Future<void> seedTrip(String tripId, {String homeCurrency = 'SAR'}) async {
      await tripRepo.createTrip(
        Trip.create(
          id: tripId,
          name: 'Test Trip $tripId',
          destination: 'Test',
          baseCurrency: 'JPY',
          destinationCurrency: 'JPY',
          homeCurrencySnapshot: homeCurrency,
        ),
      );
    }

    setUp(() async {
      db = createIsolatedAppDatabase(prefix: 'sprint7a');
      await db.database; // ensure schema created
      repo = CashLotRepository(db);
      tripRepo = TripRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('T11 – returns empty list when no lots exist', () async {
      await seedTrip('trip-x');
      final result = await repo.computeLotCurrencySummaries(
        tripId: 'trip-x',
        homeCurrencyCode: 'SAR',
      );
      expect(result, isEmpty);
    });

    test('T12 – aggregates two JPY lots correctly', () async {
      await seedTrip('trip-1');
      await _insertLot(repo,
          tripId: 'trip-1',
          currency: 'JPY',
          remaining: 5000,
          effectiveRate: 0.025,
          homeCurrency: 'SAR');
      await _insertLot(repo,
          tripId: 'trip-1',
          currency: 'JPY',
          remaining: 5000,
          effectiveRate: 0.03,
          homeCurrency: 'SAR');

      final result = await repo.computeLotCurrencySummaries(
        tripId: 'trip-1',
        homeCurrencyCode: 'SAR',
      );

      expect(result.length, 1);
      final summary = result.first;
      expect(summary.currencyCode, 'JPY');
      expect(summary.totalRemainingAmount, closeTo(10000, 1e-6));
      // 5000×0.025 + 5000×0.03 = 125 + 150 = 275
      expect(summary.totalHomeAmount, closeTo(275, 1e-6));
      expect(summary.homeCurrencyCode, 'SAR');
      // derived rate = 275/10000 = 0.0275
      expect(summary.totalHomeAmount / summary.totalRemainingAmount,
          closeTo(0.0275, 1e-6));
    });

    test('T13 – reversed lots excluded', () async {
      await seedTrip('trip-1');
      await _insertLot(repo,
          tripId: 'trip-1',
          currency: 'EUR',
          remaining: 100,
          effectiveRate: 4.0,
          homeCurrency: 'SAR');
      await _insertLot(repo,
          tripId: 'trip-1',
          currency: 'EUR',
          remaining: 50,
          effectiveRate: 4.0,
          homeCurrency: 'SAR',
          isReversed: true); // must be excluded

      final result = await repo.computeLotCurrencySummaries(
        tripId: 'trip-1',
        homeCurrencyCode: 'SAR',
      );

      expect(result.length, 1);
      expect(result.first.totalRemainingAmount, closeTo(100, 1e-6));
    });

    test('T14 – different trips isolated', () async {
      await seedTrip('trip-A');
      await seedTrip('trip-B');
      await _insertLot(repo,
          tripId: 'trip-A',
          currency: 'JPY',
          remaining: 1000,
          effectiveRate: 0.025,
          homeCurrency: 'SAR');
      await _insertLot(repo,
          tripId: 'trip-B',
          currency: 'JPY',
          remaining: 2000,
          effectiveRate: 0.025,
          homeCurrency: 'SAR');

      final resultA = await repo.computeLotCurrencySummaries(
        tripId: 'trip-A',
        homeCurrencyCode: 'SAR',
      );
      expect(resultA.length, 1);
      expect(resultA.first.totalRemainingAmount, closeTo(1000, 1e-6));
    });

    test('T15 – mismatched home currency excluded', () async {
      await seedTrip('trip-1');
      await _insertLot(repo,
          tripId: 'trip-1',
          currency: 'USD',
          remaining: 200,
          effectiveRate: 3.75,
          homeCurrency: 'SAR');
      await _insertLot(repo,
          tripId: 'trip-1',
          currency: 'GBP',
          remaining: 100,
          effectiveRate: 1.1,
          homeCurrency: 'USD'); // wrong home currency

      final result = await repo.computeLotCurrencySummaries(
        tripId: 'trip-1',
        homeCurrencyCode: 'SAR',
      );
      expect(result.length, 1);
      expect(result.first.currencyCode, 'USD');
    });
  });
}
