import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/quick_add_payment.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-pay',
    name: 'Pay Trip',
    destination: 'Test',
    baseCurrency: 'USD',
  );

  Expense expense({
    required String id,
    required String paymentMethod,
    String? paymentChannel,
    String? paymentNetwork,
    int? cardProfileId,
    DateTime? spentAt,
  }) {
    return Expense.create(
      id: id,
      tripId: trip.id,
      title: 'Item',
      amount: 10,
      currencyCode: 'USD',
      spentAt: spentAt ?? DateTime(2026, 5, 1),
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
      paymentNetwork: paymentNetwork,
      cardProfileId: cardProfileId,
    );
  }

  group('quickAddPaymentChipKeyFromExpense', () {
    test('maps cash expenses to cash chip', () {
      final cash = expense(
        id: 'cash',
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
      );
      expect(quickAddPaymentChipKeyFromExpense(cash), kQuickAddPaymentCash);
    });

    test('maps card profile expenses to card chip', () {
      final card = expense(
        id: 'card',
        paymentMethod: 'Credit Card',
        paymentChannel: 'POS Purchase',
        paymentNetwork: 'Visa',
        cardProfileId: 3,
      );
      expect(quickAddPaymentChipKeyFromExpense(card), kQuickAddPaymentCard);
    });

    test('maps apple pay channel to card chip', () {
      final wallet = expense(
        id: 'apple',
        paymentMethod: 'Credit Card',
        paymentChannel: 'Apple Pay',
        paymentNetwork: 'Visa',
      );
      expect(quickAddPaymentChipKeyFromExpense(wallet), kQuickAddPaymentCard);
    });

    test('maps bank transfer to other chip', () {
      final transfer = expense(
        id: 'xfer',
        paymentMethod: 'Bank Transfer',
        paymentChannel: 'Other',
      );
      expect(quickAddPaymentChipKeyFromExpense(transfer), kQuickAddPaymentOther);
    });
  });

  group('normalizeQuickAddPaymentChipKey', () {
    test('normalizes legacy card profile keys', () {
      expect(normalizeQuickAddPaymentChipKey('card:9'), kQuickAddPaymentCard);
    });

    test('normalizes visa payment method token to card', () {
      expect(normalizeQuickAddPaymentChipKey('Visa'), kQuickAddPaymentCard);
    });

    test('unknown token maps to other', () {
      expect(
        normalizeQuickAddPaymentChipKey('Bank Transfer'),
        kQuickAddPaymentOther,
      );
    });
  });

  group('quickAddPaymentPayloadForChip', () {
    test('card chip saves generic card without profile', () {
      final payload = quickAddPaymentPayloadForChip(kQuickAddPaymentCard);
      expect(payload.method, 'Credit Card');
      expect(payload.channel, 'POS Purchase');
      expect(payload.cardProfileId, isNull);
      expect(payload.network, '');
    });

    test('other chip saves other payment', () {
      final payload = quickAddPaymentPayloadForChip(kQuickAddPaymentOther);
      expect(payload.method, 'Other');
      expect(payload.channel, 'Other');
    });
  });

  group('quickAddPaymentMethodForAddDetails', () {
    test('maps chips to form initial methods', () {
      expect(
        quickAddPaymentMethodForAddDetails(kQuickAddPaymentCash),
        'Cash',
      );
      expect(
        quickAddPaymentMethodForAddDetails(kQuickAddPaymentCard),
        'Card',
      );
      expect(
        quickAddPaymentMethodForAddDetails(kQuickAddPaymentOther),
        'Other',
      );
    });
  });
}
