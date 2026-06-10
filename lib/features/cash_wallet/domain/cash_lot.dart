class CashLot {
  const CashLot({
    required this.id,
    required this.tripId,
    required this.sourceType,
    required this.sourceRefType,
    required this.sourceRefId,
    required this.currencyCode,
    required this.originalAmount,
    required this.remainingAmount,
    this.homeCurrencyAmount,
    this.homeCurrencyCode,
    this.effectiveRate,
    required this.isFullyConsumed,
    required this.isReversed,
    this.reversedAt,
    required this.createdAt,
    this.note,
  });

  factory CashLot.create({
    String id = '',
    required String tripId,
    required String sourceType,
    required String sourceRefType,
    required String sourceRefId,
    required String currencyCode,
    required double originalAmount,
    double? remainingAmount,
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    double? effectiveRate,
    DateTime? createdAt,
    String? note,
  }) {
    return CashLot(
      id: id,
      tripId: tripId,
      sourceType: sourceType,
      sourceRefType: sourceRefType,
      sourceRefId: sourceRefId,
      currencyCode: currencyCode.trim().toUpperCase(),
      originalAmount: originalAmount,
      remainingAmount: remainingAmount ?? originalAmount,
      homeCurrencyAmount: homeCurrencyAmount,
      homeCurrencyCode: homeCurrencyCode?.trim().toUpperCase(),
      effectiveRate: effectiveRate,
      isFullyConsumed: false,
      isReversed: false,
      reversedAt: null,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
      note: note,
    );
  }

  factory CashLot.fromMap(Map<String, Object?> map) {
    return CashLot(
      id: map['id']! as String,
      tripId: map['trip_id']! as String,
      sourceType: map['source_type']! as String,
      sourceRefType: map['source_ref_type']! as String,
      sourceRefId: map['source_ref_id']! as String,
      currencyCode: (map['currency_code']! as String).trim().toUpperCase(),
      originalAmount: (map['original_amount'] as num).toDouble(),
      remainingAmount: (map['remaining_amount'] as num).toDouble(),
      homeCurrencyAmount: (map['home_currency_amount'] as num?)?.toDouble(),
      homeCurrencyCode: (map['home_currency_code'] as String?)?.trim().toUpperCase(),
      effectiveRate: (map['effective_rate'] as num?)?.toDouble(),
      isFullyConsumed: ((map['is_fully_consumed'] as num?)?.toInt() ?? 0) == 1,
      isReversed: ((map['is_reversed'] as num?)?.toInt() ?? 0) == 1,
      reversedAt: (map['reversed_at'] as String?) != null
          ? DateTime.parse(map['reversed_at']! as String)
          : null,
      createdAt: DateTime.parse(map['created_at']! as String),
      note: map['note'] as String?,
    );
  }

  final String id;
  final String tripId;
  final String sourceType;
  final String sourceRefType;
  final String sourceRefId;
  final String currencyCode;
  final double originalAmount;
  final double remainingAmount;
  final double? homeCurrencyAmount;
  final String? homeCurrencyCode;
  final double? effectiveRate;
  final bool isFullyConsumed;
  final bool isReversed;
  final DateTime? reversedAt;
  final DateTime createdAt;
  final String? note;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'source_type': sourceType,
      'source_ref_type': sourceRefType,
      'source_ref_id': sourceRefId,
      'currency_code': currencyCode,
      'original_amount': originalAmount,
      'remaining_amount': remainingAmount,
      'home_currency_amount': homeCurrencyAmount,
      'home_currency_code': homeCurrencyCode,
      'effective_rate': effectiveRate,
      'is_fully_consumed': isFullyConsumed ? 1 : 0,
      'is_reversed': isReversed ? 1 : 0,
      'reversed_at': reversedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'note': note,
    };
  }

  CashLot copyWith({
    String? id,
    String? tripId,
    String? sourceType,
    String? sourceRefType,
    String? sourceRefId,
    String? currencyCode,
    double? originalAmount,
    double? remainingAmount,
    Object? homeCurrencyAmount = _sentinel,
    Object? homeCurrencyCode = _sentinel,
    Object? effectiveRate = _sentinel,
    bool? isFullyConsumed,
    bool? isReversed,
    Object? reversedAt = _sentinel,
    DateTime? createdAt,
    Object? note = _sentinel,
  }) {
    return CashLot(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      sourceType: sourceType ?? this.sourceType,
      sourceRefType: sourceRefType ?? this.sourceRefType,
      sourceRefId: sourceRefId ?? this.sourceRefId,
      currencyCode: currencyCode ?? this.currencyCode,
      originalAmount: originalAmount ?? this.originalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      homeCurrencyAmount: identical(homeCurrencyAmount, _sentinel) ? this.homeCurrencyAmount : homeCurrencyAmount as double?,
      homeCurrencyCode: identical(homeCurrencyCode, _sentinel) ? this.homeCurrencyCode : homeCurrencyCode as String?,
      effectiveRate: identical(effectiveRate, _sentinel) ? this.effectiveRate : effectiveRate as double?,
      isFullyConsumed: isFullyConsumed ?? this.isFullyConsumed,
      isReversed: isReversed ?? this.isReversed,
      reversedAt: identical(reversedAt, _sentinel) ? this.reversedAt : reversedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      note: identical(note, _sentinel) ? this.note : note as String?,
    );
  }

  static const Object _sentinel = Object();
}
