class AppSettings {
  const AppSettings({
    required this.id,
    required this.currencyCode,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int singletonId = 1;

  factory AppSettings.defaults() {
    final now = DateTime.now().toUtc();

    return AppSettings(
      id: singletonId,
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AppSettings.fromMap(Map<String, Object?> map) {
    return AppSettings(
      id: map['id']! as int,
      currencyCode: map['currency_code']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  final int id;
  final String currencyCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppSettings copyWith({
    int? id,
    String? currencyCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'currency_code': currencyCode,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
