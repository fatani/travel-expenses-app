import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense_payment_service.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_dirty_state.dart';

void main() {
  const payment = NormalizedExpensePayment(
    paymentMethod: 'Cash',
    paymentNetwork: null,
    paymentChannel: 'Cash',
    cardProfileId: null,
  );

  ExpenseFormDirtySnapshot baseline({
    String amountText = '25.00',
    String chargedHomeAmountText = '',
  }) {
    return ExpenseFormDirtySnapshot.fromNormalizedValues(
      title: 'Lunch',
      amountText: amountText,
      currencyCode: 'CNY',
      category: 'Food',
      note: 'Quick bite',
      spentAt: DateTime(2026, 5, 16, 12, 30),
      payment: payment,
      chargedHomeAmountText: chargedHomeAmountText,
      totalChargedAmount: null,
      totalChargedCurrency: null,
    );
  }

  group('ExpenseFormDirtySnapshot', () {
    test('valid amount text with same numeric value is not dirty', () {
      final original = baseline();
      final current = baseline(amountText: '25');

      expect(current, original);
    });

    test('invalid amount text is dirty versus valid baseline', () {
      final original = baseline();
      final cleared = baseline(amountText: '');
      final invalid = baseline(amountText: 'not-a-number');

      expect(cleared, isNot(original));
      expect(invalid, isNot(original));
    });

    test('invalid charged home amount text is dirty versus empty baseline', () {
      final original = baseline();
      final invalid = baseline(chargedHomeAmountText: 'not-a-number');

      expect(invalid, isNot(original));
    });

    test('optionalNumericFieldsEqual never throws on invalid text', () {
      expect(
        ExpenseFormDirtySnapshot.optionalNumericFieldsEqual(
          null,
          'abc',
          25,
          '25.00',
        ),
        isFalse,
      );
    });
  });
}
