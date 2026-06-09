import '../../cash_wallet/domain/trip_cash_balance.dart';

/// The cost-basis value of a single remaining cash currency balance.
///
/// Produced by [TripReportCalculator] for every currency bucket that has:
/// - a positive balance,
/// - a known effective acquisition rate, and
/// - a known home currency.
///
/// [homeAmount] = [balanceAmount] × [effectiveRate]
class RemainingCashValue {
  const RemainingCashValue({
    required this.currencyCode,
    required this.balanceAmount,
    required this.effectiveRate,
    required this.homeAmount,
    required this.homeCurrency,
  });

  /// The trip (foreign) currency of the remaining cash, e.g. `'CNY'`.
  final String currencyCode;

  /// Remaining cash in [currencyCode]. Always positive.
  final double balanceAmount;

  /// Weighted-average acquisition rate: home-currency units per 1 unit of
  /// [currencyCode]. Derived from all non-reversed cash inflows that recorded
  /// a [homeCurrencyAmount].
  final double effectiveRate;

  /// Cost basis in [homeCurrency]: [balanceAmount] × [effectiveRate].
  final double homeAmount;

  /// Home currency code, e.g. `'SAR'`.
  final String homeCurrency;
}

/// Input record that [TripReportCalculator] uses to produce a
/// [RemainingCashValue].
///
/// Callers are responsible for fetching the raw data:
/// - [balance] from `CashWalletRepository.getBalancesByTrip()`
/// - [effectiveRate] from `CashWalletRepository.getEffectiveCashRate()`
/// - [homeCurrency] from the trip's `homeCurrencySnapshot`
///
/// The calculator applies filters (null rate, null homeCurrency, non-positive
/// balance) and performs the multiplication internally.
class CashBalanceRateInput {
  const CashBalanceRateInput({
    required this.balance,
    this.effectiveRate,
    this.homeCurrency,
  });

  /// Current balance row for one currency.
  final TripCashBalance balance;

  /// Weighted-average acquisition rate. `null` when no usable inflow data
  /// exists (e.g. user never entered an FX rate for any inflow).
  final double? effectiveRate;

  /// Home currency code. `null` when the trip has no home-currency snapshot.
  final String? homeCurrency;
}
