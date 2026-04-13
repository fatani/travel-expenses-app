class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.spentAt,
    required this.paymentMethod,
    this.paymentNetwork,
    this.paymentChannel,
    required this.source,
    this.category,
    this.note,
    this.rawSmsText,
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
    String? paymentNetwork,
    String? paymentChannel,
    String source = 'manual',
    String? category,
    String? note,
    String? rawSmsText,
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
      paymentNetwork: paymentNetwork,
      paymentChannel: paymentChannel,
      source: source,
      category: category,
      note: note,
      rawSmsText: rawSmsText,
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
      paymentNetwork: map['payment_network'] as String?,
      paymentChannel: map['payment_channel'] as String?,
      source: (map['source'] as String?) ?? 'manual',
      category: map['category'] as String?,
      note: map['note'] as String?,
      rawSmsText: map['raw_sms_text'] as String?,
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
  final String? paymentNetwork;
  final String? paymentChannel;
  final String source;
  final String? category;
  final String? note;
  final String? rawSmsText;
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
    String? paymentNetwork,
    String? paymentChannel,
    String? source,
    String? category,
    String? note,
    String? rawSmsText,
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
      paymentNetwork: paymentNetwork ?? this.paymentNetwork,
      paymentChannel: paymentChannel ?? this.paymentChannel,
      source: source ?? this.source,
      category: category ?? this.category,
      note: note ?? this.note,
      rawSmsText: rawSmsText ?? this.rawSmsText,
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
      'payment_network': paymentNetwork,
      'payment_channel': paymentChannel,
      'source': source,
      'category': category,
      'note': note,
      'raw_sms_text': rawSmsText,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static String _writeDate(DateTime value) {
    return value.toIso8601String();
  }
}
