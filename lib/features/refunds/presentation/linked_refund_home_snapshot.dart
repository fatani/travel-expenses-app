import '../../expenses/domain/expense.dart';
import '../domain/derive_refund_home_amount.dart';

/// Derives a linked refund home-currency snapshot from stored expense fields.
({double? homeAmount, String? homeCurrency}) linkedRefundHomeSnapshot({
  required Expense expense,
  required double refundAmount,
}) {
  return deriveRefundHomeAmount(
    callerHomeAmount: null,
    callerHomeCurrency: null,
    refundAmount: refundAmount,
    linkedExpense: expense,
  );
}
