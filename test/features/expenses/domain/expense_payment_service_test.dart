import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense_payment_service.dart';

void main() {
  const service = ExpensePaymentService();

  test('normalizes cash payment metadata', () {
    final result = service.normalizeExpensePaymentMetadata(
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      paymentNetwork: 'Visa',
      cardProfileId: 42,
    );

    expect(result.paymentMethod, 'Cash');
    expect(result.paymentChannel, 'Cash');
    expect(result.paymentNetwork, isNull);
    expect(result.cardProfileId, isNull);
  });

  test('maps mobile wallet to real card source', () {
    final result = service.normalizeExpensePaymentMetadata(
      paymentMethod: 'Mobile Wallet',
      paymentChannel: 'Wallet',
      paymentNetwork: 'Visa',
      cardProfileId: 7,
    );

    expect(result.paymentMethod, 'Credit Card');
    expect(result.paymentChannel, 'POS Purchase');
    expect(result.paymentNetwork, 'Visa');
    expect(result.cardProfileId, 7);
  });

  test('defaults card method without channel to POS purchase', () {
    final result = service.normalizeExpensePaymentMetadata(
      paymentMethod: 'Card',
      paymentNetwork: 'Mada',
    );

    expect(result.paymentMethod, 'Debit Card');
    expect(result.paymentChannel, 'POS Purchase');
    expect(result.paymentNetwork, 'Mada');
  });
}