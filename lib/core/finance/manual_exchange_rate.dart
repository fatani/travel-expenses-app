class ManualExchangeRate {
  const ManualExchangeRate({
    required this.tripId,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    this.sourceNote,
    required this.createdAt,
  });

  final String? tripId;
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final String? sourceNote;
  final DateTime createdAt;

  factory ManualExchangeRate.create({
    String? tripId,
    required String fromCurrency,
    required String toCurrency,
    required double rate,
    String? sourceNote,
    DateTime? createdAt,
  }) {
    return ManualExchangeRate(
      tripId: _normalizeText(tripId),
      fromCurrency: fromCurrency.trim().toUpperCase(),
      toCurrency: toCurrency.trim().toUpperCase(),
      rate: rate,
      sourceNote: _normalizeText(sourceNote),
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
    );
  }

  factory ManualExchangeRate.fromMap(Map<String, Object?> map) {
    return ManualExchangeRate(
      tripId: _normalizeText(map['trip_id'] as String?),
      fromCurrency: (map['from_currency']! as String).trim().toUpperCase(),
      toCurrency: (map['to_currency']! as String).trim().toUpperCase(),
      rate: (map['rate'] as num).toDouble(),
      sourceNote: map['source_note'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'trip_id': tripId,
      'from_currency': fromCurrency,
      'to_currency': toCurrency,
      'rate': rate,
      'source_note': sourceNote,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
