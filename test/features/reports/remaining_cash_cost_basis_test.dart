import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/reports/domain/remaining_cash_value.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_summary.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/isolated_app_database.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _calc = TripReportCalculator();

/// Minimal expense with a home-currency conversion (keeps Gross Spending tests
/// independent of cash-balance logic).
Expense _expense({
  double amount = 500.0,
  String currency = 'SAR',
  double? convertedHomeAmount,
  String? homeCurrency,
}) =>
    Expense.create(
      tripId: 'trip-1',
      title: 'Test',
      amount: amount,
      currencyCode: currency,
      convertedHomeAmount: convertedHomeAmount,
      homeCurrency: homeCurrency,
      paymentMethod: 'Credit Card',
      source: 'manual',
    );

TripCashBalance _balance(String currency, double amount) => TripCashBalance(
      tripId: 'trip-1',
      currencyCode: currency,
      balanceAmount: amount,
      updatedAt: DateTime.utc(2026, 6, 9),
    );

CashBalanceRateInput _input(
  String currency,
  double balance, {
  double? rate,
  String? home,
}) =>
    CashBalanceRateInput(
      balance: _balance(currency, balance),
      effectiveRate: rate,
      homeCurrency: home,
    );

TripReportSummary _run(
  List<Expense> expenses, {
  List<CashBalanceRateInput> cashBalanceRates = const [],
}) =>
    _calc.calculate(
      tripId: 'trip-1',
      tripName: 'Test Trip',
      expenses: expenses,
      cashBalanceRates: cashBalanceRates,
    );

// ---------------------------------------------------------------------------
// 1 — Domain: RemainingCashValue construction
// ---------------------------------------------------------------------------

