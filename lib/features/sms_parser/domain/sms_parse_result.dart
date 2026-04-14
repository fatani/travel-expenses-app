class SmsParseResult {
  const SmsParseResult({
    required this.rawText,
    this.amount,
    this.currencyCode,
    this.spentAt,
    this.merchant,
    this.suggestedCategory,
    this.suggestedPaymentMethod,
    this.suggestedPaymentNetwork,
    this.suggestedPaymentChannel,
  });

  final String rawText;
  final double? amount;
  final String? currencyCode;
  final DateTime? spentAt;
  final String? merchant;
  final String? suggestedCategory;
  final String? suggestedPaymentMethod;
  final String? suggestedPaymentNetwork;
  final String? suggestedPaymentChannel;

  bool get hasAnyValue {
    return amount != null ||
        currencyCode != null ||
        spentAt != null ||
        merchant != null ||
        suggestedCategory != null ||
        suggestedPaymentMethod != null ||
        suggestedPaymentNetwork != null ||
        suggestedPaymentChannel != null;
  }
}
