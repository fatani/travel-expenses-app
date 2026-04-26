import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/export/data/trip_csv_exporter.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

Trip _trip({String name = 'Business Trip'}) {
  return Trip.create(
    id: 'trip-1',
    name: name,
    destination: 'Riyadh',
    baseCurrency: 'SAR',
    startDate: DateTime(2026, 4, 1),
    endDate: DateTime(2026, 4, 10),
  );
}

Expense _expense({
  String title = 'Coffee',
  DateTime? spentAt,
  String? category,
  String? paymentChannel,
  String? paymentNetwork,
  double amount = 18,
  String currency = 'SAR',
  double? transactionAmount,
  String? transactionCurrency,
  double? billedAmount,
  String? billedCurrency,
  double? feesAmount,
  String? feesCurrency,
  String? note,
}) {
  return Expense.create(
    tripId: 'trip-1',
    title: title,
    amount: amount,
    currencyCode: currency,
    transactionAmount: transactionAmount,
    transactionCurrency: transactionCurrency,
    billedAmount: billedAmount,
    billedCurrency: billedCurrency,
    feesAmount: feesAmount,
    feesCurrency: feesCurrency,
    paymentMethod: 'Card',
    paymentNetwork: paymentNetwork,
    paymentChannel: paymentChannel,
    category: category,
    note: note,
    spentAt: spentAt ?? DateTime(2026, 4, 2),
  );
}

void main() {
  group('TripCsvExporter', () {
    late TripCsvExporter exporter;

    setUp(() {
      exporter = TripCsvExporter();
    });

    test('exports one expense with header and one row', () {
      final csv = exporter.buildCsv(
        trip: _trip(),
        expenses: [
          _expense(
            title: 'Lunch',
            category: 'Food',
            paymentChannel: 'POS Purchase',
            paymentNetwork: 'Visa',
            amount: 45,
            currency: 'SAR',
            note: 'Client meeting',
          ),
        ],
      );

      final lines = const LineSplitter().convert(csv);
      expect(lines.length, 2);
      expect(lines.first, startsWith('\uFEFFTrip name,Expense date,Merchant / title'));
      expect(lines.last, contains('Business Trip,2026-04-02,Lunch,Food,POS Purchase,Visa,45,SAR'));
      expect(lines.last, endsWith('Client meeting'));
    });

    test('exports multiple expenses as separate rows', () {
      final csv = exporter.buildCsv(
        trip: _trip(),
        expenses: [
          _expense(title: 'Breakfast', amount: 20, spentAt: DateTime(2026, 4, 2)),
          _expense(title: 'Taxi', amount: 55, spentAt: DateTime(2026, 4, 3)),
        ],
      );

      final lines = const LineSplitter().convert(csv);
      expect(lines.length, 3);
      expect(lines[1], contains('Breakfast'));
      expect(lines[2], contains('Taxi'));
    });

    test('preserves Arabic merchant and category text in UTF-8 output', () {
      final bytes = exporter.buildCsvBytes(
        trip: _trip(name: 'رحلة جدة'),
        expenses: [
          _expense(
            title: 'مطعم البيك',
            category: 'طعام',
            note: 'وجبة سريعة',
          ),
        ],
      );

      final decoded = utf8.decode(bytes);
      expect(decoded, contains('رحلة جدة'));
      expect(decoded, contains('مطعم البيك'));
      expect(decoded, contains('طعام'));
      expect(decoded, contains('وجبة سريعة'));
    });

    test('preserves multi-currency values without conversion or merging', () {
      final csv = exporter.buildCsv(
        trip: _trip(),
        expenses: [
          _expense(
            title: 'Hotel',
            transactionAmount: 120,
            transactionCurrency: 'USD',
            billedAmount: 450,
            billedCurrency: 'SAR',
          ),
          _expense(
            title: 'Metro',
            transactionAmount: 80,
            transactionCurrency: 'AED',
            billedAmount: 82,
            billedCurrency: 'AED',
          ),
        ],
      );

      final lines = const LineSplitter().convert(csv);
      expect(lines[1], contains('120,USD,450,SAR'));
      expect(lines[2], contains('80,AED,82,AED'));
    });

    test('includes fees amount and fees currency when present', () {
      final csv = exporter.buildCsv(
        trip: _trip(),
        expenses: [
          _expense(
            title: 'Online order',
            feesAmount: 3.5,
            feesCurrency: 'SAR',
          ),
        ],
      );

      final lines = const LineSplitter().convert(csv);
      expect(lines[1], contains(',3.50,SAR,'));
    });

    test('escapes commas and quotes correctly', () {
      final csv = exporter.buildCsv(
        trip: _trip(name: 'Trip, "VIP"'),
        expenses: [
          _expense(
            title: 'Store, "Best"',
            note: 'Said "hello", then left',
          ),
        ],
      );

      final lines = const LineSplitter().convert(csv);
      expect(lines[1], contains('"Trip, ""VIP"""'));
      expect(lines[1], contains('"Store, ""Best"""'));
      expect(lines[1], contains('"Said ""hello"", then left"'));
    });
  });
}