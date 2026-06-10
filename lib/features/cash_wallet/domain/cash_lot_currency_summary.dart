/// Per-currency aggregation of open Cash Lots for the Remaining Cash Value
/// report section.
///
/// Produced by [CashLotRepository.computeLotCurrencySummaries].
/// The [TripReportCalculator] (or provider) converts these into
/// [RemainingCashValue] objects.
class CashLotCurrencySummary {
  const CashLotCurrencySummary({
    required this.currencyCode,
    required this.totalRemainingAmount,
    required this.totalHomeAmount,
    required this.homeCurrencyCode,
  });

  /// The trip (foreign) currency, e.g. `'JPY'`.
  final String currencyCode;

  /// SUM(remaining_amount) of all qualifying open lots.
  final double totalRemainingAmount;

  /// SUM(remaining_amount × effective_rate) across qualifying lots.
  /// The derived display rate = [totalHomeAmount] / [totalRemainingAmount].
  final double totalHomeAmount;

  /// Home-currency code used as the filter and the result label.
  final String homeCurrencyCode;
}
