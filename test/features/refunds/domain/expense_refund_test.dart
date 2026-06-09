import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';

void main() {
  group('ExpenseRefund', () {
    test('create factory defaults isReversed to false and reversedAt to null', () {
      final refund = ExpenseRefund.create(
        id: 'r1',
        tripId: 'trip1',
        amount: 50.0,
        currencyCode: 'USD',
        destination: RefundDestination.card,
      );

      expect(refund.isReversed, isFalse);
      expect(refund.reversedAt, isNull);
    });

    test('fromMap / toMap round-trip preserves all fields', () {
      final now = DateTime.utc(2026, 6, 9, 10, 0, 0);
      final reversedAt = DateTime.utc(2026, 6, 10, 12, 0, 0);

      final original = ExpenseRefund(
        id: 'r1',
        tripId: 'trip1',
        expenseId: 'exp1',
        amount: 75.5,
        currencyCode: 'SAR',
        homeAmount: 20.1,
        homeCurrency: 'USD',
        destination: RefundDestination.cash,
        note: 'hotel refund',
        isReversed: true,
        reversedAt: reversedAt,
        createdAt: now,
      );

      final map = original.toMap();
      final restored = ExpenseRefund.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.tripId, original.tripId);
      expect(restored.expenseId, original.expenseId);
      expect(restored.amount, original.amount);
      expect(restored.currencyCode, original.currencyCode);
      expect(restored.homeAmount, original.homeAmount);
      expect(restored.homeCurrency, original.homeCurrency);
      expect(restored.destination, original.destination);
      expect(restored.note, original.note);
      expect(restored.isReversed, isTrue);
      expect(restored.reversedAt, reversedAt);
      expect(restored.createdAt, now);
    });

    test('isReversed false maps to 0 in toMap', () {
      final refund = ExpenseRefund.create(
        id: 'r2',
        tripId: 'trip1',
        amount: 10.0,
        currencyCode: 'EUR',
        destination: RefundDestination.card,
      );
      expect(refund.toMap()['is_reversed'], 0);
    });

    test('reversed refund maps correctly from is_reversed = 1', () {
      final map = {
        'id': 'r3',
        'trip_id': 'trip1',
        'expense_id': null,
        'amount': 30.0,
        'currency_code': 'USD',
        'home_amount': null,
        'home_currency': null,
        'destination': 'card',
        'note': null,
        'is_reversed': 1,
        'reversed_at': '2026-06-10T12:00:00.000Z',
        'created_at': '2026-06-09T10:00:00.000Z',
      };

      final refund = ExpenseRefund.fromMap(map);

      expect(refund.isReversed, isTrue);
      expect(refund.reversedAt, isNotNull);
    });

    test('currencyCode is normalized to uppercase by create factory', () {
      final refund = ExpenseRefund.create(
        id: 'r4',
        tripId: 'trip1',
        amount: 10.0,
        currencyCode: 'usd',
        destination: RefundDestination.cash,
      );
      expect(refund.currencyCode, 'USD');
    });

    group('fromMap homeCurrency normalization', () {
      Map<String, Object?> baseMap({Object? homeCurrency}) => {
            'id': 'r5',
            'trip_id': 'trip1',
            'expense_id': null,
            'amount': 50.0,
            'currency_code': 'JPY',
            'home_amount': 12.5,
            'home_currency': homeCurrency,
            'destination': 'card',
            'note': null,
            'is_reversed': 0,
            'reversed_at': null,
            'created_at': '2026-06-09T10:00:00.000Z',
          };

      test('lowercase homeCurrency is uppercased', () {
        final refund = ExpenseRefund.fromMap(baseMap(homeCurrency: 'sar'));
        expect(refund.homeCurrency, 'SAR');
      });

      test('homeCurrency with surrounding whitespace is trimmed and uppercased', () {
        final refund = ExpenseRefund.fromMap(baseMap(homeCurrency: ' sar '));
        expect(refund.homeCurrency, 'SAR');
      });

      test('null homeCurrency remains null', () {
        final refund = ExpenseRefund.fromMap(baseMap(homeCurrency: null));
        expect(refund.homeCurrency, isNull);
      });

      test('already-uppercase homeCurrency is unchanged', () {
        final refund = ExpenseRefund.fromMap(baseMap(homeCurrency: 'USD'));
        expect(refund.homeCurrency, 'USD');
      });
    });
  });
}
