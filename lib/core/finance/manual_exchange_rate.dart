import '../integrity/data_integrity.dart';
import '../integrity/defensive_parse.dart';

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

  static ManualExchangeRate? tryFromMap(Map<String, Object?> map) {
    try {
      return ManualExchangeRate.fromMap(map);
    } on Object {
      return null;
    }
  }

  factory ManualExchangeRate.create({
    String? tripId,
    required String fromCurrency,
    required String toCurrency,
    required double rate,
    String? sourceNote,
    DateTime? createdAt,
  }) {
    DataIntegrity.requireManualExchangeRate(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      rate: rate,
    );

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
    final fromCurrency = DefensiveParse.readTrimmedString(map['from_currency']);
    final toCurrency = DefensiveParse.readTrimmedString(map['to_currency']);
    final rate = DefensiveParse.readPositiveDouble(map['rate']);
    final createdAt = DefensiveParse.readDateTime(map['created_at']);
    if (fromCurrency == null || toCurrency == null || rate == null || createdAt == null) {
      throw const FormatException('manual exchange rate row invalid');
    }

    return ManualExchangeRate(
      tripId: _normalizeText(map['trip_id'] as String?),
      fromCurrency: fromCurrency.toUpperCase(),
      toCurrency: toCurrency.toUpperCase(),
      rate: rate,
      sourceNote: map['source_note'] as String?,
      createdAt: createdAt,
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
