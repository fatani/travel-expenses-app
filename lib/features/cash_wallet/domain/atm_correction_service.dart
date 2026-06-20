import 'package:sqflite/sqflite.dart';

import '../../expenses/data/expense_repository.dart';
import '../data/cash_lot_consumption_repository.dart';
import '../data/cash_lot_repository.dart';
import '../data/cash_wallet_repository.dart';
import 'atm_correction.dart';
import 'cash_lot.dart';
import 'cash_lot_consumption.dart';
import 'cash_transaction.dart';
import 'exchange_correction.dart' show AffectedCashUse, AffectedCashUseType;

/// Read-only query that decides whether an ATM withdrawal can be safely undone
/// or corrected, and resolves the later transactions that consumed the received
/// cash when it cannot.
///
/// An ATM withdrawal is correctable/undoable **only** when its generated cash
/// lot is fully unused and any fee is safely identifiable:
/// * the cash transaction exists, is `atm_withdrawal`, and is not reversed,
/// * the generated lot exists and is not reversed,
/// * `remainingAmount == originalAmount` with no active consumptions,
/// * any fee is linked via `source_ref` (or there are no ambiguous legacy
///   ATM-fee orphans in the trip).
class AtmCorrectionService {
  AtmCorrectionService({
    required CashWalletRepository cashWalletRepository,
    required CashLotRepository lotRepository,
    required CashLotConsumptionRepository consumptionRepository,
    required ExpenseRepository expenseRepository,
  })  : _cashWalletRepository = cashWalletRepository,
        _lotRepository = lotRepository,
        _consumptionRepository = consumptionRepository,
        _expenseRepository = expenseRepository;

  final CashWalletRepository _cashWalletRepository;
  final CashLotRepository _lotRepository;
  final CashLotConsumptionRepository _consumptionRepository;
  final ExpenseRepository _expenseRepository;

  static const double _epsilon = 1e-9;
  static const String _atmSourceRefType = 'atm_withdrawal';

  /// Computes the correction status for the ATM cash transaction
  /// [atmCashTransactionId].
  ///
  /// Pass [txn] to evaluate inside an existing transaction (used by the
  /// reverse/correct use cases to re-validate just before mutating). When [txn]
  /// is supplied, affected-transaction titles are not enriched.
  Future<AtmCorrectionStatus> getStatus(
    String atmCashTransactionId, {
    DatabaseExecutor? txn,
  }) async {
    final cashTx = await _cashWalletRepository.getCashTransactionById(
      atmCashTransactionId,
      txn: txn,
    );
    if (cashTx == null) {
      return AtmCorrectionStatus.blocked(
        cashTransactionId: atmCashTransactionId,
        reasonCode: AtmCorrectionReason.cashTransactionNotFound,
      );
    }
    if (cashTx.type != CashTransactionType.atmWithdrawal) {
      return AtmCorrectionStatus.blocked(
        cashTransactionId: atmCashTransactionId,
        reasonCode: AtmCorrectionReason.notAtmWithdrawal,
      );
    }
    if (cashTx.isReversed) {
      return AtmCorrectionStatus.blocked(
        cashTransactionId: atmCashTransactionId,
        reasonCode: AtmCorrectionReason.alreadyReversed,
        lotId: cashTx.lotId,
      );
    }

    final lotId = cashTx.lotId;
    if (lotId == null || lotId.isEmpty) {
      return AtmCorrectionStatus.blocked(
        cashTransactionId: atmCashTransactionId,
        reasonCode: AtmCorrectionReason.lotMissing,
      );
    }

    final lot = await _lotRepository.getCashLotById(lotId, txn: txn);
    if (lot == null) {
      return AtmCorrectionStatus.blocked(
        cashTransactionId: atmCashTransactionId,
        reasonCode: AtmCorrectionReason.lotMissing,
        lotId: lotId,
      );
    }
    if (lot.isReversed) {
      return AtmCorrectionStatus.blocked(
        cashTransactionId: atmCashTransactionId,
        reasonCode: AtmCorrectionReason.alreadyReversed,
        lotId: lotId,
      );
    }

    final activeConsumptions = await _consumptionRepository
        .getActiveConsumptionsByLotId(lotId, txn: txn);
    final remainingDiffers =
        (lot.originalAmount - lot.remainingAmount).abs() > _epsilon;
    if (activeConsumptions.isNotEmpty || remainingDiffers) {
      final affected = await _resolveAffected(
        lot: lot,
        consumptions: activeConsumptions,
        enrich: txn == null,
      );
      return AtmCorrectionStatus.blocked(
        cashTransactionId: atmCashTransactionId,
        reasonCode: AtmCorrectionReason.cashUsed,
        lotId: lotId,
        affectedTransactions: affected,
      );
    }

    // Cash side is safe. Resolve the fee policy.
    final linkedFees = await _expenseRepository.getActiveExpensesBySourceRef(
      _atmSourceRefType,
      cashTx.id,
      txn: txn,
    );
    if (linkedFees.isNotEmpty) {
      return AtmCorrectionStatus.correctable(
        cashTransactionId: atmCashTransactionId,
        lotId: lotId,
        feeExpenseId: linkedFees.first.id,
      );
    }

    // No linked fee. This is either a genuine no-fee withdrawal or a legacy
    // withdrawal whose fee predates linkage. Only the latter is ambiguous: if
    // the trip has any unlinked ATM-fee orphan we cannot prove this withdrawal
    // is fee-less, so we block it.
    final hasLegacyOrphan = await _expenseRepository
        .hasActiveUnlinkedAtmFeeExpenses(cashTx.tripId, txn: txn);
    if (hasLegacyOrphan) {
      return AtmCorrectionStatus.blocked(
        cashTransactionId: atmCashTransactionId,
        reasonCode: AtmCorrectionReason.legacyUnlinked,
        lotId: lotId,
      );
    }

    return AtmCorrectionStatus.correctable(
      cashTransactionId: atmCashTransactionId,
      lotId: lotId,
    );
  }

  Future<List<AffectedCashUse>> _resolveAffected({
    required CashLot lot,
    required List<CashLotConsumption> consumptions,
    required bool enrich,
  }) async {
    final result = <AffectedCashUse>[];
    for (final c in consumptions) {
      final type = _typeFor(c.consumptionType);
      String? title;
      final referenceId = c.expenseId ?? c.exchangeId;
      if (enrich &&
          type == AffectedCashUseType.cashExpense &&
          c.expenseId != null) {
        try {
          final expense = await _expenseRepository.getExpenseById(c.expenseId!);
          title = expense?.title;
        } catch (_) {
          // Best-effort only — never fail the status query over a missing title.
        }
      }
      result.add(
        AffectedCashUse(
          type: type,
          amount: c.consumedAmount,
          currencyCode: lot.currencyCode,
          date: c.createdAt,
          referenceId: referenceId,
          title: title,
        ),
      );
    }
    return result;
  }

  AffectedCashUseType _typeFor(String consumptionType) {
    switch (consumptionType) {
      case 'cash_expense':
        return AffectedCashUseType.cashExpense;
      case 'exchange_out':
        return AffectedCashUseType.exchange;
      case 'manual_reduction':
      default:
        return AffectedCashUseType.manualReduction;
    }
  }
}
