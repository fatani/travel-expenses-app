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

  // ─── resolvePaymentMethodHint ───────────────────────────────────────────

  group('resolvePaymentMethodHint', () {
    test('cash channel returns Cash', () {
      expect(service.resolvePaymentMethodHint(null, 'Cash'), 'Cash');
      expect(service.resolvePaymentMethodHint('Visa', 'Cash'), 'Cash');
    });

    test('mobile wallet channel returns Credit Card', () {
      expect(
        service.resolvePaymentMethodHint(null, 'Mobile Wallet'),
        'Credit Card',
      );
    });

    test('null network with card channel returns Other', () {
      expect(service.resolvePaymentMethodHint(null, 'POS Purchase'), 'Other');
      expect(
        service.resolvePaymentMethodHint('', 'Online Purchase'),
        'Other',
      );
    });

    test('Mada network returns Debit Card', () {
      expect(
        service.resolvePaymentMethodHint('Mada', 'POS Purchase'),
        'Debit Card',
      );
    });

    test('Visa network returns Credit Card', () {
      expect(
        service.resolvePaymentMethodHint('Visa', 'POS Purchase'),
        'Credit Card',
      );
    });

    test('Mastercard network returns Credit Card', () {
      expect(
        service.resolvePaymentMethodHint('Mastercard', 'Online Purchase'),
        'Credit Card',
      );
    });

    test('unknown network with card channel returns Other', () {
      expect(
        service.resolvePaymentMethodHint('UnknownBank', 'POS Purchase'),
        'Other',
      );
    });
  });
}