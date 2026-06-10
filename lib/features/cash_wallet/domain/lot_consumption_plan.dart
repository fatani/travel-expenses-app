/// An immutable value object describing how much of a single cash lot should
/// be consumed as part of a FIFO consumption plan.
///
/// The engine returns a list of these — one per lot that is touched — ordered
/// in FIFO (oldest-first) sequence.  No DB writes have occurred yet when this
/// object is returned; it is purely a plan.
class LotConsumptionPlan {
  const LotConsumptionPlan({
    required this.lotId,
    required this.consumedAmount,
    this.homeAmount,
    this.homeCurrencyCode,
    required this.remainingAmountAfter,
  });

  /// The ID of the cash lot being drawn from.
  final String lotId;

  /// The amount consumed from this lot (always > 0).
  final double consumedAmount;

  /// The home-currency equivalent of [consumedAmount], derived from the lot's
  /// [effectiveRate].  Null when the lot has no cost-basis snapshot.
  final double? homeAmount;

  /// The home-currency code matching [homeAmount].  Null when [homeAmount] is
  /// null.
  final String? homeCurrencyCode;

  /// The lot's remaining balance after the planned consumption is applied
  /// (i.e. `lot.remainingAmount - consumedAmount`).  Will be 0 when the lot
  /// is fully consumed by this plan step.
  final double remainingAmountAfter;

  @override
  String toString() => 'LotConsumptionPlan('
      'lotId: $lotId, '
      'consumedAmount: $consumedAmount, '
      'homeAmount: $homeAmount, '
      'homeCurrencyCode: $homeCurrencyCode, '
      'remainingAmountAfter: $remainingAmountAfter)';
}