void main() {
  group('RemainingCashValue — domain', () {
    test('fields are stored as supplied', () {
      const v = RemainingCashValue(
        currencyCode: 'CNY',
        balanceAmount: 600.0,
        effectiveRate: 0.525,
        homeAmount: 315.0,
        homeCurrency: 'SAR',
      );

      expect(v.currencyCode, 'CNY');
      expect(v.balanceAmount, 600.0);
      expect(v.effectiveRate, 0.525);
      expect(v.homeAmount, 315.0);
      expect(v.homeCurrency, 'SAR');
    });
  });

  // -------------------------------------------------------------------------
  // 2 — Calculator: empty balances
  // -------------------------------------------------------------------------

  group('TripReportCalculator — remainingCashValues', () {
    test('no cashBalanceRates → remainingCashValues is empty', () {
      final summary = _run([_expense()]);
      expect(summary.remainingCashValues, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 3 — One balance with rate
    // -----------------------------------------------------------------------
    test('600 CNY × 0.525 → homeAmount 315 SAR', () {
      final summary = _run(
        [_expense()],
        cashBalanceRates: [_input('CNY', 600.0, rate: 0.525, home: 'SAR')],
      );

      expect(summary.remainingCashValues, hasLength(1));
      final v = summary.remainingCashValues.single;
      expect(v.currencyCode, 'CNY');
      expect(v.balanceAmount, 600.0);
      expect(v.effectiveRate, 0.525);
      expect(v.homeAmount, closeTo(315.0, 0.0001));
      expect(v.homeCurrency, 'SAR');
    });

    // -----------------------------------------------------------------------
    // 4 — Multiple currencies produce multiple entries
    // -----------------------------------------------------------------------
    test('multiple currencies produce one entry each', () {
      final summary = _run(
        [_expense()],
        cashBalanceRates: [
          _input('CNY', 600.0, rate: 0.525, home: 'SAR'),
          _input('JPY', 10000.0, rate: 0.027, home: 'SAR'),
        ],
      );

      expect(summary.remainingCashValues, hasLength(2));
      final cny = summary.remainingCashValues.firstWhere((v) => v.currencyCode == 'CNY');
      final jpy = summary.remainingCashValues.firstWhere((v) => v.currencyCode == 'JPY');
      expect(cny.homeAmount, closeTo(315.0, 0.0001));
      expect(jpy.homeAmount, closeTo(270.0, 0.0001));
    });

    // -----------------------------------------------------------------------
    // 5 — Null rate skipped
    // -----------------------------------------------------------------------
    test('null effectiveRate is skipped', () {
      final summary = _run(
        [_expense()],
        cashBalanceRates: [_input('CNY', 600.0, rate: null, home: 'SAR')],
      );

      expect(summary.remainingCashValues, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 6 — Zero balance skipped
    // -----------------------------------------------------------------------
    test('zero balance is skipped', () {
      final summary = _run(
        [_expense()],
        cashBalanceRates: [_input('CNY', 0.0, rate: 0.525, home: 'SAR')],
      );

      expect(summary.remainingCashValues, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 7 — Negative balance skipped
    // -----------------------------------------------------------------------
    test('negative balance is skipped', () {
      final summary = _run(
        [_expense()],
        cashBalanceRates: [_input('CNY', -50.0, rate: 0.525, home: 'SAR')],
      );

      expect(summary.remainingCashValues, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 8 — Gross Spending unchanged
    // -----------------------------------------------------------------------
    test('grossSpendingHomeAmount is unchanged after adding cash balance rates', () {
      final expenses = [
        _expense(convertedHomeAmount: 1000.0, homeCurrency: 'SAR'),
      ];

      final withoutRates  = _run(expenses);
      final withRates     = _run(
        expenses,
        cashBalanceRates: [_input('CNY', 600.0, rate: 0.525, home: 'SAR')],
      );

      expect(withoutRates.grossSpendingHomeAmount,  1000.0);
      expect(withRates.grossSpendingHomeAmount,     1000.0); // unchanged
    });

    // -----------------------------------------------------------------------
    // 9 — Net Spending unchanged
    // -----------------------------------------------------------------------
    test('netSpendingHomeAmount is unchanged after adding cash balance rates', () {
      final expenses = [
        _expense(convertedHomeAmount: 1000.0, homeCurrency: 'SAR'),
      ];

      final without = _run(expenses);
      final with_ = _run(
        expenses,
        cashBalanceRates: [_input('CNY', 600.0, rate: 0.525, home: 'SAR')],
      );

      // No refunds passed → net should equal gross in both cases.
      expect(without.netSpendingHomeAmount, 1000.0);
      expect(with_.netSpendingHomeAmount,   1000.0); // unchanged
    });
  });

  // -------------------------------------------------------------------------
  // Integration tests (real SQLite via sqflite_ffi)
  // -------------------------------------------------------------------------

  group('RemainingCashCostBasis — integration', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    late AppDatabase appDatabase;
    late CashWalletRepository cashWalletRepo;
    late TripRepository tripRepo;
    late ExpenseRefundRepository refundRepo;
    late Trip trip;

    setUp(() async {
      appDatabase = createIsolatedAppDatabase(prefix: 'remaining_cash');
      cashWalletRepo = CashWalletRepository(appDatabase);
      tripRepo = TripRepository(appDatabase);
      refundRepo = ExpenseRefundRepository(appDatabase);

      trip = await tripRepo.createTrip(
        Trip.create(
          id: 'trip-rc-${DateTime.now().microsecondsSinceEpoch}',
          name: 'Remaining Cash Trip',
          destination: 'Beijing',
          baseCurrency: 'CNY',
          destinationCurrency: 'CNY',
          homeCurrencySnapshot: 'SAR',
        ),
      );
    });

    tearDown(() async {
      await appDatabase.close();
    });

    // -----------------------------------------------------------------------
    // 10 — Real balance + rate produces expected RemainingCashValue
    // -----------------------------------------------------------------------
    test('real balance + rate produces correct RemainingCashValue', () async {
      // 1 000 CNY initial cash, costs 525 SAR → rate = 0.525
      await cashWalletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000.0,
        currencyCode: 'CNY',
        homeCurrencyAmount: 525.0,
        homeCurrencyCode: 'SAR',
      );

      final balances = await cashWalletRepo.getBalancesByTrip(trip.id);
      expect(balances, hasLength(1));

      final rate = await cashWalletRepo.getEffectiveCashRate(
        tripId: trip.id,
        transactionCurrencyCode: 'CNY',
        homeCurrencyCode: 'SAR',
      );
      expect(rate, closeTo(0.525, 0.0001));

      final input = CashBalanceRateInput(
        balance: balances.single,
        effectiveRate: rate,
        homeCurrency: trip.homeCurrencySnapshot,
      );
      final summary = _calc.calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: const [],
        cashBalanceRates: [input],
      );

      expect(summary.remainingCashValues, hasLength(1));
      final v = summary.remainingCashValues.single;
      expect(v.currencyCode, 'CNY');
      expect(v.balanceAmount, 1000.0);
      expect(v.homeAmount, closeTo(525.0, 0.01));
      expect(v.homeCurrency, 'SAR');
    });

    // -----------------------------------------------------------------------
    // 11 — Cash refund increases balance
    // -----------------------------------------------------------------------
    test('cash refund increases wallet balance', () async {
      await cashWalletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000.0,
        currencyCode: 'CNY',
        homeCurrencyAmount: 525.0,
        homeCurrencyCode: 'SAR',
      );

      await refundRepo.createCashRefund(
        tripId: trip.id,
        amount: 200.0,
        currencyCode: 'CNY',
      );

      final balances = await cashWalletRepo.getBalancesByTrip(trip.id);
      final cny = balances.firstWhere((b) => b.currencyCode == 'CNY');
      expect(cny.balanceAmount, closeTo(1200.0, 0.001));
    });

    // -----------------------------------------------------------------------
    // 12 — Cash refund does NOT change effective rate
    // -----------------------------------------------------------------------
    test('cash refund does not affect effective cash rate', () async {
      await cashWalletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000.0,
        currencyCode: 'CNY',
        homeCurrencyAmount: 525.0,
        homeCurrencyCode: 'SAR',
      );

      final rateBefore = await cashWalletRepo.getEffectiveCashRate(
        tripId: trip.id,
        transactionCurrencyCode: 'CNY',
        homeCurrencyCode: 'SAR',
      );

      // Cash refund: 200 CNY returned. Even if it has a derived homeAmount,
      // cashRefund type is excluded from effective rate calculation.
      await refundRepo.createCashRefund(
        tripId: trip.id,
        amount: 200.0,
        currencyCode: 'CNY',
      );

      final rateAfter = await cashWalletRepo.getEffectiveCashRate(
        tripId: trip.id,
        transactionCurrencyCode: 'CNY',
        homeCurrencyCode: 'SAR',
      );

      expect(rateBefore, closeTo(0.525, 0.0001));
      expect(rateAfter,  closeTo(0.525, 0.0001)); // unchanged
    });

    // -----------------------------------------------------------------------
    // 13 — RemainingCashValue reflects higher balance after refund
    // -----------------------------------------------------------------------
    test('remainingCashValue homeAmount increases after cash refund', () async {
      await cashWalletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000.0,
        currencyCode: 'CNY',
        homeCurrencyAmount: 525.0,
        homeCurrencyCode: 'SAR',
      );

      // Capture before-refund values.
      final rateBeforeRefund = await cashWalletRepo.getEffectiveCashRate(
        tripId: trip.id,
        transactionCurrencyCode: 'CNY',
        homeCurrencyCode: 'SAR',
      );
      final balancesBefore = await cashWalletRepo.getBalancesByTrip(trip.id);
      final homeAmountBefore = balancesBefore.single.balanceAmount * rateBeforeRefund!;

      // Issue cash refund of 200 CNY.
      await refundRepo.createCashRefund(
        tripId: trip.id,
        amount: 200.0,
        currencyCode: 'CNY',
      );

      // Capture after-refund values.
      final rateAfterRefund = await cashWalletRepo.getEffectiveCashRate(
        tripId: trip.id,
        transactionCurrencyCode: 'CNY',
        homeCurrencyCode: 'SAR',
      );
      final balancesAfter = await cashWalletRepo.getBalancesByTrip(trip.id);
      final cnyBalance = balancesAfter.firstWhere((b) => b.currencyCode == 'CNY');

      final input = CashBalanceRateInput(
        balance: cnyBalance,
        effectiveRate: rateAfterRefund,
        homeCurrency: trip.homeCurrencySnapshot,
      );
      final summary = _calc.calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: const [],
        cashBalanceRates: [input],
      );

      final v = summary.remainingCashValues.single;

      // Balance increased 1000 → 1200; rate unchanged.
      expect(v.balanceAmount, closeTo(1200.0, 0.001));
      expect(v.effectiveRate, closeTo(0.525, 0.0001));
      expect(v.homeAmount, closeTo(1200.0 * 0.525, 0.01)); // 630 SAR
      expect(v.homeAmount, greaterThan(homeAmountBefore));  // higher than before
    });
  });
}
