import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_summary.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _calc = TripReportCalculator();

/// Minimal expense with a home-currency conversion.
Expense _expense({
  double amount = 1000.0,
  String currency = 'SAR',
  double? convertedHomeAmount,
  String? homeCurrency,
}) {
  return Expense.create(
    tripId: 'trip-1',
    title: 'Test',
    amount: amount,
    currencyCode: currency,
    convertedHomeAmount: convertedHomeAmount,
    homeCurrency: homeCurrency,
    paymentMethod: 'Credit Card',
    source: 'manual',
  );
}

/// Active (non-reversed) refund with a home-currency amount.
ExpenseRefund _activeRefund({
  double homeAmount = 100.0,
  String homeCurrency = 'SAR',
}) {
  return ExpenseRefund.create(
    id: 'r-${homeAmount.toStringAsFixed(0)}-$homeCurrency',
    tripId: 'trip-1',
    amount: homeAmount,
    currencyCode: 'SAR',
    homeAmount: homeAmount,
    homeCurrency: homeCurrency,
    destination: RefundDestination.card,
  );
}

/// Reversed refund — must never be counted.
ExpenseRefund _reversedRefund({
  double homeAmount = 100.0,
  String homeCurrency = 'SAR',
}) {
  final created = ExpenseRefund.create(
    id: 'r-rev-${homeAmount.toStringAsFixed(0)}',
    tripId: 'trip-1',
    amount: homeAmount,
    currencyCode: 'SAR',
    homeAmount: homeAmount,
    homeCurrency: homeCurrency,
    destination: RefundDestination.card,
  );
  return created.copyWith(
    isReversed: true,
    reversedAt: DateTime.utc(2026, 6, 10),
  );
}

