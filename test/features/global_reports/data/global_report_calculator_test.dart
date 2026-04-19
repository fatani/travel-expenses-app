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

      expect(summary.totalTripCount, 0);
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

      expect(summary.totalTripCount, 2);
      expect(summary.totalExpenseCount, 4);
      expect(summary.totalBilledByCurrency.map((bucket) => bucket.currency), ['SAR', 'AED']);
      expect(summary.totalBilledByCurrency[0].totalAmount, 575.0);
      expect(summary.totalBilledByCurrency[1].totalAmount, 60.0);
      expect(summary.topCategory, 'Food');
      expect(summary.mostUsedPaymentChannel, 'Online Purchase');
      expect(summary.mostUsedPaymentNetwork, 'Visa');
      expect(summary.internationalRatioPercentage, 50);
      expect(summary.domesticRatioPercentage, 50);
      expect(summary.trackedTripDays, 8);
      expect(summary.averageSpendPerTripByCurrency[0].amount, 287.5);
      expect(summary.averageDailySpendByCurrency[0].amount, closeTo(71.875, 0.0001));
      expect(summary.smartInsights.length, 3);
      expect(summary.smartInsights[0].type, GlobalReportInsightType.dominantPaymentChannel);
      expect(summary.smartInsights[1].type, GlobalReportInsightType.dominantCategory);
      expect(summary.smartInsights[2].type, GlobalReportInsightType.dominantCurrency);
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
      expect(summary.smartInsights[2].type, GlobalReportInsightType.averageSpendPerTrip);
      expect(summary.smartInsights[2].amount, 200.0);
      expect(summary.smartInsights[2].currency, 'SAR');
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
      expect(summary.topCategory, 'Food');
    });
  });
}
