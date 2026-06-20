/// Value types describing whether an ATM withdrawal can be safely undone or
/// corrected, and — when it cannot — which later transactions consumed the
/// received cash.
///
/// ATM Safe Undo / Correct v1. These types carry no behaviour; the decision
/// logic lives in `AtmCorrectionService` and the mutation logic in
/// `ReverseAtmWithdrawalUseCase` / `CorrectAtmWithdrawalUseCase`.
library;

import 'exchange_correction.dart' show AffectedCashUse;

/// Why an ATM withdrawal is not undoable/correctable.
///
/// Mapped to user-facing copy by the presentation layer.
enum AtmCorrectionReason {
  /// Correctable — no blocking reason.
  none,

  /// No `cash_transactions` row exists for the supplied id.
  cashTransactionNotFound,

  /// The row exists but is not an `atm_withdrawal`.
  notAtmWithdrawal,

  /// The ATM cash transaction is already reversed — nothing to undo.
  alreadyReversed,

  /// The generated cash lot is missing or itself reversed.
  lotMissing,

  /// The cash produced by the withdrawal was (partially) spent or exchanged,
  /// so undoing/correcting would silently rewrite later transactions.
  cashUsed,

  /// A fee might belong to this withdrawal but cannot be reliably linked
  /// (legacy row created before fee linkage). Blocked to avoid orphaning it.
  legacyUnlinked,
}

/// Snapshot of whether a given ATM withdrawal can be safely undone or corrected.
///
/// [canUndo]/[canCorrect] are only `true` when the generated lot is fully
/// unused **and** any fee is safely identifiable. When `false`, [reasonCode]
/// explains why and [affectedTransactions] lists the later cash uses (empty
/// unless the reason is [AtmCorrectionReason.cashUsed]).
class AtmCorrectionStatus {
  const AtmCorrectionStatus({
    required this.cashTransactionId,
    required this.canUndo,
    required this.canCorrect,
    this.reasonCode = AtmCorrectionReason.none,
    this.lotId,
    this.feeExpenseId,
    this.affectedTransactions = const [],
  });

  /// Convenience factory for the fully-correctable case.
  const AtmCorrectionStatus.correctable({
    required this.cashTransactionId,
    required this.lotId,
    this.feeExpenseId,
  })  : canUndo = true,
        canCorrect = true,
        reasonCode = AtmCorrectionReason.none,
        affectedTransactions = const [];

  /// Convenience factory for the blocked case.
  const AtmCorrectionStatus.blocked({
    required this.cashTransactionId,
    required this.reasonCode,
    this.lotId,
    this.feeExpenseId,
    this.affectedTransactions = const [],
  })  : canUndo = false,
        canCorrect = false;

  final String cashTransactionId;
  final String? lotId;

  /// The linked ATM fee expense id, when one is safely identified. Null when
  /// the withdrawal has no fee.
  final String? feeExpenseId;
  final bool canUndo;
  final bool canCorrect;
  final AtmCorrectionReason reasonCode;
  final List<AffectedCashUse> affectedTransactions;

  /// True when the block is specifically because the received cash was used —
  /// the case where the UI offers "View affected transactions".
  bool get isBlockedByUsedCash => reasonCode == AtmCorrectionReason.cashUsed;

  /// True when the block is because a legacy/unlinked fee makes safe correction
  /// impossible — the UI shows "Correction unavailable".
  bool get isUnavailable => reasonCode == AtmCorrectionReason.legacyUnlinked;
}
