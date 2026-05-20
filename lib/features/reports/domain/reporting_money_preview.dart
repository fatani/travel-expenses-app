class ReportingMoneyPreview {
  const ReportingMoneyPreview({
    required this.originalAmount,
    required this.originalCurrency,
    this.convertedHomeAmount,
    this.homeCurrency,
  });

  final double originalAmount;
  final String originalCurrency;
  final double? convertedHomeAmount;
  final String? homeCurrency;

  bool get hasHomeConversion =>
      convertedHomeAmount != null &&
      homeCurrency != null &&
      homeCurrency!.trim().isNotEmpty;
}
