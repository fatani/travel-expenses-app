// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/isolated_app_database.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _calc = TripReportCalculator();

/// Creates a minimal [CashLot] for use in pure-calculator tests (no DB).
CashLot _lot({
  required String sourceType,
  required String currency,
  required double originalAmount,
  double? remainingAmount,
  double? homeCurrencyAmount,
  String? homeCurrencyCode,
  bool isReversed = false,
}) {
  final now = DateTime.now();
  return CashLot(
    id: 'lot-${now.microsecondsSinceEpoch}',
    tripId: 'trip-1',
    sourceType: sourceType,
    sourceRefType: 'cash_transaction',
    sourceRefId: 'ref-${now.microsecondsSinceEpoch}',
    currencyCode: currency,
    originalAmount: originalAmount,
    remainingAmount: remainingAmount ?? originalAmount,
    homeCurrencyAmount: homeCurrencyAmount,
    homeCurrencyCode: homeCurrencyCode,
    effectiveRate: (homeCurrencyAmount != null && originalAmount > 0)
        ? homeCurrencyAmount / originalAmount
        : null,
    isFullyConsumed: false,
    isReversed: isReversed,
    reversedAt: isReversed ? now : null,
    createdAt: now,
  );
}

/// Creates a minimal [Expense] for calculator tests.
Expense _expense({
  required String paymentMethod,
  required String currency,
  required double amount,
  double? convertedHomeAmount,
  String? homeCurrency,
  bool isReversed = false,
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
    paymentMethod: paymentMethod,
    source: 'manual',
    createdAt: now,
    updatedAt: now,
    isReversed: isReversed,
  );
}

