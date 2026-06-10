import '../../cash_wallet/domain/cash_lot.dart';
import '../../cash_wallet/domain/cash_transaction.dart';
import 'expense_refund.dart';

/// Immutable result returned by [RecordRefundUseCase.execute].
class RefundResult {
  const RefundResult({
    required this.refund,
    this.cashLot,
    this.cashTransaction,
  });

  /// The persisted [ExpenseRefund] row.
  final ExpenseRefund refund;

  /// The returned [CashLot] created for cash refunds; null for card refunds.
  final CashLot? cashLot;

  /// The [CashTransaction] row (type = cashRefund) for cash refunds; null for
  /// card refunds.
  final CashTransaction? cashTransaction;
}
