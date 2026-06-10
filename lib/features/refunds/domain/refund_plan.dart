import 'refund_destination.dart';

/// An immutable value object describing a planned refund.
///
/// Returned by [RefundInheritanceEngine.planCashRefund] and
/// [RefundInheritanceEngine.planCardRefund].  No DB writes have occurred when
/// this object is returned — it is a pure plan for the calling use-case to
/// execute.
class RefundPlan {
  const RefundPlan({
    required this.destination,
    required this.shouldCreateCashLot,
    required this.refundAmount,
    required this.refundCurrency,
    this.cashLotAmount,
    this.cashLotCurrency,
    this.inheritedHomeAmount,
    this.inheritedHomeCurrency,
    this.effectiveRate,
    required this.isUnlinked,
    this.linkedExpenseId,
  });

  /// Whether the refund returns cash to the wallet ([RefundDestination.cash])
  /// or back to a card ([RefundDestination.card]).
  final RefundDestination destination;

  /// `true` when the use-case should create a new [cash_lots] row for this
  /// refund (only cash refunds create a lot).
  final bool shouldCreateCashLot;

  /// The refund face-value amount in [refundCurrency].
  final double refundAmount;

  /// The currency of the refund (upper-case).
  final String refundCurrency;

  /// Amount to place in the new cash lot — equals [refundAmount] for cash
  /// refunds; null for card refunds.
  final double? cashLotAmount;

  /// Currency of the new cash lot — equals [refundCurrency] for cash refunds;
  /// null for card refunds.
  final String? cashLotCurrency;

  /// Home-currency amount inherited as the lot's cost basis.  Null when no
  /// home-currency information was provided or applicable.
  final double? inheritedHomeAmount;

  /// Home-currency code matching [inheritedHomeAmount].
  final String? inheritedHomeCurrency;

  /// `inheritedHomeAmount / cashLotAmount`.  Null when either operand is null.
  final double? effectiveRate;

  /// `true` when the refund is not linked to a specific expense.
  final bool isUnlinked;

  /// The expense ID this refund is linked to, or null if unlinked.
  final String? linkedExpenseId;

  @override
  String toString() => 'RefundPlan('
      'destination: $destination, '
      'shouldCreateCashLot: $shouldCreateCashLot, '
      'amount: $refundAmount $refundCurrency, '
      'inheritedHome: $inheritedHomeAmount $inheritedHomeCurrency, '
      'effectiveRate: $effectiveRate, '
      'isUnlinked: $isUnlinked)';
}
