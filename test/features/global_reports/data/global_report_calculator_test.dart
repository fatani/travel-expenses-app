import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/global_reports/data/global_report_calculator.dart';
import 'package:travel_expenses/features/global_reports/domain/global_report_summary.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

Trip _trip({
  required String id,
  required String name,
  required DateTime startDate,
  required DateTime endDate,
  String baseCurrency = 'SAR',
}) {
  return Trip.create(
    id: id,
    name: name,
    destination: 'Test',
    baseCurrency: baseCurrency,
    startDate: startDate,
    endDate: endDate,
  );
}

Expense _expense({
  required String tripId,
  required double amount,
  String currency = 'SAR',
  double? transactionAmount,
  String? transactionCurrency,
  double? billedAmount,
  String? billedCurrency,
  bool isInternational = false,
  String? category,
  String? paymentNetwork,
  String? paymentChannel,
}) {
  return Expense.create(
    tripId: tripId,
    title: 'Expense',
    amount: amount,
    currencyCode: currency,
    transactionAmount: transactionAmount,
    transactionCurrency: transactionCurrency,
    billedAmount: billedAmount,
    billedCurrency: billedCurrency,
    isInternational: isInternational,
    paymentMethod: 'Credit Card',
    category: category,
    paymentNetwork: paymentNetwork,
    paymentChannel: paymentChannel,
    spentAt: DateTime(2026, 1, 15),
  );
}

const _calculator = GlobalReportCalculator();

