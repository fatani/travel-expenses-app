/// Value types describing whether a currency exchange can be safely undone or
/// corrected, and — when it cannot — which later transactions consumed the
/// received cash.
///
/// Part of the Exchange Money Safe Undo / Correct sprint. These types carry no
/// behaviour; the decision logic lives in `ExchangeCorrectionService` and the
/// mutation logic in `ReverseCurrencyExchangeUseCase` /
/// `CorrectCurrencyExchangeUseCase`.
library;

/// Why an exchange is not undoable/correctable.
///
/// Mapped to user-facing copy by the presentation layer. Used both as the
/// [ExchangeCorrectionStatus.reasonCode] and as the reason carried by
/// [ExchangeNotCorrectableException].
enum ExchangeCorrectionReason {
  /// No `currency_exchanges` row exists for the supplied id.
  exchangeNotFound,

  /// The exchange row is already reversed — there is nothing to undo.
  exchangeAlreadyReversed,

  /// The exchange's destination lot (`to_lot_id`) could not be loaded.
  destinationLotMissing,

  /// The destination lot is itself reversed (already undone elsewhere).
  destinationLotReversed,

  /// The cash produced by the exchange was (partially) spent or re-exchanged,
  /// so undoing/correcting would silently rewrite later transactions.
  destinationCashUsed,
}

/// The kind of later transaction that consumed exchange-received cash.
enum AffectedCashUseType {
  /// A cash expense drew from the destination lot.
  cashExpense,

  /// A subsequent currency exchange drew from the destination lot.
  exchange,

  /// A manual reduction drew from the destination lot.
  manualReduction,
}

/// One later transaction that consumed cash from the exchange's destination
/// lot, surfaced to the traveller so they know what to fix first.
class AffectedCashUse {
  const AffectedCashUse({
    required this.type,
    required this.amount,
    required this.currencyCode,
    required this.date,
    this.referenceId,
    this.title,
  });

  /// What kind of transaction consumed the cash.
  final AffectedCashUseType type;

  /// Amount drawn from the destination lot (in [currencyCode]).
  final double amount;

  /// Currency of the consumed cash (the exchange destination currency).
  final String currencyCode;

  /// When the consumption happened.
  final DateTime date;

  /// The id of the consuming expense/exchange, when resolvable.
  final String? referenceId;

  /// A best-effort human label (e.g. expense title); may be null.
  final String? title;
}

/// Snapshot of whether a given exchange can be safely undone or corrected.
///
/// [canUndo] and [canCorrect] are only `true` when the destination lot is fully
/// unused. When `false`, [reasonCode] explains why and [affectedTransactions]
/// lists the later cash uses (empty unless the reason is
/// [ExchangeCorrectionReason.destinationCashUsed]).
class ExchangeCorrectionStatus {
  const ExchangeCorrectionStatus({
    required this.exchangeId,
    required this.canUndo,
    required this.canCorrect,
    this.reasonCode,
    this.destinationLotId,
    this.affectedTransactions = const [],
  });

  /// Convenience factory for the fully-correctable case.
  const ExchangeCorrectionStatus.correctable({
    required this.exchangeId,
    required this.destinationLotId,
  })  : canUndo = true,
        canCorrect = true,
        reasonCode = null,
        affectedTransactions = const [];

  /// Convenience factory for the blocked case.
  const ExchangeCorrectionStatus.blocked({
    required this.exchangeId,
    required ExchangeCorrectionReason this.reasonCode,
    this.destinationLotId,
    this.affectedTransactions = const [],
  })  : canUndo = false,
        canCorrect = false;

  final String exchangeId;
  final String? destinationLotId;
  final bool canUndo;
  final bool canCorrect;
  final ExchangeCorrectionReason? reasonCode;
  final List<AffectedCashUse> affectedTransactions;

  /// True when the block is specifically because the received cash was used —
  /// the case where the UI should offer "View affected transactions".
  bool get isBlockedByUsedCash =>
      reasonCode == ExchangeCorrectionReason.destinationCashUsed;
}
