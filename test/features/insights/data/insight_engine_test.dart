import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/insights/data/insight_engine.dart';
import 'package:travel_expenses/features/insights/domain/insight.dart';

Expense _expense({
  required double amount,
  required DateTime spentAt,
  String currency = 'SAR',
  String? category,
  String? paymentNetwork,
  String? paymentChannel,
  double? feesAmount,
}) {
  return Expense.create(
    tripId: 'trip-1',
    title: 'Expense',
    amount: amount,
    currencyCode: currency,
    category: category,
    paymentMethod: 'Card',
    paymentNetwork: paymentNetwork,
    paymentChannel: paymentChannel,
    feesAmount: feesAmount,
    feesCurrency: currency,
    spentAt: spentAt,
  );
}

void main() {
  const engine = InsightEngine();

  test('no expenses returns no insights', () {
    final insights = engine.build(const []);
    expect(insights, isEmpty);
  });

  test('fewer than five expenses returns no insights', () {
    final insights = engine.build([
      _expense(
        amount: 100,
        spentAt: DateTime(2026, 1, 1),
        category: 'Food',
      ),
      _expense(
        amount: 110,
        spentAt: DateTime(2026, 1, 2),
        category: 'Food',
      ),
      _expense(
        amount: 120,
        spentAt: DateTime(2026, 1, 3),
        category: 'Food',
      ),
      _expense(
        amount: 130,
        spentAt: DateTime(2026, 1, 4),
        category: 'Food',
      ),
    ]);

    expect(insights, isEmpty);
  });

  test('spike scenario generates spike insight', () {
    final insights = engine.build([
      _expense(
        amount: 40,
        spentAt: DateTime(2026, 1, 1),
        category: 'Food',
      ),
      _expense(
        amount: 30,
        spentAt: DateTime(2026, 1, 2),
        category: 'Transport',
      ),
      _expense(
        amount: 220,
        spentAt: DateTime(2026, 1, 3),
        category: 'Shopping',
      ),
      _expense(
        amount: 200,
        spentAt: DateTime(2026, 1, 4),
        category: 'Shopping',
      ),
      _expense(
        amount: 210,
        spentAt: DateTime(2026, 1, 5),
        category: 'Shopping',
      ),
    ]);

    expect(insights.map((i) => i.type), contains(InsightType.spike));
    final spike = insights.firstWhere((i) => i.type == InsightType.spike);
    expect(spike.percentage, isNotNull);
    expect(insights.length, lessThanOrEqualTo(2));
  });

  test('spike percentage is omitted when first-half average is very small', () {
    final insights = engine.build([
      _expense(
        amount: 5,
        spentAt: DateTime(2026, 5, 1),
        category: 'Food',
      ),
      _expense(
        amount: 6,
        spentAt: DateTime(2026, 5, 2),
        category: 'Food',
      ),
      _expense(
        amount: 30,
        spentAt: DateTime(2026, 5, 3),
        category: 'Shopping',
      ),
      _expense(
        amount: 35,
        spentAt: DateTime(2026, 5, 4),
        category: 'Shopping',
      ),
      _expense(
        amount: 40,
        spentAt: DateTime(2026, 5, 5),
        category: 'Shopping',
      ),
    ]);

    final spike = insights.firstWhere((i) => i.type == InsightType.spike);
    expect(spike.percentage, isNull);
  });

  test('dominant category generates category drift insight', () {
    final insights = engine.build([
      _expense(
        amount: 200,
        spentAt: DateTime(2026, 2, 1),
        category: 'Food',
      ),
      _expense(
        amount: 180,
        spentAt: DateTime(2026, 2, 2),
        category: 'Food',
      ),
      _expense(
        amount: 60,
        spentAt: DateTime(2026, 2, 3),
        category: 'Transport',
      ),
      _expense(
        amount: 70,
        spentAt: DateTime(2026, 2, 4),
        category: 'Food',
      ),
      _expense(
        amount: 60,
        spentAt: DateTime(2026, 2, 5),
        category: 'Shopping',
      ),
    ]);

    expect(insights.map((i) => i.type), contains(InsightType.categoryDrift));
    expect(insights.length, lessThanOrEqualTo(2));
  });

  test('spike insight includes top contributing trip attribution', () {
    final insights = engine.build(
      [
        _expense(
          amount: 30,
          spentAt: DateTime(2026, 3, 1),
          category: 'Food',
        ).copyWith(tripId: 'trip-a'),
        _expense(
          amount: 40,
          spentAt: DateTime(2026, 3, 2),
          category: 'Food',
        ).copyWith(tripId: 'trip-b'),
        _expense(
          amount: 120,
          spentAt: DateTime(2026, 3, 3),
          category: 'Shopping',
        ).copyWith(tripId: 'trip-b'),
        _expense(
          amount: 150,
          spentAt: DateTime(2026, 3, 4),
          category: 'Shopping',
        ).copyWith(tripId: 'trip-b'),
        _expense(
          amount: 90,
          spentAt: DateTime(2026, 3, 5),
          category: 'Transport',
        ).copyWith(tripId: 'trip-a'),
      ],
      tripNamesById: const {
        'trip-a': 'Alpha',
        'trip-b': 'Beta',
      },
    );

    final spike = insights.firstWhere((i) => i.type == InsightType.spike);
    expect(spike.tripId, 'trip-b');
    expect(spike.tripName, 'Beta');
    expect(spike.contributorTripCount, greaterThanOrEqualTo(1));
  });

  test('category drift insight includes top contributing trip attribution', () {
    final insights = engine.build(
      [
        _expense(
          amount: 200,
          spentAt: DateTime(2026, 4, 1),
          category: 'Food',
        ).copyWith(tripId: 'trip-a'),
        _expense(
          amount: 150,
          spentAt: DateTime(2026, 4, 2),
          category: 'Food',
        ).copyWith(tripId: 'trip-a'),
        _expense(
          amount: 120,
          spentAt: DateTime(2026, 4, 3),
          category: 'Food',
        ).copyWith(tripId: 'trip-b'),
        _expense(
          amount: 60,
          spentAt: DateTime(2026, 4, 4),
          category: 'Transport',
        ).copyWith(tripId: 'trip-b'),
        _expense(
          amount: 40,
          spentAt: DateTime(2026, 4, 5),
          category: 'Shopping',
        ).copyWith(tripId: 'trip-c'),
      ],
      tripNamesById: const {
        'trip-a': 'Alpha',
        'trip-b': 'Beta',
        'trip-c': 'Gamma',
      },
    );

    final drift = insights.firstWhere(
      (i) => i.type == InsightType.categoryDrift,
    );
    expect(drift.tripId, 'trip-a');
    expect(drift.tripName, 'Alpha');
    expect(drift.category, 'Food');
  });

  test('Case A: two categories only should not generate category drift', () {
    final insights = engine.build([
      _expense(
        amount: 300,
        spentAt: DateTime(2026, 6, 1),
        category: 'Transport',
      ),
      _expense(
        amount: 300,
        spentAt: DateTime(2026, 6, 2),
        category: 'Transport',
      ),
      _expense(
        amount: 200,
        spentAt: DateTime(2026, 6, 3),
        category: 'Other',
      ),
      _expense(
        amount: 200,
        spentAt: DateTime(2026, 6, 4),
        category: 'Other',
      ),
      _expense(
        amount: 100,
        spentAt: DateTime(2026, 6, 5),
        category: 'Transport',
      ),
    ]);

    expect(insights.where((i) => i.type == InsightType.categoryDrift), isEmpty);
  });

  test('Case B: three categories with 50%+ top category should generate category drift', () {
    final insights = engine.build([
      _expense(
        amount: 300,
        spentAt: DateTime(2026, 7, 1),
        category: 'Transport',
      ),
      _expense(
        amount: 400,
        spentAt: DateTime(2026, 7, 2),
        category: 'Transport',
      ),
      _expense(
        amount: 200,
        spentAt: DateTime(2026, 7, 3),
        category: 'Food',
      ),
      _expense(
        amount: 100,
        spentAt: DateTime(2026, 7, 4),
        category: 'Shopping',
      ),
      _expense(
        amount: 50,
        spentAt: DateTime(2026, 7, 5),
        category: 'Food',
      ),
    ]);

    final categoryInsight = insights.where((i) => i.type == InsightType.categoryDrift);
    expect(categoryInsight, isNotEmpty);
    expect(categoryInsight.first.category, 'Transport');
    expect(categoryInsight.first.percentage, greaterThanOrEqualTo(50));
  });

  test('Case C: spike should not generate with insufficient split (3 expenses)', () {
    final insights = engine.build([
      _expense(
        amount: 50,
        spentAt: DateTime(2026, 8, 1),
        category: 'Food',
      ),
      _expense(
        amount: 60,
        spentAt: DateTime(2026, 8, 2),
        category: 'Transport',
      ),
      _expense(
        amount: 200,
        spentAt: DateTime(2026, 8, 3),
        category: 'Shopping',
      ),
    ]);

    expect(insights.where((i) => i.type == InsightType.spike), isEmpty);
  });

  test('Case D: spike should generate with valid 6-expense split and higher second half average', () {
    final insights = engine.build([
      _expense(
        amount: 40,
        spentAt: DateTime(2026, 9, 1),
        category: 'Food',
      ),
      _expense(
        amount: 50,
        spentAt: DateTime(2026, 9, 2),
        category: 'Transport',
      ),
      _expense(
        amount: 45,
        spentAt: DateTime(2026, 9, 3),
        category: 'Food',
      ),
      _expense(
        amount: 120,
        spentAt: DateTime(2026, 9, 4),
        category: 'Shopping',
      ),
      _expense(
        amount: 130,
        spentAt: DateTime(2026, 9, 5),
        category: 'Shopping',
      ),
      _expense(
        amount: 140,
        spentAt: DateTime(2026, 9, 6),
        category: 'Transport',
      ),
    ]);

    final spikeInsights = insights.where((i) => i.type == InsightType.spike);
    expect(spikeInsights, isNotEmpty);
    expect(spikeInsights.first.multiplier, greaterThanOrEqualTo(1.5));
  });
}
