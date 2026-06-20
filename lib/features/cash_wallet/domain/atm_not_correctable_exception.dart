import 'atm_correction.dart';
import 'exchange_correction.dart' show AffectedCashUse;

/// Thrown when an attempt is made to undo or correct an ATM withdrawal that is
/// not in a safe state to do so (already reversed, missing lot, its received
/// cash was already used, or a legacy fee cannot be safely linked).
///
/// This is an expected business-rule failure — callers should catch it and show
/// guidance, never treat it as a crash. The [reason] drives the message and the
/// [affectedTransactions] (when [AtmCorrectionReason.cashUsed]) let the UI list
/// what must be fixed first.
class AtmNotCorrectableException implements Exception {
  const AtmNotCorrectableException({
    required this.cashTransactionId,
    required this.reason,
    this.affectedTransactions = const [],
  });

  final String cashTransactionId;
  final AtmCorrectionReason reason;
  final List<AffectedCashUse> affectedTransactions;

  @override
  String toString() =>
      'AtmNotCorrectableException(cashTransactionId: $cashTransactionId, '
      'reason: $reason, affected: ${affectedTransactions.length})';
}
