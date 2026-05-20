class TripCashBalance {
  const TripCashBalance({
    required this.tripId,
    required this.currencyCode,
    required this.balanceAmount,
    required this.updatedAt,
  });

  final String tripId;
  final String currencyCode;
  final double balanceAmount;
  final DateTime updatedAt;

  factory TripCashBalance.fromMap(Map<String, Object?> map) {
    return TripCashBalance(
      tripId: map['trip_id']! as String,
      currencyCode: (map['currency_code']! as String).trim().toUpperCase(),
      balanceAmount: (map['balance_amount'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'trip_id': tripId,
      'currency_code': currencyCode,
      'balance_amount': balanceAmount,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
