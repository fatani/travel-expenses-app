import '../../cash_wallet/domain/cash_lot.dart';
import '../domain/remaining_cash_value.dart';

/// Aggregates open [lots] into per-currency [RemainingCashValue] rows.
///
/// Used by [tripReportProvider] to build net-trip-cost inputs that may
/// exclude certain lot source types (e.g. `cash_refund`) while keeping full
/// remaining-cash values for display.
List<RemainingCashValue> buildRemainingCashValuesFromLots({
  required List<CashLot> lots,
  required String homeCurrencyCode,
  Set<String> excludeSourceTypes = const {},
}) {
  final normalizedHome = homeCurrencyCode.trim().toUpperCase();
  final byCurrency = <String, ({double remaining, double home})>{};

  for (final lot in lots) {
    if (lot.isReversed) continue;
    if (excludeSourceTypes.contains(lot.sourceType)) continue;
    if (lot.remainingAmount <= 0) continue;
    final rate = lot.effectiveRate;
    final lotHomeCode = lot.homeCurrencyCode;
    if (rate == null || lotHomeCode == null) continue;
    if (lotHomeCode.trim().toUpperCase() != normalizedHome) continue;

    final currency = lot.currencyCode.trim().toUpperCase();
    final homeContribution = lot.remainingAmount * rate;
    final current = byCurrency[currency];
    if (current == null) {
      byCurrency[currency] = (
        remaining: lot.remainingAmount,
        home: homeContribution,
      );
    } else {
      byCurrency[currency] = (
        remaining: current.remaining + lot.remainingAmount,
        home: current.home + homeContribution,
      );
    }
  }

  return byCurrency.entries
      .map(
        (e) => RemainingCashValue(
          currencyCode: e.key,
          balanceAmount: e.value.remaining,
          effectiveRate: e.value.home / e.value.remaining,
          homeAmount: e.value.home,
          homeCurrency: normalizedHome,
        ),
      )
      .toList();
}
