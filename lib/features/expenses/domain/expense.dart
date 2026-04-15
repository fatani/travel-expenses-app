class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.transactionAmount,
    required this.transactionCurrency,
    this.billedAmount,
    this.billedCurrency,
    this.feesAmount,
    this.feesCurrency,
    this.totalChargedAmount,
    this.totalChargedCurrency,
    required this.isInternational,
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
    double? transactionAmount,
    String? transactionCurrency,
    double? billedAmount,
    String? billedCurrency,
    double? feesAmount,
    String? feesCurrency,
    double? totalChargedAmount,
    String? totalChargedCurrency,
    bool? isInternational,
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
      transactionAmount: transactionAmount ?? amount,
      transactionCurrency: transactionCurrency ?? currencyCode,
      billedAmount: billedAmount,
      billedCurrency: billedCurrency,
      feesAmount: feesAmount,
      feesCurrency: feesCurrency,
      totalChargedAmount: totalChargedAmount,
      totalChargedCurrency: totalChargedCurrency,
      isInternational:
          isInternational ??
          _inferInternational(
            transactionCurrency: transactionCurrency ?? currencyCode,
            feesAmount: feesAmount,
          ),
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
    final legacyAmount = (map['amount']! as num).toDouble();
    final legacyCurrencyCode = map['currency_code']! as String;
    final transactionAmount =
      (map['transaction_amount'] as num?)?.toDouble() ?? legacyAmount;
    final transactionCurrency =
      (map['transaction_currency'] as String?) ?? legacyCurrencyCode;
    final feesAmount = (map['fees_amount'] as num?)?.toDouble();

    return Expense(
      id: map['id']! as String,
      tripId: map['trip_id']! as String,
      title: map['title']! as String,
      amount: transactionAmount,
      currencyCode: transactionCurrency,
      transactionAmount: transactionAmount,
      transactionCurrency: transactionCurrency,
      billedAmount: (map['billed_amount'] as num?)?.toDouble(),
      billedCurrency: map['billed_currency'] as String?,
      feesAmount: feesAmount,
      feesCurrency: map['fees_currency'] as String?,
      totalChargedAmount: (map['total_charged_amount'] as num?)?.toDouble(),
      totalChargedCurrency: map['total_charged_currency'] as String?,
      isInternational:
          ((map['is_international'] as num?)?.toInt() ?? 0) == 1 ||
          _inferInternational(
            transactionCurrency: transactionCurrency,
            feesAmount: feesAmount,
          ),
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
  final double transactionAmount;
  final String transactionCurrency;
  final double? billedAmount;
  final String? billedCurrency;
  final double? feesAmount;
  final String? feesCurrency;
  final double? totalChargedAmount;
  final String? totalChargedCurrency;
  final bool isInternational;
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
    double? transactionAmount,
    String? transactionCurrency,
    double? billedAmount,
    String? billedCurrency,
    double? feesAmount,
    String? feesCurrency,
    double? totalChargedAmount,
    String? totalChargedCurrency,
    bool? isInternational,
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
      transactionAmount: transactionAmount ?? this.transactionAmount,
      transactionCurrency: transactionCurrency ?? this.transactionCurrency,
      billedAmount: billedAmount ?? this.billedAmount,
      billedCurrency: billedCurrency ?? this.billedCurrency,
      feesAmount: feesAmount ?? this.feesAmount,
      feesCurrency: feesCurrency ?? this.feesCurrency,
      totalChargedAmount: totalChargedAmount ?? this.totalChargedAmount,
      totalChargedCurrency: totalChargedCurrency ?? this.totalChargedCurrency,
      isInternational: isInternational ?? this.isInternational,
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
      'amount': transactionAmount,
      'currency_code': transactionCurrency,
      'transaction_amount': transactionAmount,
      'transaction_currency': transactionCurrency,
      'billed_amount': billedAmount,
      'billed_currency': billedCurrency,
      'fees_amount': feesAmount,
      'fees_currency': feesCurrency,
      'total_charged_amount': totalChargedAmount,
      'total_charged_currency': totalChargedCurrency,
      'is_international': isInternational ? 1 : 0,
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

  static bool _inferInternational({
    required String transactionCurrency,
    required double? feesAmount,
  }) {
    return transactionCurrency.trim().toUpperCase() != 'SAR' ||
        (feesAmount != null && feesAmount > 0);
  }
}
