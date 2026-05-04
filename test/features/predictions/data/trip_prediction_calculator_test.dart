import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/predictions/data/trip_prediction_calculator.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

Trip _trip({
  DateTime? startDate,
  DateTime? endDate,
  double? budget,
  String baseCurrency = 'SAR',
}) {
  return Trip.create(
    id: 'trip-1',
    name: 'Trip',
    destination: 'Riyadh',
    baseCurrency: baseCurrency,
    startDate: startDate,
    endDate: endDate,
    budget: budget,
  );
}

Expense _expense({
  required double amount,
  required String currency,
  required DateTime spentAt,
}) {
  return Expense.create(
    tripId: 'trip-1',
    title: 'Expense',
    amount: amount,
    currencyCode: currency,
    transactionAmount: amount,
    transactionCurrency: currency,
    spentAt: spentAt,
    paymentMethod: 'Card',
    category: 'Food',
  );
}

void main() {
  const calculator = TripPredictionCalculator();

  final now = DateTime(2026, 4, 10);

  test('No expenses -> no prediction', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: const [],
      asOf: now,
    );

    expect(summary, isNull);
  });

  test('Less than 3 expenses -> no prediction', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 50, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
      ],
      asOf: now,
    );

    expect(summary, isNull);
  });

  test('Elapsed days < 2 -> no prediction', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 10),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 10)),
        _expense(amount: 50, currency: 'SAR', spentAt: DateTime(2026, 4, 10)),
        _expense(amount: 80, currency: 'SAR', spentAt: DateTime(2026, 4, 10)),
      ],
      asOf: now,
    );

    expect(summary, isNull);
  });

  test('Valid burn rate calculation', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 50, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 150, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(summary!.elapsedDays, 10);
    // Weighted daily burn across [100, 50, 150] -> (100*1 + 50*2 + 150*3) / 6 = 108.333...
    expect(summary.burnRateByCurrency['SAR'], closeTo(108.3333, 0.0001));
  });

  test('Valid forecast calculation', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 13),
      ),
      expenses: [
        _expense(amount: 100, currency: 'CNY', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 200, currency: 'CNY', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 150, currency: 'CNY', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(summary!.remainingDays, 3);
    // Weighted burn [100, 200, 150] -> (100*1 + 200*2 + 150*3) / 6 = 158.333...
    // Forecast = 450 + (158.333... * 3) = 925
    expect(summary.forecastTotalByCurrency['CNY'], closeTo(925, 0.0001));
  });

  test('Multi-currency forecast stays separate', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 13),
      ),
      expenses: [
        _expense(amount: 100, currency: 'CNY', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 200, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 150, currency: 'CNY', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(summary!.forecastTotalByCurrency.keys.toSet(), {'CNY', 'SAR'});
    expect(summary.forecastTotalByCurrency.length, 2);
  });

  test('Trip ended -> no prediction', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 20),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 3, 2)),
        _expense(amount: 200, currency: 'SAR', spentAt: DateTime(2026, 3, 3)),
        _expense(amount: 300, currency: 'SAR', spentAt: DateTime(2026, 3, 4)),
      ],
      asOf: now,
    );

    expect(summary, isNull);
  });

  test('Trip end date reached -> no prediction', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 10),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 200, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 300, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(summary, isNull);
  });

  test('Budget warning appears only when forecast exceeds budget', () {
    final warningSummary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 13),
        budget: 500,
        baseCurrency: 'SAR',
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 200, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 150, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(warningSummary, isNotNull);
    expect(warningSummary!.hasBudgetWarning, isTrue);
    expect(warningSummary.budgetWarningMessage, isNotNull);

    final safeSummary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 13),
        budget: 2000,
        baseCurrency: 'SAR',
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 200, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 150, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(safeSummary, isNotNull);
    expect(safeSummary!.hasBudgetWarning, isFalse);
    expect(safeSummary.budgetWarningMessage, isNull);
  });

  test('Increasing trend -> weighted burn rate higher than simple average', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        _expense(amount: 50, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 60, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 200, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    final simpleAverage = (50 + 60 + 200) / 3;
    expect(summary!.burnRateByCurrency['SAR']!, greaterThan(simpleAverage));
  });

  test('Decreasing trend -> weighted burn rate lower than simple average', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        _expense(amount: 200, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 60, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 50, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    final simpleAverage = (200 + 60 + 50) / 3;
    expect(summary!.burnRateByCurrency['SAR']!, lessThan(simpleAverage));
  });

  test('Flat trend -> weighted burn rate equals simple average', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(summary!.burnRateByCurrency['SAR'], closeTo(100, 0.0001));
  });

  test('Fewer than 3 expense-days -> fallback to simple average by elapsed days', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 50, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 150, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    // 2 unique expense-days only -> fallback to currentSpent / elapsedDays = 300 / 10 = 30
    expect(summary!.burnRateByCurrency['SAR'], closeTo(30, 0.0001));
  });
}
