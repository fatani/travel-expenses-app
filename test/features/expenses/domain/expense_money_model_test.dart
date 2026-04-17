import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';

void main() {
  group('Expense.moneyModel', () {
    test('maps all money fields consistently', () {
      final expense = Expense.create(
        tripId: 'trip-1',
        title: 'Test expense',
        amount: 10.0,
        currencyCode: 'USD',
        transactionAmount: 10.0,
        transactionCurrency: 'USD',
        billedAmount: 37.53,
        billedCurrency: 'SAR',
        feesAmount: 0.24,
        feesCurrency: 'SAR',
        totalChargedAmount: 37.77,
        totalChargedCurrency: 'SAR',
        paymentMethod: 'Credit Card',
        category: 'Shopping',
      );

      final money = expense.moneyModel;

      expect(money.transactionAmount, 10.0);
      expect(money.transactionCurrency, 'USD');
      expect(money.billedAmount, 37.53);
      expect(money.billedCurrency, 'SAR');
      expect(money.feesAmount, 0.24);
      expect(money.feesCurrency, 'SAR');
      expect(money.totalChargedAmount, 37.77);
      expect(money.totalChargedCurrency, 'SAR');
      expect(money.isInternational, isTrue);
    });

    test('keeps optional fee fields null when absent', () {
      final expense = Expense.create(
        tripId: 'trip-2',
        title: 'Local purchase',
        amount: 120.0,
        currencyCode: 'SAR',
        paymentMethod: 'Debit Card',
        category: 'Food',
      );

      final money = expense.moneyModel;

      expect(money.transactionAmount, 120.0);
      expect(money.transactionCurrency, 'SAR');
      expect(money.feesAmount, isNull);
      expect(money.feesCurrency, isNull);
      expect(money.billedAmount, isNull);
      expect(money.totalChargedAmount, isNull);
      expect(money.isInternational, isFalse);
    });
  });
}
