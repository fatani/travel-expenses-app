class CurrencyExchange {
  const CurrencyExchange({
    required this.id,
    required this.tripId,
    required this.fromCurrencyCode,
    required this.fromAmount,
    required this.toCurrencyCode,
    required this.toAmount,
    required this.exchangeRate,
    required this.toLotId,
    required this.isReversed,
    this.reversedAt,
    this.note,
    required this.createdAt,
  });

  factory CurrencyExchange.create({
    String id = '',
    required String tripId,
    required String fromCurrencyCode,
    required double fromAmount,
    required String toCurrencyCode,
    required double toAmount,
    required double exchangeRate,
    required String toLotId,
    String? note,
    DateTime? createdAt,
  }) {
    return CurrencyExchange(
      id: id,
      tripId: tripId,
      fromCurrencyCode: fromCurrencyCode.trim().toUpperCase(),
      fromAmount: fromAmount,
      toCurrencyCode: toCurrencyCode.trim().toUpperCase(),
      toAmount: toAmount,
      exchangeRate: exchangeRate,
      toLotId: toLotId,
      isReversed: false,
      reversedAt: null,
      note: note,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
    );
  }

  factory CurrencyExchange.fromMap(Map<String, Object?> map) {
    return CurrencyExchange(
      id: map['id']! as String,
      tripId: map['trip_id']! as String,
      fromCurrencyCode: (map['from_currency_code']! as String).trim().toUpperCase(),
      fromAmount: (map['from_amount'] as num).toDouble(),
      toCurrencyCode: (map['to_currency_code']! as String).trim().toUpperCase(),
      toAmount: (map['to_amount'] as num).toDouble(),
      exchangeRate: (map['exchange_rate'] as num).toDouble(),
      toLotId: map['to_lot_id']! as String,
      isReversed: ((map['is_reversed'] as num?)?.toInt() ?? 0) == 1,
      reversedAt: (map['reversed_at'] as String?) != null
          ? DateTime.parse(map['reversed_at']! as String)
          : null,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  final String id;
  final String tripId;
  final String fromCurrencyCode;
  final double fromAmount;
  final String toCurrencyCode;
  final double toAmount;
  final double exchangeRate;
  final String toLotId;
  final bool isReversed;
  final DateTime? reversedAt;
  final String? note;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'from_currency_code': fromCurrencyCode,
      'from_amount': fromAmount,
      'to_currency_code': toCurrencyCode,
      'to_amount': toAmount,
      'exchange_rate': exchangeRate,
      'to_lot_id': toLotId,
      'is_reversed': isReversed ? 1 : 0,
      'reversed_at': reversedAt?.toUtc().toIso8601String(),
      'note': note,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