void main() {
  group('GlobalReportCalculator', () {
    test('returns empty summary for no trips', () {
      final summary = _calculator.calculate(trips: const [], expenses: const []);

      expect(summary.totalTrips, 0);
      expect(summary.activeTrips, 0);
      expect(summary.totalExpenseCount, 0);
      expect(summary.totalBilledByCurrency, isEmpty);
      expect(summary.smartInsights, isEmpty);
    });

    test('aggregates multiple trips and currencies without mixing totals', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'Riyadh',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 3),
        ),
        _trip(
          id: 'trip-2',
          name: 'Dubai',
          startDate: DateTime(2026, 2, 10),
          endDate: DateTime(2026, 2, 14),
        ),
      ];
      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 120,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Mada',
          paymentChannel: 'POS Purchase',
        ),
        _expense(
          tripId: 'trip-1',
          amount: 80,
          currency: 'SAR',
          category: 'Transport',
          paymentNetwork: 'Visa',
          paymentChannel: 'Online Purchase',
        ),
        _expense(
          tripId: 'trip-2',
          amount: 375,
          currency: 'SAR',
          billedAmount: 375,
          billedCurrency: 'SAR',
          transactionAmount: 100,
          transactionCurrency: 'USD',
          isInternational: true,
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'Online Purchase',
        ),
        _expense(
          tripId: 'trip-2',
          amount: 60,
          currency: 'AED',
          billedAmount: 60,
          billedCurrency: 'AED',
          transactionAmount: 60,
          transactionCurrency: 'AED',
          isInternational: true,
          category: 'Shopping',
          paymentNetwork: 'Visa',
          paymentChannel: 'Online Purchase',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalTrips, 2);
      expect(summary.activeTrips, 2);
      expect(summary.totalExpenseCount, 4);
      expect(summary.totalBilledByCurrency.map((bucket) => bucket.currency), ['SAR', 'USD', 'AED']);
      expect(summary.totalBilledByCurrency[0].totalAmount, 200.0);
      expect(summary.totalBilledByCurrency[1].totalAmount, 100.0);
      expect(summary.totalBilledByCurrency[2].totalAmount, 60.0);
      expect(summary.topCategory, 'Food');
      expect(summary.mostUsedPaymentChannel, 'Online Purchase');
      expect(summary.mostUsedPaymentNetwork, 'Visa');
      expect(summary.internationalRatioPercentage, 50);
      expect(summary.domesticRatioPercentage, 50);
      expect(summary.trackedTripDays, 8);
      expect(summary.averageSpendPerTripByCurrency[0].amount, 100.0);
      expect(summary.averageDailySpendByCurrency[0].amount, 25.0);
      expect(summary.smartInsights.length, 2);
      expect(summary.smartInsights[0].type, GlobalReportInsightType.currencyDistribution);
      expect(summary.smartInsights[1].type, GlobalReportInsightType.categoryVariation);
    });

    test('shows separate totals for different currencies', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'One',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 2),
        ),
      ];
      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 2.36,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
        _expense(
          tripId: 'trip-1',
          amount: 23000,
          currency: 'VND',
          category: 'Shopping',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalBilledByCurrency.map((bucket) => bucket.currency), ['VND', 'SAR']);
      expect(summary.totalBilledByCurrency[0].totalAmount, 23000);
      expect(summary.totalBilledByCurrency[1].totalAmount, 2.36);
    });

    test('uses average spend per trip insight for single-currency data', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'One',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 2),
        ),
        _trip(
          id: 'trip-2',
          name: 'Two',
          startDate: DateTime(2026, 3, 5),
          endDate: DateTime(2026, 3, 7),
        ),
      ];
      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 100,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'Online Purchase',
        ),
        _expense(
          tripId: 'trip-2',
          amount: 300,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'Online Purchase',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalBilledByCurrency, hasLength(1));
      expect(summary.averageSpendPerTripByCurrency.first.amount, 200.0);
      expect(summary.smartInsights, isEmpty);
    });

    test('hides smart insights when total expenses are less than 3', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'One',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 2),
        ),
        _trip(
          id: 'trip-2',
          name: 'Two',
          startDate: DateTime(2026, 9, 10),
          endDate: DateTime(2026, 9, 12),
        ),
      ];
      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 100,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'Online Purchase',
        ),
        _expense(
          tripId: 'trip-2',
          amount: 80,
          currency: 'USD',
          category: 'Transport',
          paymentNetwork: 'Mada',
          paymentChannel: 'POS Purchase',
          transactionAmount: 80,
          transactionCurrency: 'USD',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalExpenseCount, 2);
      expect(summary.totalBilledByCurrency.length, 2);
      expect(summary.smartInsights, isEmpty);
    });

    test('shows no summary for two expenses with identical patterns', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'One',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 2),
        ),
      ];
      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 100,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
        _expense(
          tripId: 'trip-1',
          amount: 120,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalExpenseCount, 2);
      expect(summary.smartInsights, isEmpty);
    });

    test('shows summary for three mixed expenses in one trip', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'One',
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 4),
        ),
      ];
      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 100,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
        _expense(
          tripId: 'trip-1',
          amount: 70,
          currency: 'USD',
          transactionAmount: 70,
          transactionCurrency: 'USD',
          category: 'Transport',
          paymentNetwork: 'Mada',
          paymentChannel: 'Online Purchase',
        ),
        _expense(
          tripId: 'trip-1',
          amount: 40,
          currency: 'SAR',
          category: 'Shopping',
          paymentNetwork: 'Mastercard',
          paymentChannel: 'ATM',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalExpenseCount, 3);
      expect(summary.smartInsights, isNotEmpty);
      expect(summary.smartInsights.length, lessThanOrEqualTo(2));
    });

    test('shows summary when currencies are mixed with enough data', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'One',
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 3),
        ),
      ];
      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 100,
          currency: 'SAR',
          category: 'Food',
        ),
        _expense(
          tripId: 'trip-1',
          amount: 80,
          currency: 'USD',
          transactionAmount: 80,
          transactionCurrency: 'USD',
          category: 'Food',
        ),
        _expense(
          tripId: 'trip-1',
          amount: 60,
          currency: 'EUR',
          transactionAmount: 60,
          transactionCurrency: 'EUR',
          category: 'Food',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalExpenseCount, 3);
      expect(summary.uniqueTransactionCurrencyCount, 3);
      expect(summary.smartInsights, isNotEmpty);
      expect(summary.smartInsights.first.type, GlobalReportInsightType.currencyDistribution);
    });

    test('counts total trips separately from active trips', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'With expenses',
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 2),
        ),
        _trip(
          id: 'trip-2',
          name: 'Without expenses',
          startDate: DateTime(2026, 5, 10),
          endDate: DateTime(2026, 5, 12),
        ),
      ];

      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 140,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalTrips, 2);
      expect(summary.activeTrips, 1);
      expect(summary.totalExpenseCount, 1);
    });

    test('returns no insights for single trip', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'Solo',
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 2),
        ),
      ];
      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 220,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalTrips, 1);
      expect(summary.smartInsights, isEmpty);
    });

    test('ignores expenses that do not belong to provided trips', () {
      final trips = [
        _trip(
          id: 'trip-1',
          name: 'One',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 1),
        ),
      ];
      final expenses = [
        _expense(
          tripId: 'trip-1',
          amount: 100,
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
        _expense(
          tripId: 'missing-trip',
          amount: 999,
          category: 'Shopping',
          paymentNetwork: 'Mastercard',
          paymentChannel: 'Online Purchase',
        ),
      ];

      final summary = _calculator.calculate(trips: trips, expenses: expenses);

      expect(summary.totalExpenseCount, 1);
      expect(summary.totalBilledByCurrency.single.totalAmount, 100.0);
      expect(summary.topCategory, isNull);
      expect(summary.mostUsedPaymentChannel, isNull);
      expect(summary.mostUsedPaymentNetwork, isNull);
      expect(summary.smartInsights, isEmpty);
    });
  });
}
