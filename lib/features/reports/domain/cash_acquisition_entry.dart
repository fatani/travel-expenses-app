/// One row in the Cash Acquisition Summary.
///
/// Groups active (non-reversed) Cash Lots by [sourceType] + [originalCurrency].
/// Produced by [TripReportCalculator] from the `activeLots` parameter.
class CashAcquisitionEntry {
  const CashAcquisitionEntry({
    required this.sourceType,
    required this.originalCurrency,
    required this.totalOriginalAmount,
    this.totalHomeAmount,
    this.homeCurrency,
    required this.count,
  });

  /// Lot source, e.g. `'initial_cash'`, `'atm_withdrawal'`, `'exchange_in'`,
  /// `'cash_refund'`, `'manual_adjustment'`.
  final String sourceType;

  /// The foreign (trip) currency of the acquired cash, e.g. `'JPY'`.
  final String originalCurrency;

  /// SUM(lot.originalAmount) for all lots in this group.
  final double totalOriginalAmount;

  /// SUM(lot.homeCurrencyAmount) when every lot in the group shares the same
  /// [homeCurrency].  Null when home-currency data is absent or inconsistent.
  final double? totalHomeAmount;

  /// Home currency code shared by every lot in this group, or null when
  /// absent / inconsistent.
  final String? homeCurrency;

  /// Number of lots contributing to this entry.
  final int count;
}
