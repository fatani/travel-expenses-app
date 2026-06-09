import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_summary.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Expense _expense({
  required double amount,
  String currency = 'SAR',
  double? transactionAmount,
  String? transactionCurrency,
  double? convertedHomeAmount,
  String? homeCurrency,
  String paymentMethod = 'Credit Card',
  String source = 'manual',
}) {
  return Expense.create(
    tripId: 'trip-1',
    title: 'Test',
    amount: amount,
    currencyCode: currency,
    transactionAmount: transactionAmount,
    transactionCurrency: transactionCurrency,
    convertedHomeAmount: convertedHomeAmount,
    homeCurrency: homeCurrency,
    paymentMethod: paymentMethod,
    source: source,
  );
}

const _calc = TripReportCalculator();

TripReportSummary _run(List<Expense> expenses) =>
    _calc.calculate(tripId: 'trip-1', tripName: 'Test Trip', expenses: expenses);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Gross Spending — Home Currency', () {
    test('cash expense with convertedHomeAmount contributes', () {
      final summary = _run([
        _expense(
          amount: 100,
          currency: 'SAR',
          convertedHomeAmount: 100,
          homeCurrency: 'SAR',
          paymentMethod: 'Cash',
        ),
      ]);

      expect(summary.grossSpendingHomeAmount, 100.0);
      expect(summary.grossSpendingHomeCurrency, 'SAR');
    });

    test('card expense with convertedHomeAmount contributes', () {
      final summary = _run([
        _expense(
          amount: 200,
          currency: 'USD',
          transactionAmount: 200,
          transactionCurrency: 'USD',
          convertedHomeAmount: 750,
          homeCurrency: 'SAR',
          paymentMethod: 'Credit Card',
        ),
      ]);

      expect(summary.grossSpendingHomeAmount, 750.0);
      expect(summary.grossSpendingHomeCurrency, 'SAR');
    });

    test('multi-currency expenses aggregate via convertedHomeAmount', () {
      final summary = _run([
        _expense(
          amount: 100,
          currency: 'SAR',
          convertedHomeAmount: 100,
          homeCurrency: 'SAR',
        ),
        _expense(
          amount: 50,
          currency: 'USD',
          transactionAmount: 50,
          transactionCurrency: 'USD',
          convertedHomeAmount: 187.5,
          homeCurrency: 'SAR',
        ),
        _expense(
          amount: 30,
          currency: 'EUR',
          transactionAmount: 30,
          transactionCurrency: 'EUR',
          convertedHomeAmount: 120,
          homeCurrency: 'SAR',
        ),
      ]);

      expect(summary.grossSpendingHomeAmount, closeTo(407.5, 0.001));
      expect(summary.grossSpendingHomeCurrency, 'SAR');
    });

    test('null convertedHomeAmount is ignored', () {
      final summary = _run([
        _expense(
          amount: 100,
          currency: 'SAR',
          convertedHomeAmount: 100,
          homeCurrency: 'SAR',
        ),
        _expense(
          amount: 50,
          currency: 'USD',
          convertedHomeAmount: null,
          homeCurrency: null,
        ),
      ]);

      expect(summary.grossSpendingHomeAmount, 100.0);
      expect(summary.grossSpendingHomeCurrency, 'SAR');
    });

    test('all null convertedHomeAmounts yields null gross spending', () {
      final summary = _run([
        _expense(amount: 100, currency: 'SAR'),
        _expense(amount: 50, currency: 'USD'),
      ]);

      expect(summary.grossSpendingHomeAmount, isNull);
      expect(summary.grossSpendingHomeCurrency, isNull);
    });

    // Cash wallet transactions live in a separate cash_transactions table and
    // are never passed to TripReportCalculator as Expense objects. These tests
    // confirm that expenses tagged by paymentMethod or channel that resemble
    // wallet infrastructure records do not distort gross spending.

    test('cash-payment expense is a real expense and contributes normally', () {
      // Cash expenses (paymentMethod=Cash) ARE real spending — they reduce the
      // cash wallet balance. They must be included in gross spending.
      final summary = _run([
        _expense(
          amount: 75,
          currency: 'SAR',
          convertedHomeAmount: 75,
          homeCurrency: 'SAR',
          paymentMethod: 'Cash',
        ),
      ]);

      expect(summary.grossSpendingHomeAmount, 75.0);
    });

    test('empty expense list produces null gross spending', () {
      final summary = _run([]);

      expect(summary.grossSpendingHomeAmount, isNull);
      expect(summary.grossSpendingHomeCurrency, isNull);
    });

    // -------------------------------------------------------------------------
    // Regression: mixed homeCurrency values must not be silently merged
    // -------------------------------------------------------------------------

    test('expenses with different homeCurrency values are not merged — only the first currency is summed', () {
      // Expense 1: home currency SAR (anchors the series)
      // Expense 2: home currency USD (different — must be skipped)
      // Expense 3: home currency SAR (same as first — must be included)
      final summary = _run([
        _expense(
          amount: 100,
          currency: 'SAR',
          convertedHomeAmount: 100,
          homeCurrency: 'SAR',
        ),
        _expense(
          amount: 50,
          currency: 'USD',
          transactionAmount: 50,
          transactionCurrency: 'USD',
          convertedHomeAmount: 200,
          homeCurrency: 'USD', // different — must be excluded
        ),
        _expense(
          amount: 60,
          currency: 'EUR',
          transactionAmount: 60,
          transactionCurrency: 'EUR',
          convertedHomeAmount: 240,
          homeCurrency: 'SAR', // same as first — included
        ),
      ]);

      // Only SAR-denominated home amounts should contribute: 100 + 240 = 340.
      // The USD-denominated 200 must NOT be added.
      expect(summary.grossSpendingHomeCurrency, 'SAR');
      expect(summary.grossSpendingHomeAmount, closeTo(340.0, 0.001));
    });

    // -------------------------------------------------------------------------
    // Regression: existing report fields are unaffected
    // -------------------------------------------------------------------------

    test('existing totalBilledByCurrency is unchanged', () {
      final summary = _run([
        _expense(
          amount: 100,
          currency: 'SAR',
          convertedHomeAmount: 100,
          homeCurrency: 'SAR',
        ),
        _expense(
          amount: 50,
          currency: 'USD',
          transactionAmount: 50,
          transactionCurrency: 'USD',
          convertedHomeAmount: 187.5,
          homeCurrency: 'SAR',
        ),
      ]);

      expect(summary.totalBilledByCurrency.length, 2);
      final sarBucket = summary.totalBilledByCurrency
          .firstWhere((b) => b.currency == 'SAR');
      expect(sarBucket.totalAmount, 100.0);
      final usdBucket = summary.totalBilledByCurrency
          .firstWhere((b) => b.currency == 'USD');
      expect(usdBucket.totalAmount, 50.0);
    });

    test('existing expense counts are unchanged', () {
      final summary = _run([
        _expense(amount: 100, currency: 'SAR', convertedHomeAmount: 100, homeCurrency: 'SAR'),
        _expense(amount: 50, currency: 'USD', convertedHomeAmount: 187.5, homeCurrency: 'SAR', transactionCurrency: 'USD', transactionAmount: 50),
      ]);

      expect(summary.totalExpenseCount, 2);
    });
  });
}
