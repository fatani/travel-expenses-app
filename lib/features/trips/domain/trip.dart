class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.baseCurrency,
    this.startDate,
    this.endDate,
    this.budget,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trip.create({
    String id = '',
    required String name,
    required String destination,
    required String baseCurrency,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
  }) {
    final now = DateTime.now().toUtc();

    return Trip(
      id: id,
      name: name,
      destination: destination,
      baseCurrency: baseCurrency,
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Trip.fromMap(Map<String, Object?> map) {
    return Trip(
      id: map['id']! as String,
      name: map['name']! as String,
      destination: (map['destination'] as String?) ?? '',
      baseCurrency: (map['base_currency'] as String?) ?? '',
      startDate: _readDate(map['start_date']),
      endDate: _readDate(map['end_date']),
      budget: _readBudget(map['budget']),
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  final String id;
  final String name;
  final String destination;
  final String baseCurrency;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? budget;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip copyWith({
    String? id,
    String? name,
    String? destination,
    String? baseCurrency,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'destination': destination,
      'base_currency': baseCurrency,
      'start_date': startDate == null ? null : _writeDate(startDate!),
      'end_date': endDate == null ? null : _writeDate(endDate!),
      'budget': budget,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
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

  static String _writeDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
