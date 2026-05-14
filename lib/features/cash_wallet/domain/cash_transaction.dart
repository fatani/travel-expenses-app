enum CashTransactionType {
  initialCash,
  atmWithdrawal,
  currencyExchangeIn,
  currencyExchangeOut,
  manualAdjustment,
  cashExpenseDeduction,
}

extension CashTransactionTypeCodec on CashTransactionType {
  String get value {
    switch (this) {
      case CashTransactionType.initialCash:
        return 'initial_cash';
      case CashTransactionType.atmWithdrawal:
        return 'atm_withdrawal';
      case CashTransactionType.currencyExchangeIn:
        return 'currency_exchange_in';
      case CashTransactionType.currencyExchangeOut:
        return 'currency_exchange_out';
      case CashTransactionType.manualAdjustment:
        return 'manual_adjustment';
      case CashTransactionType.cashExpenseDeduction:
        return 'cash_expense_deduction';
    }
  }

  static CashTransactionType fromValue(String raw) {
    switch (raw) {
      case 'initial_cash':
        return CashTransactionType.initialCash;
      case 'atm_withdrawal':
        return CashTransactionType.atmWithdrawal;
      case 'currency_exchange_in':
        return CashTransactionType.currencyExchangeIn;
      case 'currency_exchange_out':
        return CashTransactionType.currencyExchangeOut;
      case 'manual_adjustment':
        return CashTransactionType.manualAdjustment;
      case 'cash_expense_deduction':
      default:
        return CashTransactionType.cashExpenseDeduction;
    }
  }
}

class CashTransaction {
  const CashTransaction({
    required this.id,
    required this.tripId,
    required this.type,
    required this.amount,
    required this.currencyCode,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final CashTransactionType type;
  final double amount;
  final String currencyCode;
  final String? note;
  final DateTime createdAt;

  factory CashTransaction.create({
    String id = '',
    required String tripId,
    required CashTransactionType type,
    required double amount,
    required String currencyCode,
    String? note,
    DateTime? createdAt,
  }) {
    return CashTransaction(
      id: id,
      tripId: tripId,
      type: type,
      amount: amount,
      currencyCode: currencyCode.trim().toUpperCase(),
      note: _normalizeText(note),
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
    );
  }

  factory CashTransaction.fromMap(Map<String, Object?> map) {
    return CashTransaction(
      id: map['id']! as String,
      tripId: map['trip_id']! as String,
      type: CashTransactionTypeCodec.fromValue(map['type']! as String),
      amount: (map['amount'] as num).toDouble(),
      currencyCode: (map['currency_code']! as String).trim().toUpperCase(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'type': type.value,
      'amount': amount,
      'currency_code': currencyCode,
      'note': note,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
