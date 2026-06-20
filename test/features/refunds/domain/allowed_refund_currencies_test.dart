import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/refunds/domain/allowed_refund_currencies.dart';

void main() {
  Expense expense({
    required String currency,
    required String paymentMethod,
    required String paymentChannel,
    bool isReversed = false,
  }) {
    final base = Expense.create(
      tripId: 'trip-1',
      title: 'Item',
      amount: 100,
      currencyCode: currency,
      transactionAmount: 100,
      transactionCurrency: currency,
      spentAt: DateTime(2026, 1, 1),
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
      category: 'Food',
    );
    return isReversed ? base.copyWith(isReversed: true) : base;
  }

  group('buildAllowedRefundCurrencies', () {
    test('orders home, destination, then prior card currencies', () {
      final result = buildAllowedRefundCurrencies(
        homeCurrency: 'SAR',
        destinationCurrency: 'CNY',
        expenses: [
          expense(
            currency: 'USD',
            paymentMethod: 'Credit Card',
            paymentChannel: 'POS Purchase',
          ),
        ],
      );

      expect(result, ['SAR', 'CNY', 'USD']);
    });

    test('excludes currencies used only by cash expenses', () {
      final result = buildAllowedRefundCurrencies(
        homeCurrency: 'SAR',
        destinationCurrency: 'CNY',
        expenses: [
          expense(
            currency: 'JPY',
            paymentMethod: 'Cash',
            paymentChannel: 'Cash',
          ),
        ],
      );

      expect(result, ['SAR', 'CNY']);
      expect(result, isNot(contains('JPY')));
    });

    test('removes duplicates and never repeats home/destination', () {
      final result = buildAllowedRefundCurrencies(
        homeCurrency: 'SAR',
        destinationCurrency: 'CNY',
        expenses: [
          expense(
            currency: 'CNY',
            paymentMethod: 'Credit Card',
            paymentChannel: 'POS Purchase',
          ),
          expense(
            currency: 'SAR',
            paymentMethod: 'Credit Card',
            paymentChannel: 'POS Purchase',
          ),
          expense(
            currency: 'USD',
            paymentMethod: 'Credit Card',
            paymentChannel: 'POS Purchase',
          ),
          expense(
            currency: 'USD',
            paymentMethod: 'Credit Card',
            paymentChannel: 'Online Purchase',
          ),
        ],
      );

      expect(result, ['SAR', 'CNY', 'USD']);
    });

    test('collapses to one entry when home == destination', () {
      final result = buildAllowedRefundCurrencies(
        homeCurrency: 'CNY',
        destinationCurrency: 'CNY',
        expenses: const [],
      );

      expect(result, ['CNY']);
    });

    test('ignores reversed card expenses', () {
      final result = buildAllowedRefundCurrencies(
        homeCurrency: 'SAR',
        destinationCurrency: 'CNY',
        expenses: [
          expense(
            currency: 'USD',
            paymentMethod: 'Credit Card',
            paymentChannel: 'POS Purchase',
            isReversed: true,
          ),
        ],
      );

      expect(result, ['SAR', 'CNY']);
      expect(result, isNot(contains('USD')));
    });

    test('normalizes case and skips blanks', () {
      final result = buildAllowedRefundCurrencies(
        homeCurrency: ' sar ',
        destinationCurrency: '',
        expenses: [
          expense(
            currency: 'usd',
            paymentMethod: 'Credit Card',
            paymentChannel: 'POS Purchase',
          ),
        ],
      );

      expect(result, ['SAR', 'USD']);
    });
  });
}
