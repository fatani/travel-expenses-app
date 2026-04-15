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

  // Backward-compatible aliases used by existing UI/tests.
  double? get amount => transactionAmount;
  String? get currencyCode => transactionCurrency;

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
        suggestedPaymentChannel != null;
  }
}
