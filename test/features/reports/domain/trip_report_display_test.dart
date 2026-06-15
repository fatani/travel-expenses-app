import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/reports/domain/report_bucket.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_display.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_summary.dart';

void main() {
  group('buildRefundsByTransactionCurrency', () {
    test('sums active refunds by currency and ignores reversed', () {
      final refunds = [
        ExpenseRefund.create(
          id: 'r1',
          tripId: 'trip-1',
          amount: 400,
          currencyCode: 'CNY',
          destination: RefundDestination.card,
        ),
        ExpenseRefund.create(
          id: 'r2',
          tripId: 'trip-1',
          amount: 100,
          currencyCode: 'CNY',
          destination: RefundDestination.card,
        ),
        ExpenseRefund.create(
          id: 'r3',
          tripId: 'trip-1',
          amount: 50,
          currencyCode: 'USD',
          destination: RefundDestination.card,
        ).copyWith(isReversed: true),
      ];

      final buckets = buildRefundsByTransactionCurrency(refunds);

      expect(buckets, hasLength(1));
      expect(buckets.single.currency, 'CNY');
      expect(buckets.single.totalAmount, 500);
      expect(buckets.single.count, 2);
    });
  });

  group('netTransactionAmountForCurrency', () {
    final summary = TripReportSummary(
      tripId: 'trip-1',
      tripName: 'Trip',
      totalExpenseCount: 2,
      internationalExpenseCount: 0,
      domesticExpenseCount: 2,
      totalBilledByCurrency: const [
        ReportBucket(
          key: 'CNY',
          currency: 'CNY',
          totalAmount: 1390,
          count: 2,
        ),
      ],
      totalFeesByCurrency: const [],
      topCategory: null,
      topPaymentNetwork: null,
      topPaymentChannel: null,
      byCategory: const [],
      byTransactionCurrency: const [],
      byPaymentNetwork: const [],
      byPaymentChannel: const [],
      smartInsights: const [],
      grossSpendingHomeAmount: null,
      grossSpendingHomeCurrency: null,
      refundHomeAmount: null,
      netSpendingHomeAmount: null,
    );

    final refundsByCurrency = buildRefundsByTransactionCurrency([
      ExpenseRefund.create(
        id: 'r1',
        tripId: 'trip-1',
        amount: 400,
        currencyCode: 'CNY',
        destination: RefundDestination.card,
      ),
    ]);

    test('subtracts refund face values from gross billed amount', () {
      expect(
        grossTransactionAmountForCurrency(summary, 'CNY'),
        1390,
      );
      expect(
        refundTransactionAmountForCurrency(refundsByCurrency, 'CNY'),
        400,
      );
      expect(
        netTransactionAmountForCurrency(
          summary: summary,
          refundsByTransactionCurrency: refundsByCurrency,
          currency: 'CNY',
        ),
        990,
      );
    });
  });
}
