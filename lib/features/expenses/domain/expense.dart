class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.spentAt,
    required this.paymentMethod,
    required this.source,
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
    required String paymentMethod,
    String source = 'manual',
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
      paymentMethod: paymentMethod,
      source: source,
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
      paymentMethod: (map['payment_method'] as String?) ?? '',
      source: (map['source'] as String?) ?? 'manual',
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
  final String paymentMethod;
  final String source;
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
    String? paymentMethod,
    String? source,
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
      paymentMethod: paymentMethod ?? this.paymentMethod,
      source: source ?? this.source,
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
      'spent_at': _writeDate(spentAt),
      'payment_method': paymentMethod,
      'source': source,
      'category': category,
      'note': note,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static String _writeDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
