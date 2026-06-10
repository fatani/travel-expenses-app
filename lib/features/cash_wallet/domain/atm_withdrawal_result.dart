import '../../expenses/domain/expense.dart';
import 'cash_lot.dart';
import 'cash_transaction.dart';

/// Result returned by [RecordAtmWithdrawalUseCase.execute].
class AtmWithdrawalResult {
  const AtmWithdrawalResult({
    required this.cashLot,
    required this.cashTransaction,
    this.feeExpense,
  });

  /// The [CashLot] created to represent the received cash.
  final CashLot cashLot;

  /// The [CashTransaction] row (type = atmWithdrawal, lot_id = [cashLot.id]).
  final CashTransaction cashTransaction;

  /// The fee [Expense] (payment_channel = 'ATM Withdrawal Fee') if a fee was
  /// provided; otherwise `null`.
  final Expense? feeExpense;
}
