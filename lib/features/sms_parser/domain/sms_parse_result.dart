class SmsParseResult {
  const SmsParseResult({
    required this.rawText,
    this.amount,
    this.currencyCode,
    this.spentAt,
    this.merchant,
    this.suggestedCategory,
  });

  final String rawText;
  final double? amount;
  final String? currencyCode;
  final DateTime? spentAt;
  final String? merchant;
  final String? suggestedCategory;

  bool get hasAnyParsedValue {
    return amount != null ||
        currencyCode != null ||
        spentAt != null ||
        merchant != null ||
        suggestedCategory != null;
  }
}
