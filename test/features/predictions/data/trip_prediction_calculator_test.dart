import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/predictions/data/trip_prediction_calculator.dart';
import 'package:travel_expenses/features/predictions/domain/trip_prediction_summary.dart';
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
    expect(summary!.elapsedDays, 9);
    expect(summary.totalSpendByCurrency['SAR'], 300);
    expect(summary.burnRateByCurrency['SAR'], closeTo(33.3333, 0.0001));
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
    expect(summary.forecastTotalByCurrency['CNY'], closeTo(600, 0.0001));
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

  test('Trip ended still returns summary and hides future projection in UI layer', () {
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

    expect(summary, isNotNull);
    expect(summary!.isTripEnded, isTrue);
    expect(summary.remainingDays, 0);
    expect(summary.elapsedDays, greaterThanOrEqualTo(2));
  });

  test('Trip end date reached returns summary with non-negative remaining days', () {
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

    expect(summary, isNotNull);
    expect(summary!.isTripEnded, isFalse);
    expect(summary.remainingDays, 0);
  });

  test('Elapsed days never becomes negative', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 10),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 5, 1)),
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 5, 2)),
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 5, 3)),
      ],
      asOf: DateTime(2026, 4, 28),
    );

    expect(summary, isNull);
  });

  test('Remaining days never becomes negative for ended trips', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 5),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 3, 1)),
        _expense(amount: 150, currency: 'SAR', spentAt: DateTime(2026, 3, 2)),
        _expense(amount: 200, currency: 'SAR', spentAt: DateTime(2026, 3, 3)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(summary!.remainingDays, 0);
  });

  test('Stable spend does not create a spike action', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 5)),
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 6)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(
      summary!.actions.any((action) => action.type == TripDecisionActionType.spendSpike),
      isFalse,
    );
  });

  test('High spike adds spike recommendation', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 25),
      ),
      expenses: [
        _expense(amount: 40, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 50, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 220, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
        _expense(amount: 240, currency: 'SAR', spentAt: DateTime(2026, 4, 5)),
        _expense(amount: 250, currency: 'SAR', spentAt: DateTime(2026, 4, 6)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(
      summary!.actions.any((action) => action.type == TripDecisionActionType.spendSpike),
      isTrue,
    );
  });

  test('Category below 50 percent does not create optimization action', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 1',
          amount: 120,
          currencyCode: 'SAR',
          transactionAmount: 120,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 2),
          paymentMethod: 'Card',
          category: 'Food',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 2',
          amount: 100,
          currencyCode: 'SAR',
          transactionAmount: 100,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 3),
          paymentMethod: 'Card',
          category: 'Transport',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 3',
          amount: 90,
          currencyCode: 'SAR',
          transactionAmount: 90,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 4),
          paymentMethod: 'Card',
          category: 'Shopping',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 4',
          amount: 80,
          currencyCode: 'SAR',
          transactionAmount: 80,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 5),
          paymentMethod: 'Card',
          category: 'Food',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 5',
          amount: 70,
          currencyCode: 'SAR',
          transactionAmount: 70,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 6),
          paymentMethod: 'Card',
          category: 'Transport',
        ),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(
      summary!.actions.any(
        (action) => action.type == TripDecisionActionType.categoryConcentration,
      ),
      isFalse,
    );
  });

  test('Category above 50 percent shows optimization action', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 20),
      ),
      expenses: [
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 1',
          amount: 200,
          currencyCode: 'SAR',
          transactionAmount: 200,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 2),
          paymentMethod: 'Card',
          category: 'Food',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 2',
          amount: 180,
          currencyCode: 'SAR',
          transactionAmount: 180,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 3),
          paymentMethod: 'Card',
          category: 'Food',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 3',
          amount: 60,
          currencyCode: 'SAR',
          transactionAmount: 60,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 4),
          paymentMethod: 'Card',
          category: 'Transport',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 4',
          amount: 70,
          currencyCode: 'SAR',
          transactionAmount: 70,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 5),
          paymentMethod: 'Card',
          category: 'Food',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 5',
          amount: 60,
          currencyCode: 'SAR',
          transactionAmount: 60,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 6),
          paymentMethod: 'Card',
          category: 'Shopping',
        ),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    final categoryAction = summary!.actions.firstWhere(
      (action) => action.type == TripDecisionActionType.categoryConcentration,
    );
    expect(categoryAction.category, 'Food');
  });

  test('High burn rate shows warning', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 25),
      ),
      expenses: [
        _expense(amount: 100, currency: 'SAR', spentAt: DateTime(2026, 4, 2)),
        _expense(amount: 120, currency: 'SAR', spentAt: DateTime(2026, 4, 3)),
        _expense(amount: 140, currency: 'SAR', spentAt: DateTime(2026, 4, 4)),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(summary!.actions.first.type, TripDecisionActionType.burnRisk);
  });

  test('Priority system keeps max two actions', () {
    final summary = calculator.calculate(
      trip: _trip(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 25),
      ),
      expenses: [
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 1',
          amount: 40,
          currencyCode: 'SAR',
          transactionAmount: 40,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 2),
          paymentMethod: 'Card',
          category: 'Food',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 2',
          amount: 50,
          currencyCode: 'SAR',
          transactionAmount: 50,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 3),
          paymentMethod: 'Card',
          category: 'Transport',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 3',
          amount: 220,
          currencyCode: 'SAR',
          transactionAmount: 220,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 4),
          paymentMethod: 'Card',
          category: 'Food',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 4',
          amount: 240,
          currencyCode: 'SAR',
          transactionAmount: 240,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 5),
          paymentMethod: 'Card',
          category: 'Food',
        ),
        Expense.create(
          tripId: 'trip-1',
          title: 'Expense 5',
          amount: 250,
          currencyCode: 'SAR',
          transactionAmount: 250,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 6),
          paymentMethod: 'Card',
          category: 'Shopping',
        ),
      ],
      asOf: now,
    );

    expect(summary, isNotNull);
    expect(summary!.actions, hasLength(2));
    expect(summary.actions[0].type, TripDecisionActionType.burnRisk);
    expect(summary.actions[1].type, TripDecisionActionType.spendSpike);
  });
}
