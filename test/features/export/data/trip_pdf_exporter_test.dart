import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:travel_expenses/features/export/data/trip_pdf_exporter.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

Trip _trip({
  String name = 'Business Trip',
  String destination = 'Riyadh',
}) {
  return Trip.create(
    id: 'trip-1',
    name: name,
    destination: destination,
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
  double? feesAmount,
  String? feesCurrency,
}) {
  return Expense.create(
    tripId: 'trip-1',
    title: title,
    amount: amount,
    currencyCode: currency,
    transactionAmount: transactionAmount,
    transactionCurrency: transactionCurrency,
    feesAmount: feesAmount,
    feesCurrency: feesCurrency,
    paymentMethod: 'Card',
    paymentNetwork: paymentNetwork,
    paymentChannel: paymentChannel,
    category: category,
    spentAt: spentAt ?? DateTime(2026, 4, 2),
  );
}

void main() {
  group('TripPdfExporter', () {
    late TripPdfExporter exporter;

    setUp(() {
      // Inject the built-in Helvetica font so tests don't require asset loading.
      exporter = TripPdfExporter(arabicFont: pw.Font.helvetica());
    });

    test('generates non-empty PDF bytes for a single expense', () async {
      final bytes = await exporter.buildPdfBytes(
        trip: _trip(),
        expenses: [_expense()],
      );
      expect(bytes, isNotEmpty);
      // Valid PDF starts with %PDF
      expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
    });

    test('generates PDF with multi-currency values without crashing', () async {
      final bytes = await exporter.buildPdfBytes(
        trip: _trip(),
        expenses: [
          _expense(
            transactionAmount: 120,
            transactionCurrency: 'USD',
            currency: 'USD',
          ),
          _expense(
            transactionAmount: 450,
            transactionCurrency: 'SAR',
            currency: 'SAR',
          ),
          _expense(
            transactionAmount: 80,
            transactionCurrency: 'AED',
            currency: 'AED',
          ),
        ],
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
    });

    test('includes fees when present without crashing', () async {
      final bytes = await exporter.buildPdfBytes(
        trip: _trip(),
        expenses: [
          _expense(feesAmount: 3.5, feesCurrency: 'SAR'),
          _expense(feesAmount: 1.25, feesCurrency: 'USD', currency: 'USD'),
        ],
      );
      expect(bytes, isNotEmpty);
    });

    test('handles null optional fields without crashing', () async {
      final bytes = await exporter.buildPdfBytes(
        trip: _trip(destination: ''),
        expenses: [
          _expense(
            category: null,
            paymentChannel: null,
            paymentNetwork: null,
          ),
        ],
      );
      expect(bytes, isNotEmpty);
    });

    test('Arabic trip name does not crash PDF generation', () async {
      final bytes = await exporter.buildPdfBytes(
        trip: _trip(name: 'رحلة فيتنام 2025', destination: 'فيتنام'),
        expenses: [_expense(title: 'مطعم', category: 'طعام')],
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
    });

    test('trip with no dates generates PDF without crashing', () async {
      final tripNoDates = Trip.create(
        id: 'trip-2',
        name: 'Open Trip',
        destination: 'Unknown',
        baseCurrency: 'USD',
      );
      final bytes = await exporter.buildPdfBytes(
        trip: tripNoDates,
        expenses: [_expense()],
      );
      expect(bytes, isNotEmpty);
    });

    test('exports PDF to file and returns valid ExportResult', () async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_test_');
      try {
        final testExporter = TripPdfExporter(
          directoryProvider: () async => tempDir,
          arabicFont: pw.Font.helvetica(),
        );

        final result = await testExporter.exportTrip(
          trip: _trip(name: 'Vietnam Trip'),
          expenses: [_expense(), _expense(title: 'Taxi')],
        );

        expect(result.fileName, endsWith('.pdf'));
        expect(result.fileName, contains('Summary'));
        expect(result.fileName, contains('Vietnam_Trip'));
        expect(result.rowCount, equals(2));
        expect(File(result.filePath).existsSync(), isTrue);
        expect(File(result.filePath).lengthSync(), greaterThan(0));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
