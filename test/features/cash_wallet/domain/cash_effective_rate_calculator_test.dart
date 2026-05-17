import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_effective_rate_calculator.dart';

void main() {
  test('calculates weighted average using usable inflow rows only', () {
    final rate = CashEffectiveRateCalculator.calculate([
      {'amount': 100, 'home_currency_amount': 10},
      {'amount': 50, 'home_currency_amount': 5},
      {'amount': 0, 'home_currency_amount': 999},
      {'amount': 20, 'home_currency_amount': 0},
    ]);

    expect(rate, closeTo(0.1, 0.000001));
  });

  test('returns null when no usable inflow rows exist', () {
    expect(CashEffectiveRateCalculator.calculate([]), isNull);
    expect(
      CashEffectiveRateCalculator.calculate([
        {'amount': 0, 'home_currency_amount': 10},
      ]),
      isNull,
    );
  });
}