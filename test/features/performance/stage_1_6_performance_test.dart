import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_list_display.dart';
import 'package:travel_expenses/features/expenses/presentation/quick_add_recent_merchants.dart';
import 'package:travel_expenses/features/export/data/trip_csv_exporter.dart';
import 'package:travel_expenses/features/export/presentation/trip_export_guard.dart';
import 'package:travel_expenses/features/global_reports/data/global_report_calculator.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

Expense _expense({
  required int index,
  required String tripId,
  String title = 'Shop',
  String category = 'Food',
  String paymentMethod = 'Cash',
  double amount = 10,
  String currency = 'USD',
  DateTime? spentAt,
  String? note,
}) {
  return Expense.create(
    id: 'exp-$index',
    tripId: tripId,
    title: title,
    amount: amount,
    currencyCode: currency,
    transactionAmount: amount,
    transactionCurrency: currency,
    category: category,
    paymentMethod: paymentMethod,
    spentAt: spentAt ?? DateTime(2026, 5, 1).add(Duration(hours: index)),
    note: note,
  );
}

List<Expense> _largeExpenseList({
  required String tripId,
  int count = 1200,
  String currency = 'USD',
}) {
  return List<Expense>.generate(
    count,
    (index) => _expense(
      index: index,
      tripId: tripId,
      title: 'Merchant ${index % 50}',
      amount: (index % 100) + 1,
      currency: currency,
      category: index.isEven ? 'Food' : 'Transport',
      paymentMethod: index % 3 == 0 ? 'Card' : 'Cash',
      note: index % 17 == 0 ? 'search-token-$index' : null,
    ),
  );
}

void main() {
  group('Stage 1.6 performance helpers', () {
    const tripId = 'trip-scale';

    test('filters and sorts 1,000+ expenses correctly', () {
      final expenses = _largeExpenseList(tripId: tripId);

      final filtered = ExpenseListDisplay.filteredAndSorted(
        expenses: expenses,
        searchQuery: 'search-token-34',
        category: 'Food',
        paymentMethod: 'Cash',
        sort: ExpenseListSort.highestAmount,
      );

      expect(filtered, isNotEmpty);
      expect(filtered.every((e) => e.category == 'Food'), isTrue);
      expect(filtered.every((e) => e.paymentMethod == 'Cash'), isTrue);
      expect(
        filtered.every((e) => e.note?.contains('search-token-34') ?? false),
        isTrue,
      );
      for (var i = 1; i < filtered.length; i++) {
        expect(
          filtered[i - 1].transactionAmount >= filtered[i].transactionAmount,
          isTrue,
        );
      }
    });

    test('context total stays safe for single and mixed currency lists', () {
      final single = _largeExpenseList(tripId: tripId, count: 500, currency: 'EUR');
      final sole = ExpenseListDisplay.soleTransactionCurrency(single);
      expect(sole, 'EUR');
      expect(
        ExpenseListDisplay.soleCurrencyTotal(single, 'EUR'),
        greaterThan(0),
      );
      expect(
        ExpenseListDisplay.hidesContextTotal(
          searchQuery: '',
          category: null,
          paymentMethod: null,
        ),
        isFalse,
      );

      final mixed = [
        ..._largeExpenseList(tripId: tripId, count: 200, currency: 'USD'),
        ..._largeExpenseList(tripId: tripId, count: 200, currency: 'THB'),
      ];
      expect(ExpenseListDisplay.soleTransactionCurrency(mixed), isNull);
    });

    test('deriveQuickAddSnapshot handles large lists in one pass', () {
      final expenses = _largeExpenseList(tripId: tripId, count: 2000);
      expenses[1500] = _expense(
        index: 99999,
        tripId: tripId,
        title: 'Latest Merchant',
        spentAt: DateTime(2026, 12, 31),
      );

      final snapshot = deriveQuickAddSnapshot(expenses, maxCount: 7);

      expect(snapshot.mostRecent?.title, 'Latest Merchant');
      expect(snapshot.recentMerchants.length, lessThanOrEqualTo(7));
      expect(snapshot.recentMerchants.first, 'Latest Merchant');
    });

    test('trip report calculator handles large per-currency data', () {
      final expenses = [
        ..._largeExpenseList(tripId: tripId, count: 800, currency: 'USD'),
        ..._largeExpenseList(tripId: tripId, count: 400, currency: 'EUR'),
      ];

      const calculator = TripReportCalculator();
      final summary = calculator.calculate(
        tripId: tripId,
        tripName: 'Scale Trip',
        expenses: expenses,
      );

      expect(summary.totalExpenseCount, 1200);
      expect(summary.byTransactionCurrency.length, 2);
      final currencies = summary.byTransactionCurrency
          .map((bucket) => bucket.currency)
          .toSet();
      expect(currencies, containsAll(['USD', 'EUR']));
    });

    test('global report suppresses unsafe mixed-currency leaders at scale', () {
      final trips = List<Trip>.generate(
        50,
        (index) => Trip.create(
          id: 'trip-$index',
          name: 'Trip $index',
          destination: 'City',
          baseCurrency: 'USD',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 10),
        ),
      );

      final expenses = <Expense>[];
      for (final trip in trips) {
        expenses.addAll(
          _largeExpenseList(tripId: trip.id, count: 20, currency: 'USD'),
        );
        expenses.addAll(
          _largeExpenseList(tripId: trip.id, count: 10, currency: 'EUR'),
        );
      }

      const calculator = GlobalReportCalculator();
      final summary = calculator.calculate(
        trips: trips,
        expenses: expenses,
        isArabic: false,
      );

      expect(summary.totalTrips, 50);
      expect(summary.totalExpenseCount, 50 * 30);
      expect(summary.totalBilledByCurrency.length, greaterThan(1));
      expect(summary.topCategory, isNull);
      expect(summary.uniqueTransactionCurrencyCount, greaterThan(1));
    });

    test('CSV export preserves original amounts and currencies at scale', () {
      final trip = Trip.create(
        id: tripId,
        name: 'Export Trip',
        destination: 'Test',
        baseCurrency: 'USD',
      );
      final expenses = [
        _expense(index: 1, tripId: tripId, amount: 42.5, currency: 'USD'),
        _expense(index: 2, tripId: tripId, amount: 99, currency: 'EUR'),
      ];

      final csv = TripCsvExporter().buildCsv(trip: trip, expenses: expenses);

      expect(csv, contains('42.5'));
      expect(csv, contains('USD'));
      expect(csv, contains('99'));
      expect(csv, contains('EUR'));
    });

    test('TripExportGuard blocks duplicate exports per trip and format', () {
      expect(
        TripExportGuard.tryAcquire(tripId: 't1', formatKey: 'csv'),
        isTrue,
      );
      expect(
        TripExportGuard.tryAcquire(tripId: 't1', formatKey: 'csv'),
        isFalse,
      );
      expect(
        TripExportGuard.tryAcquire(tripId: 't1', formatKey: 'pdf'),
        isTrue,
      );
      TripExportGuard.release(tripId: 't1', formatKey: 'csv');
      expect(
        TripExportGuard.tryAcquire(tripId: 't1', formatKey: 'csv'),
        isTrue,
      );
      TripExportGuard.release(tripId: 't1', formatKey: 'csv');
      TripExportGuard.release(tripId: 't1', formatKey: 'pdf');
    });
  });
}
