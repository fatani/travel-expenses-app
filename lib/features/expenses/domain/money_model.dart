class MoneyModel {
  const MoneyModel({
    required this.transactionAmount,
    required this.transactionCurrency,
    this.billedAmount,
    this.billedCurrency,
    this.totalChargedAmount,
    this.totalChargedCurrency,
    this.feesAmount,
    this.feesCurrency,
    required this.isInternational,
  });

  final double? transactionAmount;
  final String? transactionCurrency;
  final double? billedAmount;
  final String? billedCurrency;
  final double? totalChargedAmount;
  final String? totalChargedCurrency;
  final double? feesAmount;
  final String? feesCurrency;
  final bool isInternational;

  MoneyModel copyWith({
    double? transactionAmount,
    String? transactionCurrency,
    double? billedAmount,
    String? billedCurrency,
    double? totalChargedAmount,
    String? totalChargedCurrency,
    double? feesAmount,
    String? feesCurrency,
    bool? isInternational,
  }) {
    return MoneyModel(
      transactionAmount: transactionAmount ?? this.transactionAmount,
      transactionCurrency: transactionCurrency ?? this.transactionCurrency,
      billedAmount: billedAmount ?? this.billedAmount,
      billedCurrency: billedCurrency ?? this.billedCurrency,
      totalChargedAmount: totalChargedAmount ?? this.totalChargedAmount,
      totalChargedCurrency: totalChargedCurrency ?? this.totalChargedCurrency,
      feesAmount: feesAmount ?? this.feesAmount,
      feesCurrency: feesCurrency ?? this.feesCurrency,
      isInternational: isInternational ?? this.isInternational,
    );
  }
}
