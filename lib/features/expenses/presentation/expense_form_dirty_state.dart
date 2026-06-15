import '../domain/expense_payment_service.dart';

/// Normalized expense form values used to detect unsaved edits.
class ExpenseFormDirtySnapshot {
  const ExpenseFormDirtySnapshot({
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.note,
    required this.spentAtMinute,
    required this.paymentMethod,
    required this.paymentNetwork,
    required this.paymentChannel,
    required this.cardProfileId,
    required this.totalChargedAmount,
    required this.totalChargedCurrency,
  });

  final String title;
  final double amount;
  final String currencyCode;
  final String category;
  final String note;
  final DateTime spentAtMinute;
  final String paymentMethod;
  final String? paymentNetwork;
  final String paymentChannel;
  final int? cardProfileId;
  final double? totalChargedAmount;
  final String? totalChargedCurrency;

  factory ExpenseFormDirtySnapshot.fromNormalizedValues({
    required String title,
    required double amount,
    required String currencyCode,
    required String category,
    required String note,
    required DateTime spentAt,
    required NormalizedExpensePayment payment,
    required double? totalChargedAmount,
    required String? totalChargedCurrency,
  }) {
    return ExpenseFormDirtySnapshot(
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      category: category,
      note: note,
      spentAtMinute: _truncateToMinute(spentAt),
      paymentMethod: payment.paymentMethod,
      paymentNetwork: payment.paymentNetwork,
      paymentChannel: payment.paymentChannel ?? '',
      cardProfileId: payment.cardProfileId,
      totalChargedAmount: totalChargedAmount,
      totalChargedCurrency: totalChargedCurrency,
    );
  }

  static DateTime _truncateToMinute(DateTime value) {
    final local = value.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseFormDirtySnapshot &&
        title == other.title &&
        amount == other.amount &&
        currencyCode == other.currencyCode &&
        category == other.category &&
        note == other.note &&
        spentAtMinute == other.spentAtMinute &&
        paymentMethod == other.paymentMethod &&
        paymentNetwork == other.paymentNetwork &&
        paymentChannel == other.paymentChannel &&
        cardProfileId == other.cardProfileId &&
        totalChargedAmount == other.totalChargedAmount &&
        totalChargedCurrency == other.totalChargedCurrency;
  }

  @override
  int get hashCode => Object.hash(
    title,
    amount,
    currencyCode,
    category,
    note,
    spentAtMinute,
    paymentMethod,
    paymentNetwork,
    paymentChannel,
    cardProfileId,
    totalChargedAmount,
    totalChargedCurrency,
  );
}
