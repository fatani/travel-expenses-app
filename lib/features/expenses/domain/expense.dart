class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.spentAt,
    this.category,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Expense.create({
    String id = '',
    required String tripId,
    required String title,
    required double amount,
    String currencyCode = 'USD',
    DateTime? spentAt,
    String? category,
    String? note,
  }) {
    final now = DateTime.now().toUtc();

    return Expense(
      id: id,
      tripId: tripId,
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      spentAt: spentAt ?? now,
      category: category,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Expense.fromMap(Map<String, Object?> map) {
    return Expense(
      id: map['id']! as String,
      tripId: map['trip_id']! as String,
      title: map['title']! as String,
      amount: (map['amount']! as num).toDouble(),
      currencyCode: map['currency_code']! as String,
      spentAt: DateTime.parse(map['spent_at']! as String),
      category: map['category'] as String?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  final String id;
  final String tripId;
  final String title;
  final double amount;
  final String currencyCode;
  final DateTime spentAt;
  final String? category;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense copyWith({
    String? id,
    String? tripId,
    String? title,
    double? amount,
    String? currencyCode,
    DateTime? spentAt,
    String? category,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      spentAt: spentAt ?? this.spentAt,
      category: category ?? this.category,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'title': title,
      'amount': amount,
      'currency_code': currencyCode,
      'spent_at': spentAt.toUtc().toIso8601String(),
      'category': category,
      'note': note,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
