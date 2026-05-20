class CashEffectiveRateCalculator {
  const CashEffectiveRateCalculator._();

  static double? calculate(Iterable<Map<String, Object?>> rows) {
    double totalCash = 0;
    double totalHome = 0;

    for (final row in rows) {
      final cash = (row['amount'] as num?)?.toDouble() ?? 0;
      final home = (row['home_currency_amount'] as num?)?.toDouble() ?? 0;
      if (cash > 0 && home > 0) {
        totalCash += cash;
        totalHome += home;
      }
    }

    if (totalCash <= 0 || totalHome <= 0) {
      return null;
    }

    return totalHome / totalCash;
  }
}