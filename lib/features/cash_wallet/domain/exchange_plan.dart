import 'lot_consumption_plan.dart';

/// An immutable value object describing a planned currency exchange.
///
/// Returned by [CurrencyExchangeEngine.planExchange].  No DB writes have
/// occurred when this object is returned — it is a pure plan.
///
/// ## Cost-basis transfer
/// [transferredHomeAmount] is the sum of the home-currency cost basis consumed
/// from the source lots (FIFO order).  This value is carried forward as the
/// cost basis of the destination lot, preserving historical cost rather than
/// re-marking to market.
///
/// If every source lot has no cost-basis snapshot ([LotConsumptionPlan.homeAmount]
/// is null for all), then [transferredHomeAmount], [homeCurrencyCode], and
/// [destinationEffectiveRate] are all null.
///
/// If at least one source lot has a cost basis the partial sum is used.
class ExchangePlan {
  const ExchangePlan({
    required this.fromCurrencyCode,
    required this.fromAmount,
    required this.toCurrencyCode,
    required this.toAmount,
    required this.exchangeRate,
    this.transferredHomeAmount,
    this.homeCurrencyCode,
    this.destinationEffectiveRate,
    required this.sourcePlans,
  });

  /// The currency being sold / drawn from (upper-case).
  final String fromCurrencyCode;

  /// The amount sold / consumed from the wallet.
  final double fromAmount;

  /// The currency being acquired (upper-case).
  final String toCurrencyCode;

  /// The amount acquired (credited to the wallet).
  final double toAmount;

  /// Spot rate at time of exchange: [toAmount] / [fromAmount].
  final double exchangeRate;

  /// Sum of [LotConsumptionPlan.homeAmount] across all source lots.
  /// Null only when every source lot lacks a cost-basis snapshot.
  final double? transferredHomeAmount;

  /// Home-currency code matching [transferredHomeAmount].
  final String? homeCurrencyCode;

  /// Effective cost rate for the destination lot:
  /// [transferredHomeAmount] / [toAmount].
  /// Null when [transferredHomeAmount] is null.
  final double? destinationEffectiveRate;

  /// FIFO source lot consumption plan (one entry per lot drawn from).
  final List<LotConsumptionPlan> sourcePlans;

  @override
  String toString() => 'ExchangePlan('
      '$fromCurrencyCode $fromAmount → $toCurrencyCode $toAmount, '
      'rate: $exchangeRate, '
      'transferredHome: $transferredHomeAmount $homeCurrencyCode, '
      'destRate: $destinationEffectiveRate, '
      'sourcePlans: ${sourcePlans.length})';
}
