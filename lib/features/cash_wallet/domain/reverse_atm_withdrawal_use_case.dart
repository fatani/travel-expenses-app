import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../expenses/data/expense_repository.dart';
import '../data/cash_wallet_repository.dart';
import 'atm_correction.dart';
import 'atm_correction_service.dart';
import 'atm_not_correctable_exception.dart';
import 'cash_transaction.dart';
import 'insufficient_cash_exception.dart';

/// Safely reverses (undoes) a single ATM withdrawal whose generated cash has
/// not been used.
///
/// Reversing means: remove the received cash, reverse the generated lot, and
/// reverse the linked ATM fee expense — never hard-deleting or editing any row.
/// Balances behave as if the withdrawal never happened.
///
/// This is the **Undo** operation. `CorrectAtmWithdrawalUseCase` reuses
/// [reverseInTransaction] so the reverse-of-original and the corrected record
/// share one atomic transaction.
class ReverseAtmWithdrawalUseCase {
  ReverseAtmWithdrawalUseCase({
    required AppDatabase appDatabase,
    required AtmCorrectionService correctionService,
    required CashWalletRepository cashWalletRepository,
    required ExpenseRepository expenseRepository,
  })  : _appDatabase = appDatabase,
        _correctionService = correctionService,
        _cashWalletRepository = cashWalletRepository,
        _expenseRepository = expenseRepository;

  final AppDatabase _appDatabase;
  final AtmCorrectionService _correctionService;
  final CashWalletRepository _cashWalletRepository;
  final ExpenseRepository _expenseRepository;

  /// Undoes the ATM withdrawal [atmCashTransactionId] in its own atomic
  /// transaction.
  ///
  /// Throws [AtmNotCorrectableException] when the withdrawal is missing, already
  /// reversed, its cash was used, or a legacy fee cannot be linked — in which
  /// case nothing is mutated.
  Future<CashTransaction> execute(String atmCashTransactionId) async {
    final db = await _appDatabase.database;
    return db.transaction(
      (txn) => reverseInTransaction(txn, atmCashTransactionId),
    );
  }

  /// Reverses [atmCashTransactionId] inside the caller-supplied [txn].
  ///
  /// Re-validates correctability against the live (in-transaction) state before
  /// mutating, so a concurrent spend cannot slip through. Returns the original
  /// (now-reversed) ATM cash transaction.
  Future<CashTransaction> reverseInTransaction(
    DatabaseExecutor txn,
    String atmCashTransactionId,
  ) async {
    final status =
        await _correctionService.getStatus(atmCashTransactionId, txn: txn);
    if (!status.canUndo) {
      throw AtmNotCorrectableException(
        cashTransactionId: atmCashTransactionId,
        reason: status.reasonCode == AtmCorrectionReason.none
            ? AtmCorrectionReason.cashUsed
            : status.reasonCode,
        affectedTransactions: status.affectedTransactions,
      );
    }

    final cashTx = await _cashWalletRepository.getCashTransactionById(
      atmCashTransactionId,
      txn: txn,
    );
    // getStatus already guaranteed a non-reversed ATM transaction exists.
    if (cashTx == null) {
      throw const AtmNotCorrectableException(
        cashTransactionId: '',
        reason: AtmCorrectionReason.cashTransactionNotFound,
      );
    }

    // 1. Reverse the cash side: generated lot + inflow transaction + balance.
    // Wrap InsufficientCashException (balance guard fired — ATM cash was spent
    // before backup so the lot-remaining is overstated after restore) into the
    // domain exception the UI already knows how to handle.
    try {
      await _cashWalletRepository.reverseAtmCashInflowInTxn(
        txn,
        transaction: cashTx,
      );
    } on InsufficientCashException {
      throw AtmNotCorrectableException(
        cashTransactionId: atmCashTransactionId,
        reason: AtmCorrectionReason.cashUsed,
      );
    }

    // 2. Reverse the linked ATM fee expense, if any (card expense — no FIFO).
    final feeExpenseId = status.feeExpenseId;
    if (feeExpenseId != null) {
      await _expenseRepository.markExpenseReversed(feeExpenseId, txn: txn);
    }

    return cashTx;
  }
}