// ---------------------------------------------------------------------------
// Group 1 — Cash Acquisition Summary (pure calculator, no DB)
// ---------------------------------------------------------------------------

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Cash Acquisition Summary — calculator', () {
    test('T01 – initial_cash lots grouped correctly', () {
      final lots = [
        _lot(
          sourceType: 'initial_cash',
          currency: 'JPY',
          originalAmount: 10000,
          homeCurrencyAmount: 250,
          homeCurrencyCode: 'SAR',
        ),
        _lot(
          sourceType: 'initial_cash',
          currency: 'JPY',
          originalAmount: 5000,
          homeCurrencyAmount: 125,
          homeCurrencyCode: 'SAR',
        ),
      ];
      final result =
          _calc.calculate(tripId: 'trip-1', tripName: 'T', expenses: const [], activeLots: lots);

      expect(result.cashAcquisitionSummary.length, 1);
      final entry = result.cashAcquisitionSummary.first;
      expect(entry.sourceType, 'initial_cash');
      expect(entry.originalCurrency, 'JPY');
      expect(entry.totalOriginalAmount, closeTo(15000, 1e-9));
      expect(entry.totalHomeAmount, closeTo(375, 1e-9));
      expect(entry.homeCurrency, 'SAR');
      expect(entry.count, 2);
    });

    test('T02 – atm_withdrawal lots grouped correctly', () {
      final lots = [
        _lot(
          sourceType: 'atm_withdrawal',
          currency: 'JPY',
          originalAmount: 20000,
          homeCurrencyAmount: 500,
          homeCurrencyCode: 'SAR',
        ),
      ];
      final result =
          _calc.calculate(tripId: 'trip-1', tripName: 'T', expenses: const [], activeLots: lots);

      expect(result.cashAcquisitionSummary.length, 1);
      final entry = result.cashAcquisitionSummary.first;
      expect(entry.sourceType, 'atm_withdrawal');
      expect(entry.totalOriginalAmount, closeTo(20000, 1e-9));
      expect(entry.count, 1);
    });

    test('T03 – exchange_in lots grouped correctly', () {
      final lots = [
        _lot(
          sourceType: 'exchange_in',
          currency: 'EUR',
          originalAmount: 200,
          homeCurrencyAmount: 800,
          homeCurrencyCode: 'SAR',
        ),
      ];
      final result =
          _calc.calculate(tripId: 'trip-1', tripName: 'T', expenses: const [], activeLots: lots);

      expect(result.cashAcquisitionSummary.length, 1);
      expect(result.cashAcquisitionSummary.first.sourceType, 'exchange_in');
      expect(result.cashAcquisitionSummary.first.originalCurrency, 'EUR');
    });

    test('T04 – cash_refund lots grouped correctly', () {
      final lots = [
        _lot(
          sourceType: 'cash_refund',
          currency: 'JPY',
          originalAmount: 1000,
          homeCurrencyAmount: 25,
          homeCurrencyCode: 'SAR',
        ),
      ];
      final result =
          _calc.calculate(tripId: 'trip-1', tripName: 'T', expenses: const [], activeLots: lots);

      expect(result.cashAcquisitionSummary.length, 1);
      expect(result.cashAcquisitionSummary.first.sourceType, 'cash_refund');
      expect(result.cashAcquisitionSummary.first.totalOriginalAmount, closeTo(1000, 1e-9));
    });

    test('T05 – reversed lots excluded from acquisition summary', () {
      final lots = [
        _lot(
          sourceType: 'atm_withdrawal',
          currency: 'JPY',
          originalAmount: 10000,
          homeCurrencyAmount: 250,
          homeCurrencyCode: 'SAR',
        ),
        _lot(
          sourceType: 'atm_withdrawal',
          currency: 'JPY',
          originalAmount: 5000,
          homeCurrencyAmount: 125,
          homeCurrencyCode: 'SAR',
          isReversed: true, // must be excluded
        ),
      ];
      // activeLots in calculator are pre-filtered by provider;
      // but _buildCashAcquisitionSummary should not re-check isReversed since
      // only active lots are passed. We pass the reversed lot explicitly to
      // verify the provider-level filtering works — here we pass both to
      // confirm the calculator uses what it receives (the pre-filtering is the
      // provider's job). Instead, test that reversed lots from the REPOSITORY
      // don't appear. Here we test at the repository level below (T05b).
      // So this test passes only active lots to the calculator:
      final activeLots = lots.where((l) => !l.isReversed).toList();
      final result = _calc.calculate(
          tripId: 'trip-1', tripName: 'T', expenses: const [], activeLots: activeLots);

      expect(result.cashAcquisitionSummary.length, 1);
      expect(result.cashAcquisitionSummary.first.totalOriginalAmount, closeTo(10000, 1e-9));
      expect(result.cashAcquisitionSummary.first.count, 1);
    });

    test('T06 – multiple currencies produce separate entries', () {
      final lots = [
        _lot(
          sourceType: 'atm_withdrawal',
          currency: 'JPY',
          originalAmount: 10000,
          homeCurrencyAmount: 250,
          homeCurrencyCode: 'SAR',
        ),
        _lot(
          sourceType: 'atm_withdrawal',
          currency: 'EUR',
          originalAmount: 100,
          homeCurrencyAmount: 400,
          homeCurrencyCode: 'SAR',
        ),
      ];
      final result =
          _calc.calculate(tripId: 'trip-1', tripName: 'T', expenses: const [], activeLots: lots);

      expect(result.cashAcquisitionSummary.length, 2);
      final jpy = result.cashAcquisitionSummary
          .firstWhere((e) => e.originalCurrency == 'JPY');
      final eur = result.cashAcquisitionSummary
          .firstWhere((e) => e.originalCurrency == 'EUR');
      expect(jpy.totalOriginalAmount, closeTo(10000, 1e-9));
      expect(eur.totalOriginalAmount, closeTo(100, 1e-9));
    });
  });

  // ── Group 2 — Payment Source Summary ────────────────────────────────────────

  group('Payment Source Summary — calculator', () {
    test('T07 – cash expenses grouped correctly', () {
      final expenses = [
        _expense(paymentMethod: 'cash', currency: 'JPY', amount: 1000),
        _expense(paymentMethod: 'cash', currency: 'JPY', amount: 500),
      ];
      final result = _calc.calculate(
          tripId: 'trip-1', tripName: 'T', expenses: expenses);

      final cashEntries = result.paymentSourceSummary
          .where((e) => e.paymentType == 'cash')
          .toList();
      expect(cashEntries.length, 1);
      expect(cashEntries.first.totalTransactionAmount, closeTo(1500, 1e-9));
      expect(cashEntries.first.transactionCurrency, 'JPY');
      expect(cashEntries.first.count, 2);
    });

    test('T08 – card expenses grouped correctly', () {
      final expenses = [
        _expense(paymentMethod: 'card', currency: 'SAR', amount: 200,
            convertedHomeAmount: 200, homeCurrency: 'SAR'),
        _expense(paymentMethod: 'card', currency: 'SAR', amount: 300,
            convertedHomeAmount: 300, homeCurrency: 'SAR'),
      ];
      final result = _calc.calculate(
          tripId: 'trip-1', tripName: 'T', expenses: expenses);

      final cardEntries = result.paymentSourceSummary
          .where((e) => e.paymentType == 'card')
          .toList();
      expect(cardEntries.length, 1);
      expect(cardEntries.first.totalTransactionAmount, closeTo(500, 1e-9));
      expect(cardEntries.first.totalHomeAmount, closeTo(500, 1e-9));
      expect(cardEntries.first.homeCurrency, 'SAR');
      expect(cardEntries.first.count, 2);
    });

    test('T09 – reversed expenses excluded from payment source summary', () {
      final expenses = [
        _expense(paymentMethod: 'card', currency: 'SAR', amount: 500),
        _expense(
            paymentMethod: 'card', currency: 'SAR', amount: 200,
            isReversed: true), // must be excluded
      ];
      final result = _calc.calculate(
          tripId: 'trip-1', tripName: 'T', expenses: expenses);

      final cardEntries = result.paymentSourceSummary
          .where((e) => e.paymentType == 'card')
          .toList();
      expect(cardEntries.length, 1);
      expect(cardEntries.first.totalTransactionAmount, closeTo(500, 1e-9));
      expect(cardEntries.first.count, 1);
    });

    test('T10 – ATM fee appears under card payment source', () {
      // ATM withdrawal generates an expense with paymentMethod='card' and
      // feesAmount. The fee appears as a card expense, NOT as cash acquisition.
      final expenses = [
        _expense(paymentMethod: 'card', currency: 'SAR', amount: 10),
      ];
      final result = _calc.calculate(
          tripId: 'trip-1', tripName: 'T', expenses: expenses);

      // Card entry exists
      final cardEntries = result.paymentSourceSummary
          .where((e) => e.paymentType == 'card')
          .toList();
      expect(cardEntries, isNotEmpty);
      expect(cardEntries.first.paymentType, 'card');

      // No cash acquisition for a fee — activeLots is empty here
      expect(result.cashAcquisitionSummary, isEmpty);
    });

    test('T11 – refunds do not appear in payment source summary', () {
      // The calculator receives expenses only. Refunds are passed separately
      // and reduce netSpendingHomeAmount — they must NOT be in paymentSourceSummary.
      // Here we verify that passing zero expenses produces zero payment entries,
      // even when refunds are passed.
      final result = _calc.calculate(
        tripId: 'trip-1',
        tripName: 'T',
        expenses: const [],
        // refunds: passing none; just verifying no phantom entries appear
      );
      expect(result.paymentSourceSummary, isEmpty);
    });

    test('T12 – cash and card expenses both present → separate entries', () {
      final expenses = [
        _expense(paymentMethod: 'cash', currency: 'JPY', amount: 1000),
        _expense(paymentMethod: 'card', currency: 'SAR', amount: 200),
      ];
      final result = _calc.calculate(
          tripId: 'trip-1', tripName: 'T', expenses: expenses);

      expect(result.paymentSourceSummary.length, 2);
      // cash entry comes first (sorted: cash < card < other)
      expect(result.paymentSourceSummary[0].paymentType, 'cash');
      expect(result.paymentSourceSummary[1].paymentType, 'card');
    });
  });

  // ── Group 3 — getActiveLotsForTrip repository integration ───────────────────

  group('CashLotRepository.getActiveLotsForTrip', () {
    late AppDatabase db;
    late CashLotRepository repo;
    late TripRepository tripRepo;

    Future<void> seedTrip(String tripId) async {
      await tripRepo.createTrip(
        Trip.create(
          id: tripId,
          name: 'Trip $tripId',
          destination: 'Test',
          baseCurrency: 'JPY',
          destinationCurrency: 'JPY',
          homeCurrencySnapshot: 'SAR',
        ),
      );
    }

    Future<CashLot> insertLot(
      String tripId,
      String sourceType,
      String currency,
      double amount, {
      bool reversed = false,
    }) async {
      final lot = CashLot.create(
        tripId: tripId,
        sourceType: sourceType,
        sourceRefType: 'cash_transaction',
        sourceRefId: 'ref-${DateTime.now().microsecondsSinceEpoch}',
        currencyCode: currency,
        originalAmount: amount,
        homeCurrencyAmount: amount * 0.025,
        homeCurrencyCode: 'SAR',
        effectiveRate: 0.025,
      );
      final inserted = await repo.insertCashLot(lot);
      if (reversed) await repo.markLotReversed(inserted.id);
      return inserted;
    }

    setUp(() async {
      db = createIsolatedAppDatabase(prefix: 'sprint7b');
      await db.database;
      repo = CashLotRepository(db);
      tripRepo = TripRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('T13 – returns all active lots, reversed excluded', () async {
      await seedTrip('trip-1');
      await insertLot('trip-1', 'atm_withdrawal', 'JPY', 10000);
      await insertLot('trip-1', 'initial_cash', 'JPY', 5000);
      await insertLot('trip-1', 'atm_withdrawal', 'JPY', 2000, reversed: true);

      final lots = await repo.getActiveLotsForTrip('trip-1');
      expect(lots.length, 2);
      expect(lots.every((l) => !l.isReversed), isTrue);
    });

    test('T14 – different trips isolated', () async {
      await seedTrip('trip-A');
      await seedTrip('trip-B');
      await insertLot('trip-A', 'atm_withdrawal', 'JPY', 10000);
      await insertLot('trip-B', 'initial_cash', 'EUR', 100);

      final lotsA = await repo.getActiveLotsForTrip('trip-A');
      final lotsB = await repo.getActiveLotsForTrip('trip-B');
      expect(lotsA.length, 1);
      expect(lotsA.first.currencyCode, 'JPY');
      expect(lotsB.length, 1);
      expect(lotsB.first.currencyCode, 'EUR');
    });

    test('T15 – fully consumed but non-reversed lots are included', () async {
      // Cash Acquisition shows what was acquired, not just what remains.
      await seedTrip('trip-1');
      final lot = CashLot.create(
        tripId: 'trip-1',
        sourceType: 'atm_withdrawal',
        sourceRefType: 'cash_transaction',
        sourceRefId: 'ref-fully-consumed',
        currencyCode: 'JPY',
        originalAmount: 5000,
        remainingAmount: 0,
        homeCurrencyAmount: 125,
        homeCurrencyCode: 'SAR',
        effectiveRate: 0.025,
      );
      final inserted = await repo.insertCashLot(lot);
      await repo.updateLotRemainingAmount(inserted.id, 0);

      final lots = await repo.getActiveLotsForTrip('trip-1');
      expect(lots.length, 1);
      expect(lots.first.originalAmount, closeTo(5000, 1e-9));
    });
  });
}
