class CurrencyConversion {
  const CurrencyConversion({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.createdAt,
    required this.isManual,
  });

  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final DateTime createdAt;
  final bool isManual;

  Map<String, Object?> toMap() {
    return {
      'from_currency': fromCurrency,
      'to_currency': toCurrency,
      'rate': rate,
      'created_at': createdAt.toUtc().toIso8601String(),
      'is_manual': isManual,
    };
  }

  factory CurrencyConversion.fromMap(Map<String, Object?> map) {
    return CurrencyConversion(
      fromCurrency: (map['from_currency'] as String).trim().toUpperCase(),
      toCurrency: (map['to_currency'] as String).trim().toUpperCase(),
      rate: (map['rate'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      isManual: map['is_manual'] == true || ((map['is_manual'] as num?)?.toInt() ?? 0) == 1,
    );
  }
}
