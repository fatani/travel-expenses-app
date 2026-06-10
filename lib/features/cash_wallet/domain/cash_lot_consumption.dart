class CashLotConsumption {
  const CashLotConsumption({
    required this.id,
    required this.lotId,
    required this.consumptionType,
    this.expenseId,
    this.exchangeId,
    required this.consumedAmount,
    this.homeAmount,
    this.homeCurrencyCode,
    required this.isReversed,
    this.reversedAt,
    required this.createdAt,
  });

  factory CashLotConsumption.create({
    String id = '',
    required String lotId,
    required String consumptionType,
    String? expenseId,
    String? exchangeId,
    required double consumedAmount,
    double? homeAmount,
    String? homeCurrencyCode,
    DateTime? createdAt,
  }) {
    return CashLotConsumption(
      id: id,
      lotId: lotId,
      consumptionType: consumptionType,
      expenseId: expenseId,
      exchangeId: exchangeId,
      consumedAmount: consumedAmount,
      homeAmount: homeAmount,
      homeCurrencyCode: homeCurrencyCode?.trim().toUpperCase(),
      isReversed: false,
      reversedAt: null,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
    );
  }

  factory CashLotConsumption.fromMap(Map<String, Object?> map) {
    return CashLotConsumption(
      id: map['id']! as String,
      lotId: map['lot_id']! as String,
      consumptionType: map['consumption_type']! as String,
      expenseId: map['expense_id'] as String?,
      exchangeId: map['exchange_id'] as String?,
      consumedAmount: (map['consumed_amount'] as num).toDouble(),
      homeAmount: (map['home_amount'] as num?)?.toDouble(),
      homeCurrencyCode: (map['home_currency_code'] as String?)?.trim().toUpperCase(),
      isReversed: ((map['is_reversed'] as num?)?.toInt() ?? 0) == 1,
      reversedAt: (map['reversed_at'] as String?) != null
          ? DateTime.parse(map['reversed_at']! as String)
          : null,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  final String id;
  final String lotId;
  final String consumptionType;
  final String? expenseId;
  final String? exchangeId;
  final double consumedAmount;
  final double? homeAmount;
  final String? homeCurrencyCode;
  final bool isReversed;
  final DateTime? reversedAt;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'lot_id': lotId,
      'consumption_type': consumptionType,
      'expense_id': expenseId,
      'exchange_id': exchangeId,
      'consumed_amount': consumedAmount,
      'home_amount': homeAmount,
      'home_currency_code': homeCurrencyCode,
      'is_reversed': isReversed ? 1 : 0,
      'reversed_at': reversedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
