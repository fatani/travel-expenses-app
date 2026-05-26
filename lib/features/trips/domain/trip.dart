import '../../../core/integrity/data_integrity.dart';
import '../../../core/integrity/defensive_parse.dart';

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.baseCurrency,
    required this.destinationCurrency,
    required this.homeCurrencySnapshot,
    this.startDate,
    this.endDate,
    this.budget,
    this.budgetCurrency,
    required this.createdAt,
    required this.updatedAt,
    this.isCustomTitle = false,
    this.destinationCountryCode,
  });

  static Trip? tryFromMap(Map<String, Object?> map) {
    try {
      return Trip.fromMap(map);
    } on Object {
      return null;
    }
  }

  factory Trip.create({
    String id = '',
    required String name,
    required String destination,
    required String baseCurrency,
    String? destinationCurrency,
    String? homeCurrencySnapshot,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    String? budgetCurrency,
    bool isCustomTitle = false,
    String? destinationCountryCode,
  }) {
    DataIntegrity.requireTripCurrencies(
      baseCurrency: baseCurrency,
      destinationCurrency: destinationCurrency,
      homeCurrencySnapshot: homeCurrencySnapshot,
      budgetCurrency: budgetCurrency,
    );

    final now = DateTime.now().toUtc();

    return Trip(
      id: id,
      name: name,
      destination: destination,
      baseCurrency: baseCurrency,
        destinationCurrency:
          (destinationCurrency == null || destinationCurrency.trim().isEmpty)
          ? baseCurrency
          : destinationCurrency.trim().toUpperCase(),
        homeCurrencySnapshot:
          (homeCurrencySnapshot == null || homeCurrencySnapshot.trim().isEmpty)
          ? baseCurrency
          : homeCurrencySnapshot.trim().toUpperCase(),
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      budgetCurrency: budgetCurrency,
      createdAt: now,
      updatedAt: now,
      isCustomTitle: isCustomTitle,
      destinationCountryCode: destinationCountryCode,
    );
  }

  factory Trip.fromMap(Map<String, Object?> map) {
    final id = DefensiveParse.readTrimmedString(map['id']);
    final name = DefensiveParse.readTrimmedString(map['name']);
    if (id == null || name == null) {
      throw const FormatException('trip id/name missing');
    }

    final createdAt = DefensiveParse.readDateTime(map['created_at']);
    final updatedAt = DefensiveParse.readDateTime(map['updated_at']);
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('trip timestamps missing');
    }

    return Trip(
      id: id,
      name: name,
      destination: (map['destination'] as String?) ?? '',
      baseCurrency: (map['base_currency'] as String?) ?? '',
        destinationCurrency:
          ((map['destination_currency'] as String?) ??
              (map['base_currency'] as String?) ??
              '')
            .trim()
            .toUpperCase(),
        homeCurrencySnapshot:
          ((map['home_currency_snapshot'] as String?) ??
              (map['base_currency'] as String?) ??
              '')
            .trim()
            .toUpperCase(),
      startDate: _readDate(map['start_date']),
      endDate: _readDate(map['end_date']),
      budget: _readBudget(map['budget']),
      budgetCurrency: _readBudgetCurrency(map),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isCustomTitle: (map['is_custom_title'] as int? ?? 0) != 0,
      destinationCountryCode: map['destination_country_code'] as String?,
    );
  }

  final String id;
  final String name;
  final String destination;
  final String baseCurrency;
  final String destinationCurrency;
  final String homeCurrencySnapshot;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? budget;
  final String? budgetCurrency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isCustomTitle;
  final String? destinationCountryCode;

  static const Object _unset = Object();

  Trip copyWith({
    String? id,
    String? name,
    String? destination,
    String? baseCurrency,
    String? destinationCurrency,
    String? homeCurrencySnapshot,
    Object? startDate = _unset,
    Object? endDate = _unset,
    Object? budget = _unset,
    Object? budgetCurrency = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCustomTitle,
    Object? destinationCountryCode = _unset,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      destinationCurrency: destinationCurrency ?? this.destinationCurrency,
      homeCurrencySnapshot: homeCurrencySnapshot ?? this.homeCurrencySnapshot,
      startDate: identical(startDate, _unset) ? this.startDate : startDate as DateTime?,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
      budget: identical(budget, _unset) ? this.budget : budget as double?,
      budgetCurrency: identical(budgetCurrency, _unset)
          ? this.budgetCurrency
          : budgetCurrency as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCustomTitle: isCustomTitle ?? this.isCustomTitle,
      destinationCountryCode: identical(destinationCountryCode, _unset)
          ? this.destinationCountryCode
          : destinationCountryCode as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'destination': destination,
      'base_currency': baseCurrency,
      'destination_currency': destinationCurrency,
      'home_currency_snapshot': homeCurrencySnapshot,
      'start_date': startDate == null ? null : _writeDate(startDate!),
      'end_date': endDate == null ? null : _writeDate(endDate!),
      'budget': budget,
      'budget_currency': budgetCurrency,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_custom_title': isCustomTitle ? 1 : 0,
      'destination_country_code': destinationCountryCode,
    };
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value as String);
  }

  static double? _readBudget(Object? value) {
    if (value == null) {
      return null;
    }

    return (value as num).toDouble();
  }

  static String? _readBudgetCurrency(Map<String, Object?> map) {
    final value = map['budget_currency'] as String?;
    if (value != null && value.trim().isNotEmpty) {
      return value.trim().toUpperCase();
    }

    final budget = _readBudget(map['budget']);
    if (budget == null) {
      return null;
    }

    final baseCurrency = (map['base_currency'] as String?)?.trim().toUpperCase();
    return (baseCurrency == null || baseCurrency.isEmpty) ? null : baseCurrency;
  }

  static String _writeDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