TripReportSummary _run(
  List<Expense> expenses, {
  List<ExpenseRefund> refunds = const [],
}) =>
    _calc.calculate(
      tripId: 'trip-1',
      tripName: 'Test Trip',
      expenses: expenses,
      refunds: refunds,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Net Spending — Home Currency', () {
    // -----------------------------------------------------------------------
    // 1. No refunds
    // -----------------------------------------------------------------------
    test('no refunds: refundHomeAmount is null; net equals gross', () {
      final summary = _run([
        _expense(convertedHomeAmount: 1000.0, homeCurrency: 'SAR'),
      ]);

      expect(summary.grossSpendingHomeAmount, 1000.0);
      expect(summary.refundHomeAmount, isNull);
      expect(summary.netSpendingHomeAmount, 1000.0);
    });

    // -----------------------------------------------------------------------
    // 2. One active refund
    // -----------------------------------------------------------------------
    test('one active refund: net = gross - refund', () {
      final summary = _run(
        [_expense(convertedHomeAmount: 1000.0, homeCurrency: 'SAR')],
        refunds: [_activeRefund(homeAmount: 200.0, homeCurrency: 'SAR')],
      );

      expect(summary.grossSpendingHomeAmount, 1000.0);
      expect(summary.refundHomeAmount, 200.0);
      expect(summary.netSpendingHomeAmount, 800.0);
    });

    // -----------------------------------------------------------------------
    // 3. Multiple active refunds — totals are summed
    // -----------------------------------------------------------------------
    test('multiple active refunds: refundHomeAmount sums all', () {
      final summary = _run(
        [_expense(convertedHomeAmount: 1000.0, homeCurrency: 'SAR')],
        refunds: [
          _activeRefund(homeAmount: 100.0, homeCurrency: 'SAR'),
          _activeRefund(homeAmount: 150.0, homeCurrency: 'SAR'),
          _activeRefund(homeAmount: 50.0,  homeCurrency: 'SAR'),
        ],
      );

      expect(summary.refundHomeAmount, closeTo(300.0, 0.001));
      expect(summary.netSpendingHomeAmount, closeTo(700.0, 0.001));
    });

    // -----------------------------------------------------------------------
    // 4. Reversed refund is excluded; active one counts
    // -----------------------------------------------------------------------
    test('reversed refund is excluded; active refund counts', () {
      final summary = _run(
        [_expense(convertedHomeAmount: 1000.0, homeCurrency: 'SAR')],
        refunds: [
          _activeRefund(homeAmount: 200.0, homeCurrency: 'SAR'),
          _reversedRefund(homeAmount: 500.0, homeCurrency: 'SAR'),
        ],
      );

      expect(summary.refundHomeAmount, 200.0);
      expect(summary.netSpendingHomeAmount, 800.0);
    });

    // -----------------------------------------------------------------------
    // 5. Refund with null homeAmount is ignored
    // -----------------------------------------------------------------------
    test('refund with null homeAmount is ignored', () {
      final refundNoHome = ExpenseRefund.create(
        id: 'r-no-home',
        tripId: 'trip-1',
        amount: 500.0,
        currencyCode: 'SAR',
        homeAmount: null,
        homeCurrency: null,
        destination: RefundDestination.card,
      );

      final summary = _run(
        [_expense(convertedHomeAmount: 1000.0, homeCurrency: 'SAR')],
        refunds: [refundNoHome],
      );

      expect(summary.refundHomeAmount, isNull);
      expect(summary.netSpendingHomeAmount, 1000.0); // equals gross
    });

    // -----------------------------------------------------------------------
    // 6. Refund with different homeCurrency is ignored
    // -----------------------------------------------------------------------
    test('refund with different homeCurrency is ignored', () {
      final summary = _run(
        [_expense(convertedHomeAmount: 1000.0, homeCurrency: 'SAR')],
        refunds: [_activeRefund(homeAmount: 200.0, homeCurrency: 'USD')],
      );

      expect(summary.refundHomeAmount, isNull);
      expect(summary.netSpendingHomeAmount, 1000.0); // equals gross
    });

    // -----------------------------------------------------------------------
    // 7. Gross remains unchanged after adding refunds
    // -----------------------------------------------------------------------
    test('gross spending is unchanged after adding refunds', () {
      final expenses = [
        _expense(convertedHomeAmount: 600.0, homeCurrency: 'SAR'),
        _expense(convertedHomeAmount: 400.0, homeCurrency: 'SAR'),
      ];

      final withoutRefunds = _run(expenses);
      final withRefunds = _run(
        expenses,
        refunds: [_activeRefund(homeAmount: 300.0, homeCurrency: 'SAR')],
      );

      expect(withoutRefunds.grossSpendingHomeAmount, 1000.0);
      expect(withRefunds.grossSpendingHomeAmount, 1000.0); // unchanged
      expect(withRefunds.netSpendingHomeAmount, 700.0);
    });

    // -----------------------------------------------------------------------
    // 8. Transaction-currency totals are unchanged
    // -----------------------------------------------------------------------
    test('transaction-currency totals are unchanged after adding refunds', () {
      final expenses = [
        _expense(amount: 100.0, currency: 'SAR', convertedHomeAmount: 100.0, homeCurrency: 'SAR'),
        _expense(amount: 50.0,  currency: 'USD', convertedHomeAmount: 187.5, homeCurrency: 'SAR'),
      ];

      final withoutRefunds = _run(expenses);
      final withRefunds    = _run(
        expenses,
        refunds: [_activeRefund(homeAmount: 50.0, homeCurrency: 'SAR')],
      );

      expect(withoutRefunds.totalBilledByCurrency.length, 2);
      expect(withRefunds.totalBilledByCurrency.length, 2);

      final sarBucket = withRefunds.totalBilledByCurrency
          .firstWhere((b) => b.currency == 'SAR');
      expect(sarBucket.totalAmount, 100.0);

      final usdBucket = withRefunds.totalBilledByCurrency
          .firstWhere((b) => b.currency == 'USD');
      expect(usdBucket.totalAmount, 50.0);
    });

    // -----------------------------------------------------------------------
    // 9. No gross but refunds exist → netSpendingHomeAmount is null
    // -----------------------------------------------------------------------
    test('no gross spending: netSpendingHomeAmount is null even when refunds exist', () {
      // Expenses have no convertedHomeAmount — gross is null.
      final expensesNoHome = [
        _expense(amount: 500.0, currency: 'SAR'),
      ];

      final summary = _run(
        expensesNoHome,
        refunds: [_activeRefund(homeAmount: 100.0, homeCurrency: 'SAR')],
      );

      expect(summary.grossSpendingHomeAmount, isNull);
      expect(summary.netSpendingHomeAmount, isNull);
      // refundHomeAmount is also null because grossCurrency is unknown.
      expect(summary.refundHomeAmount, isNull);
    });

    // -----------------------------------------------------------------------
    // 10. Mixed: some refunds valid, some ignored (currency mismatch + null)
    // -----------------------------------------------------------------------
    test('mixed refunds: only matching-currency non-null active refunds count', () {
      final refundNoHome = ExpenseRefund.create(
        id: 'r-mixed-no-home',
        tripId: 'trip-1',
        amount: 100.0,
        currencyCode: 'SAR',
        homeAmount: null,
        homeCurrency: null,
        destination: RefundDestination.card,
      );

      final summary = _run(
        [_expense(convertedHomeAmount: 1000.0, homeCurrency: 'SAR')],
        refunds: [
          _activeRefund(homeAmount: 120.0, homeCurrency: 'SAR'),  // valid
          _activeRefund(homeAmount: 80.0,  homeCurrency: 'USD'),  // wrong currency
          refundNoHome,                                           // null homeAmount
          _reversedRefund(homeAmount: 200.0, homeCurrency: 'SAR'), // reversed
        ],
      );

      expect(summary.refundHomeAmount, 120.0);
      expect(summary.netSpendingHomeAmount, 880.0);
    });
  });
}
