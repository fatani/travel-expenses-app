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
  double? billedAmount,
  String? billedCurrency,
  double? feesAmount,
  String? feesCurrency,
  bool isInternational = false,
  String? category,
  String? paymentNetwork,
  String? paymentChannel,
  String paymentMethod = 'Credit Card',
}) {
  return Expense.create(
    tripId: 'trip-1',
    title: 'Test expense',
    amount: amount,
    currencyCode: currency,
    transactionAmount: transactionAmount,
    transactionCurrency: transactionCurrency,
    billedAmount: billedAmount,
    billedCurrency: billedCurrency,
    feesAmount: feesAmount,
    feesCurrency: feesCurrency,
    isInternational: isInternational,
    paymentMethod: paymentMethod,
    paymentNetwork: paymentNetwork,
    paymentChannel: paymentChannel,
    category: category,
    spentAt: DateTime(2026, 1, 15),
  );
}

const _calc = TripReportCalculator();

TripReportSummary _run(List<Expense> expenses) =>
    _calc.calculate(tripId: 'trip-1', tripName: 'Test Trip', expenses: expenses);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TripReportCalculator', () {
    // -----------------------------------------------------------------------
    // Empty trip
    // -----------------------------------------------------------------------

    test('empty expenses returns zero counts', () {
      final summary = _run([]);
      expect(summary.totalExpenseCount, 0);
      expect(summary.internationalExpenseCount, 0);
      expect(summary.domesticExpenseCount, 0);
      expect(summary.totalBilledByCurrency, isEmpty);
      expect(summary.totalFeesByCurrency, isEmpty);
      expect(summary.topCategory, isNull);
      expect(summary.smartInsights, isEmpty);
    });

    // -----------------------------------------------------------------------
    // Domestic-only trip
    // -----------------------------------------------------------------------

    group('domestic-only trip', () {
      late TripReportSummary summary;

      setUp(() {
        summary = _run([
          _expense(
            amount: 100,
            currency: 'SAR',
            category: 'Food',
            paymentNetwork: 'Mada',
            paymentChannel: 'POS Purchase',
          ),
          _expense(
            amount: 250,
            currency: 'SAR',
            category: 'Transport',
            paymentNetwork: 'Mada',
            paymentChannel: 'POS Purchase',
          ),
          _expense(
            amount: 50,
            currency: 'SAR',
            category: 'Food',
            paymentNetwork: 'Visa',
            paymentChannel: 'Online Purchase',
          ),
        ]);
      });

      test('counts are correct', () {
        expect(summary.totalExpenseCount, 3);
        expect(summary.domesticExpenseCount, 3);
        expect(summary.internationalExpenseCount, 0);
        expect(summary.hasInternational, isFalse);
      });

      test('total billed in SAR only', () {
        expect(summary.totalBilledByCurrency.length, 1);
        expect(summary.totalBilledByCurrency.first.currency, 'SAR');
        expect(summary.totalBilledByCurrency.first.totalAmount, 400.0);
        expect(summary.totalBilledByCurrency.first.count, 3);
      });

      test('top category is Transport (highest spend)', () {
        expect(summary.topCategory, 'Transport');
      });

      test('smart insights are empty for single-currency domestic trip', () {
        expect(summary.smartInsights, isEmpty);
      });

      test('byCategory buckets include Food and Transport', () {
        final keys = summary.byCategory.map((b) => b.key).toSet();
        expect(keys, containsAll(['Food', 'Transport']));
      });

      test('byCategory Food total is 150 SAR', () {
        final foodBuckets =
            summary.byCategory.where((b) => b.key == 'Food').toList();
        expect(foodBuckets.length, 1);
        expect(foodBuckets.first.totalAmount, 150.0);
      });

      test('byPaymentNetwork has Mada and Visa', () {
        final networks = summary.byPaymentNetwork.map((b) => b.key).toSet();
        expect(networks, containsAll(['Mada', 'Visa']));
      });

      test('byPaymentChannel has POS and Online', () {
        final channels = summary.byPaymentChannel.map((b) => b.key).toSet();
        expect(channels, containsAll(['POS Purchase', 'Online Purchase']));
      });

      test('top payment channel metadata is available', () {
        expect(summary.topPaymentChannel, 'POS Purchase');
      });

      test('no fees', () {
        expect(summary.hasFees, isFalse);
        expect(summary.totalFeesByCurrency, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // International-only trip
    // -----------------------------------------------------------------------

    group('international-only trip (USD transactions, SAR billed)', () {
      late TripReportSummary summary;

      setUp(() {
        summary = _run([
          _expense(
            amount: 200,
            currency: 'SAR',
            transactionAmount: 50,
            transactionCurrency: 'USD',
            billedAmount: 187.5,
            billedCurrency: 'SAR',
            feesAmount: 2.0,
            feesCurrency: 'SAR',
            isInternational: true,
            category: 'Shopping',
            paymentNetwork: 'Visa',
            paymentChannel: 'Online Purchase',
          ),
          _expense(
            amount: 150,
            currency: 'SAR',
            transactionAmount: 30,
            transactionCurrency: 'USD',
            billedAmount: 112.5,
            billedCurrency: 'SAR',
            feesAmount: 1.5,
            feesCurrency: 'SAR',
            isInternational: true,
            category: 'Shopping',
            paymentNetwork: 'Mastercard',
            paymentChannel: 'Online Purchase',
          ),
        ]);
      });

      test('all expenses are international', () {
        expect(summary.totalExpenseCount, 2);
        expect(summary.internationalExpenseCount, 2);
        expect(summary.domesticExpenseCount, 0);
        expect(summary.hasInternational, isTrue);
      });

      test('billed totals are in SAR only', () {
        expect(summary.totalBilledByCurrency.length, 1);
        expect(summary.totalBilledByCurrency.first.currency, 'SAR');
        expect(summary.totalBilledByCurrency.first.totalAmount, 300.0);
      });

      test('fees are correctly summed in SAR', () {
        expect(summary.hasFees, isTrue);
        expect(summary.totalFeesByCurrency.length, 1);
        expect(summary.totalFeesByCurrency.first.currency, 'SAR');
        expect(summary.totalFeesByCurrency.first.totalAmount, 3.5);
      });

      test('byTransactionCurrency shows USD', () {
        expect(summary.byTransactionCurrency.length, 1);
        expect(summary.byTransactionCurrency.first.key, 'USD');
        expect(summary.byTransactionCurrency.first.totalAmount, 80.0);
      });

      test('smart insights include internationalDominant and feesPercentage', () {
        // intl=2, domestic=0 → internationalDominant fires
        // single txn currency (USD) → no multipleCurrencies
        // fees exist → feesPercentage
        expect(summary.smartInsights.length, 2);
        expect(
          summary.smartInsights.first.type,
          TripReportInsightType.internationalDominant,
        );
        expect(
          summary.smartInsights.last.type,
          TripReportInsightType.feesPercentage,
        );
        // fees are 3.5 / 300 ≈ 1%
        expect(summary.smartInsights.last.percentage, 1);
      });
    });

    // -----------------------------------------------------------------------
    // Mixed trip with multiple currencies
    // -----------------------------------------------------------------------

    group('mixed trip with multiple currencies', () {
      late TripReportSummary summary;

      setUp(() {
        summary = _run([
          // Domestic SAR expense
          _expense(
            amount: 200,
            currency: 'SAR',
            isInternational: false,
            category: 'Food',
            paymentNetwork: 'Mada',
            paymentChannel: 'POS Purchase',
          ),
          // USD international
          _expense(
            amount: 375,
            currency: 'SAR',
            transactionAmount: 100,
            transactionCurrency: 'USD',
            billedAmount: 375,
            billedCurrency: 'SAR',
            isInternational: true,
            category: 'Accommodation',
            paymentNetwork: 'Visa',
            paymentChannel: 'Online Purchase',
          ),
          // EUR international
          _expense(
            amount: 250,
            currency: 'SAR',
            transactionAmount: 60,
            transactionCurrency: 'EUR',
            billedAmount: 250,
            billedCurrency: 'SAR',
            feesAmount: 5,
            feesCurrency: 'SAR',
            isInternational: true,
            category: 'Transport',
            paymentNetwork: 'Mastercard',
            paymentChannel: 'POS Purchase',
          ),
        ]);
      });

      test('counts', () {
        expect(summary.totalExpenseCount, 3);
        expect(summary.internationalExpenseCount, 2);
        expect(summary.domesticExpenseCount, 1);
      });

      test('billed total is all SAR, not mixed', () {
        expect(summary.totalBilledByCurrency.length, 1);
        expect(summary.totalBilledByCurrency.first.currency, 'SAR');
        expect(summary.totalBilledByCurrency.first.totalAmount, 825.0);
      });

      test('byTransactionCurrency has SAR, USD, EUR buckets', () {
        final currencies =
            summary.byTransactionCurrency.map((b) => b.key).toSet();
        expect(currencies, containsAll(['SAR', 'USD', 'EUR']));
      });

      test('USD and EUR transaction buckets are separate — no merging', () {
        final usd = summary.byTransactionCurrency
            .firstWhere((b) => b.key == 'USD');
        final eur = summary.byTransactionCurrency
            .firstWhere((b) => b.key == 'EUR');
        expect(usd.totalAmount, 100.0);
        expect(eur.totalAmount, 60.0);
      });

      test('fees exist only for EUR expense', () {
        expect(summary.hasFees, isTrue);
        expect(summary.totalFeesByCurrency.first.totalAmount, 5.0);
      });

      test('top category is Accommodation (375 SAR)', () {
        expect(summary.topCategory, 'Accommodation');
      });

      test('smart insights: internationalDominant, multipleCurrencies, feesPercentage', () {
        // Dominant behavior comes first, then context, then fees.
        expect(summary.smartInsights.length, 3);
        expect(summary.smartInsights[0].type, TripReportInsightType.internationalDominant);
        expect(summary.smartInsights[1].type, TripReportInsightType.multipleCurrencies);
        expect(summary.smartInsights[1].percentage, 3);
        expect(summary.smartInsights[2].type, TripReportInsightType.feesPercentage);
        expect(
          summary.smartInsights.map((i) => i.type),
          isNot(contains(TripReportInsightType.noInternationalFees)),
        );
      });
    });

    // -----------------------------------------------------------------------
    // Mixed payment channels and networks
    // -----------------------------------------------------------------------

    group('multiple payment channels and networks', () {
      late TripReportSummary summary;

      setUp(() {
        summary = _run([
          _expense(
            amount: 100,
            currency: 'SAR',
            paymentNetwork: 'Visa',
            paymentChannel: 'POS Purchase',
            category: 'Food',
          ),
          _expense(
            amount: 200,
            currency: 'SAR',
            paymentNetwork: 'Visa',
            paymentChannel: 'Online Purchase',
            category: 'Shopping',
          ),
          _expense(
            amount: 50,
            currency: 'SAR',
            paymentNetwork: 'Mada',
            paymentChannel: 'POS Purchase',
            category: 'Food',
          ),
          _expense(
            amount: 80,
            currency: 'SAR',
            paymentNetwork: null,
            paymentChannel: null,
            category: 'Other',
          ),
        ]);
      });

      test('byPaymentNetwork Visa total is 300 SAR', () {
        final visa =
            summary.byPaymentNetwork.where((b) => b.key == 'Visa').toList();
        // Two Visa buckets if channels differ, or aggregated by SAR.
        // Calculator groups by (network, currency), so both Visa entries share SAR.
        expect(visa.length, 1);
        expect(visa.first.totalAmount, 300.0);
      });

      test('no-network expense lands in Other bucket', () {
        final other = summary.byPaymentNetwork
            .where((b) => b.key == 'Other')
            .toList();
        expect(other, isNotEmpty);
        expect(other.first.totalAmount, 80.0);
      });

      test('byPaymentChannel POS total is 150 SAR', () {
        final pos = summary.byPaymentChannel
            .where((b) => b.key == 'POS Purchase')
            .toList();
        expect(pos.length, 1);
        expect(pos.first.totalAmount, 150.0);
      });

      test('byPaymentChannel Online total is 200 SAR', () {
        final online = summary.byPaymentChannel
            .where((b) => b.key == 'Online Purchase')
            .toList();
        expect(online.first.totalAmount, 200.0);
      });

      test('top payment network metadata is available', () {
        expect(summary.topPaymentNetwork, 'Visa');
      });
    });

    test('smart insights include noInternationalFees when applicable', () {
      final summary = _run([
        _expense(
          amount: 150,
          currency: 'SAR',
          transactionAmount: 40,
          transactionCurrency: 'USD',
          billedAmount: 150,
          billedCurrency: 'SAR',
          isInternational: true,
          category: 'Transport',
          paymentChannel: 'Online Purchase',
        ),
        _expense(
          amount: 50,
          currency: 'SAR',
          isInternational: false,
          category: 'Food',
          paymentChannel: 'POS Purchase',
        ),
      ]);

      expect(summary.smartInsights.length, 2);
      expect(summary.smartInsights.first.type, TripReportInsightType.multipleCurrencies);
      expect(summary.smartInsights.first.percentage, 2); // SAR + USD
      expect(
        summary.smartInsights.last.type,
        TripReportInsightType.noInternationalFees,
      );
    });

    test('noInternationalFees is not shown when any international expense has fees', () {
      final summary = _run([
        _expense(
          amount: 150,
          currency: 'SAR',
          transactionAmount: 40,
          transactionCurrency: 'USD',
          billedAmount: 150,
          billedCurrency: 'SAR',
          feesAmount: 0.2,
          feesCurrency: 'SAR',
          isInternational: true,
          category: 'Transport',
          paymentChannel: 'Online Purchase',
        ),
        _expense(
          amount: 50,
          currency: 'SAR',
          isInternational: false,
          category: 'Food',
          paymentChannel: 'POS Purchase',
        ),
      ]);

      expect(
        summary.smartInsights.map((insight) => insight.type),
        isNot(contains(TripReportInsightType.noInternationalFees)),
      );
    });
  });
}
