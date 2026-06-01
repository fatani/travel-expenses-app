import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/quick_add_currency.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

void main() {
  group('deriveQuickAddTripCurrencies', () {
    test('orders base, destination, home and deduplicates', () {
      final trip = Trip.create(
        id: 't1',
        name: 'Trip',
        destination: 'X',
        baseCurrency: 'SAR',
        destinationCurrency: 'EUR',
        homeCurrencySnapshot: 'SAR',
      );

      expect(deriveQuickAddTripCurrencies(trip), ['SAR', 'EUR']);
    });

    test('includes home when different from base and destination', () {
      final trip = Trip.create(
        id: 't2',
        name: 'Trip',
        destination: 'X',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'USD',
      );

      expect(deriveQuickAddTripCurrencies(trip), ['JPY', 'USD']);
    });
  });

  group('deriveQuickAddRecentCurrencies', () {
    final trip = Trip.create(
      id: 't3',
      name: 'Trip',
      destination: 'X',
      baseCurrency: 'USD',
    );

    test('returns unique codes most recent first', () {
      final expenses = [
        Expense.create(
          id: 'e1',
          tripId: trip.id,
          title: 'A',
          amount: 1,
          currencyCode: 'EUR',
          spentAt: DateTime(2026, 5, 20),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
        ),
        Expense.create(
          id: 'e2',
          tripId: trip.id,
          title: 'B',
          amount: 2,
          currencyCode: 'GBP',
          spentAt: DateTime(2026, 5, 21),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
        ),
        Expense.create(
          id: 'e3',
          tripId: trip.id,
          title: 'C',
          amount: 3,
          currencyCode: 'EUR',
          spentAt: DateTime(2026, 5, 19),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
        ),
      ];

      final recent = deriveQuickAddRecentCurrencies(
        expenses,
        exclude: {'USD'},
      );

      expect(recent, ['GBP', 'EUR']);
    });

    test('limits to three recent currencies', () {
      final expenses = List.generate(5, (index) {
        return Expense.create(
          id: 'e$index',
          tripId: trip.id,
          title: 'Item $index',
          amount: 1,
          currencyCode: 'C$index',
          spentAt: DateTime(2026, 5, 30 - index),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
        );
      });

      final recent = deriveQuickAddRecentCurrencies(
        expenses,
        exclude: const {},
        maxCount: 3,
      );

      expect(recent, hasLength(3));
      expect(recent, ['C0', 'C1', 'C2']);
    });

    test('excludes trip currencies from recent list', () {
      final expenses = [
        Expense.create(
          id: 'e1',
          tripId: trip.id,
          title: 'A',
          amount: 1,
          currencyCode: 'USD',
          spentAt: DateTime(2026, 5, 20),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
        ),
        Expense.create(
          id: 'e2',
          tripId: trip.id,
          title: 'B',
          amount: 2,
          currencyCode: 'CHF',
          spentAt: DateTime(2026, 5, 21),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
        ),
      ];

      final options = buildQuickAddCurrencyPickerOptions(trip, expenses);

      expect(options.tripCurrencies, ['USD']);
      expect(options.recentCurrencies, ['CHF']);
      expect(options.allListedCodes, ['USD', 'CHF']);
    });
  });

  group('isValidQuickAddOtherCurrencyCode', () {
    test('accepts three letters only', () {
      expect(isValidQuickAddOtherCurrencyCode('usd'), isTrue);
      expect(isValidQuickAddOtherCurrencyCode('EUR'), isTrue);
    });

    test('rejects invalid codes', () {
      expect(isValidQuickAddOtherCurrencyCode('US'), isFalse);
      expect(isValidQuickAddOtherCurrencyCode('USDD'), isFalse);
      expect(isValidQuickAddOtherCurrencyCode('U1D'), isFalse);
      expect(isValidQuickAddOtherCurrencyCode(''), isFalse);
    });
  });
}
