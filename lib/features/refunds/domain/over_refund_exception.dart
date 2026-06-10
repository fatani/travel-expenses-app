/// Thrown by the [RefundInheritanceEngine] when the proposed refund's
/// home-currency amount would push the total refunded amount for an expense
/// above the expense's own home-currency amount.
class OverRefundException implements Exception {
  const OverRefundException({
    required this.requested,
    required this.existing,
    required this.limit,
  });

  /// The home-currency amount of the new refund being planned.
  final double requested;

  /// The sum of home-currency amounts already refunded for the expense.
  final double existing;

  /// The maximum home-currency amount that may be refunded (the expense's
  /// [convertedHomeAmount]).
  final double limit;

  @override
  String toString() => 'OverRefundException('
      'requested: $requested, '
      'existing: $existing, '
      'limit: $limit)';
}
