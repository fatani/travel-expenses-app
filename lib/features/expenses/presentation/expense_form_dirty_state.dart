import '../domain/expense_payment_service.dart';

/// Normalized expense form values used to detect unsaved edits.
class ExpenseFormDirtySnapshot {
  const ExpenseFormDirtySnapshot({
    required this.title,
    required this.amountText,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.note,
    required this.spentAtMinute,
    required this.paymentMethod,
    required this.paymentNetwork,
    required this.paymentChannel,
    required this.cardProfileId,
    required this.chargedHomeAmountText,
    required this.totalChargedAmount,
    required this.totalChargedCurrency,
  });

  final String title;
  final String amountText;
  final double? amount;
  final String currencyCode;
  final String category;
  final String note;
  final DateTime spentAtMinute;
  final String paymentMethod;
  final String? paymentNetwork;
  final String paymentChannel;
  final int? cardProfileId;
  final String chargedHomeAmountText;
  final double? totalChargedAmount;
  final String? totalChargedCurrency;

  factory ExpenseFormDirtySnapshot.fromNormalizedValues({
    required String title,
    required String amountText,
    required String currencyCode,
    required String category,
    required String note,
    required DateTime spentAt,
    required NormalizedExpensePayment payment,
    required String chargedHomeAmountText,
    required double? totalChargedAmount,
    required String? totalChargedCurrency,
  }) {
    final trimmedAmount = amountText.trim();
    final trimmedChargedHomeAmount = chargedHomeAmountText.trim();
    return ExpenseFormDirtySnapshot(
      title: title,
      amountText: trimmedAmount,
      amount: double.tryParse(trimmedAmount),
      currencyCode: currencyCode,
      category: category,
      note: note,
      spentAtMinute: _truncateToMinute(spentAt),
      paymentMethod: payment.paymentMethod,
      paymentNetwork: payment.paymentNetwork,
      paymentChannel: payment.paymentChannel ?? '',
      cardProfileId: payment.cardProfileId,
      chargedHomeAmountText: trimmedChargedHomeAmount,
      totalChargedAmount: totalChargedAmount,
      totalChargedCurrency: totalChargedCurrency,
    );
  }

  static bool optionalNumericFieldsEqual(
    double? leftValue,
    String leftText,
    double? rightValue,
    String rightText,
  ) {
    if (leftValue != null && rightValue != null) {
      return leftValue == rightValue;
    }
    if (leftValue == null && rightValue == null) {
      return leftText == rightText;
    }
    return false;
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
        optionalNumericFieldsEqual(
          amount,
          amountText,
          other.amount,
          other.amountText,
        ) &&
        currencyCode == other.currencyCode &&
        category == other.category &&
        note == other.note &&
        spentAtMinute == other.spentAtMinute &&
        paymentMethod == other.paymentMethod &&
        paymentNetwork == other.paymentNetwork &&
        paymentChannel == other.paymentChannel &&
        cardProfileId == other.cardProfileId &&
        optionalNumericFieldsEqual(
          totalChargedAmount,
          chargedHomeAmountText,
          other.totalChargedAmount,
          other.chargedHomeAmountText,
        ) &&
        totalChargedCurrency == other.totalChargedCurrency;
  }

  @override
  int get hashCode => Object.hash(
    title,
    amountText,
    amount,
    currencyCode,
    category,
    note,
    spentAtMinute,
    paymentMethod,
    paymentNetwork,
    paymentChannel,
    cardProfileId,
    chargedHomeAmountText,
    totalChargedAmount,
    totalChargedCurrency,
  );
}
