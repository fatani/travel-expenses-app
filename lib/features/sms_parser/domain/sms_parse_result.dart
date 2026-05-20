class SmsParseResult {
  const SmsParseResult({
    required this.rawText,
    this.transactionAmount,
    this.transactionCurrency,
    this.billedAmount,
    this.billedCurrency,
    this.feesAmount,
    this.feesCurrency,
    this.totalChargedAmount,
    this.totalChargedCurrency,
    this.isInternational,
    this.spentAt,
    this.merchant,
    this.suggestedCategory,
    this.suggestedPaymentMethod,
    this.suggestedPaymentNetwork,
    this.suggestedPaymentChannel,
    this.suggestedPaymentDetail,
    this.parserName,
    this.notes,
  });

  final String rawText;
  final double? transactionAmount;
  final String? transactionCurrency;
  final double? billedAmount;
  final String? billedCurrency;
  final double? feesAmount;
  final String? feesCurrency;
  final double? totalChargedAmount;
  final String? totalChargedCurrency;
  final bool? isInternational;
  final DateTime? spentAt;
  final String? merchant;
  final String? suggestedCategory;
  final String? suggestedPaymentMethod;
  final String? suggestedPaymentNetwork;
  final String? suggestedPaymentChannel;
  final String? suggestedPaymentDetail;
  final String? parserName;
  final String? notes;

  // Backward-compatible aliases used by existing UI/tests.
  double? get amount => transactionAmount;
  String? get currencyCode => transactionCurrency;
  DateTime? get transactionDateTime => spentAt;
  String? get title => merchant;
  String? get paymentNetwork => suggestedPaymentNetwork;
  String? get paymentChannel => suggestedPaymentChannel;
  String? get paymentDetail => suggestedPaymentDetail;

  SmsParseResult copyWith({
    String? rawText,
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
    String? merchant,
    String? suggestedCategory,
    String? suggestedPaymentMethod,
    String? suggestedPaymentNetwork,
    String? suggestedPaymentChannel,
    String? suggestedPaymentDetail,
    String? parserName,
    String? notes,
  }) {
    return SmsParseResult(
      rawText: rawText ?? this.rawText,
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
      merchant: merchant ?? this.merchant,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      suggestedPaymentMethod:
          suggestedPaymentMethod ?? this.suggestedPaymentMethod,
      suggestedPaymentNetwork:
          suggestedPaymentNetwork ?? this.suggestedPaymentNetwork,
      suggestedPaymentChannel:
          suggestedPaymentChannel ?? this.suggestedPaymentChannel,
      suggestedPaymentDetail:
          suggestedPaymentDetail ?? this.suggestedPaymentDetail,
      parserName: parserName ?? this.parserName,
      notes: notes ?? this.notes,
    );
  }

  bool get hasAnyValue {
    return transactionAmount != null ||
        transactionCurrency != null ||
        billedAmount != null ||
        billedCurrency != null ||
        feesAmount != null ||
        feesCurrency != null ||
        totalChargedAmount != null ||
        totalChargedCurrency != null ||
        isInternational != null ||
        spentAt != null ||
        merchant != null ||
        suggestedCategory != null ||
        suggestedPaymentMethod != null ||
        suggestedPaymentNetwork != null ||
        suggestedPaymentChannel != null ||
        suggestedPaymentDetail != null;
  }
}
