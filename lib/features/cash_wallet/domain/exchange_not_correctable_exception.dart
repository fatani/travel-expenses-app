import 'exchange_correction.dart';

/// Thrown when an attempt is made to undo or correct a currency exchange that
/// is not in a safe state to do so (already reversed, missing, or its received
/// cash was already used).
///
/// This is an expected business-rule failure — callers should catch it and show
/// guidance, never treat it as a crash. The [reason] drives the message and the
/// [affectedTransactions] (when [ExchangeCorrectionReason.destinationCashUsed])
/// let the UI list what must be fixed first.
class ExchangeNotCorrectableException implements Exception {
  const ExchangeNotCorrectableException({
    required this.exchangeId,
    required this.reason,
    this.affectedTransactions = const [],
  });

  final String exchangeId;
  final ExchangeCorrectionReason reason;
  final List<AffectedCashUse> affectedTransactions;

  @override
  String toString() =>
      'ExchangeNotCorrectableException(exchangeId: $exchangeId, '
      'reason: $reason, affected: ${affectedTransactions.length})';
}
