import 'refund_destination.dart';

class ExpenseRefund {
  const ExpenseRefund({
    required this.id,
    required this.tripId,
    this.expenseId,
    required this.amount,
    required this.currencyCode,
    this.homeAmount,
    this.homeCurrency,
    required this.destination,
    this.note,
    required this.isReversed,
    this.reversedAt,
    required this.createdAt,
    this.returnedLotId,
  });

  factory ExpenseRefund.create({
    String id = '',
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    double? homeAmount,
    String? homeCurrency,
    required RefundDestination destination,
    String? note,
    DateTime? createdAt,
    String? returnedLotId,
  }) {
    return ExpenseRefund(
      id: id,
      tripId: tripId,
      expenseId: expenseId,
      amount: amount,
      currencyCode: currencyCode.trim().toUpperCase(),
      homeAmount: homeAmount,
      homeCurrency: homeCurrency?.trim().toUpperCase(),
      destination: destination,
      note: _normalizeText(note),
      isReversed: false,
      reversedAt: null,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
      returnedLotId: returnedLotId,
    );
  }

  factory ExpenseRefund.fromMap(Map<String, Object?> map) {
    return ExpenseRefund(
      id: map['id']! as String,
      tripId: map['trip_id']! as String,
      expenseId: map['expense_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      currencyCode: (map['currency_code']! as String).trim().toUpperCase(),
      homeAmount: (map['home_amount'] as num?)?.toDouble(),
      homeCurrency: (map['home_currency'] as String?)?.trim().toUpperCase(),
      destination: RefundDestinationCodec.fromValue(map['destination']! as String),
      note: map['note'] as String?,
      isReversed: ((map['is_reversed'] as num?)?.toInt() ?? 0) == 1,
      reversedAt: (map['reversed_at'] as String?) != null
          ? DateTime.parse(map['reversed_at']! as String)
          : null,
      createdAt: DateTime.parse(map['created_at']! as String),
      returnedLotId: map['returned_lot_id'] as String?,
    );
  }

  final String id;
  final String tripId;
  final String? expenseId;
  final double amount;
  final String currencyCode;
  final double? homeAmount;
  final String? homeCurrency;
  final RefundDestination destination;
  final String? note;
  final bool isReversed;
  final DateTime? reversedAt;
  final DateTime createdAt;
  final String? returnedLotId;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'expense_id': expenseId,
      'amount': amount,
      'currency_code': currencyCode,
      'home_amount': homeAmount,
      'home_currency': homeCurrency,
      'destination': destination.value,
      'note': note,
      'is_reversed': isReversed ? 1 : 0,
      'reversed_at': reversedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'returned_lot_id': returnedLotId,
    };
  }

  ExpenseRefund copyWith({
    String? id,
    String? tripId,
    Object? expenseId = _sentinel,
    double? amount,
    String? currencyCode,
    Object? homeAmount = _sentinel,
    Object? homeCurrency = _sentinel,
    RefundDestination? destination,
    Object? note = _sentinel,
    bool? isReversed,
    Object? reversedAt = _sentinel,
    DateTime? createdAt,
    Object? returnedLotId = _sentinel,
  }) {
    return ExpenseRefund(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      expenseId: identical(expenseId, _sentinel) ? this.expenseId : expenseId as String?,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      homeAmount: identical(homeAmount, _sentinel) ? this.homeAmount : homeAmount as double?,
      homeCurrency: identical(homeCurrency, _sentinel) ? this.homeCurrency : homeCurrency as String?,
      destination: destination ?? this.destination,
      note: identical(note, _sentinel) ? this.note : note as String?,
      isReversed: isReversed ?? this.isReversed,
      reversedAt: identical(reversedAt, _sentinel) ? this.reversedAt : reversedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      returnedLotId: identical(returnedLotId, _sentinel) ? this.returnedLotId : returnedLotId as String?,
    );
  }

  static const Object _sentinel = Object();

  static String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
