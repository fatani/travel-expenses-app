/// Failure reasons for [UpdateCashExpenseUseCase.execute].
enum UpdateCashExpenseFailureReason {
  /// The expense row is already marked [Expense.isReversed] and cannot be
  /// updated.
  alreadyReversed,

  /// At least one active (non-reversed) refund exists for this expense.
  hasActiveRefunds,

  /// After restoring the old FIFO consumptions, the new requested amount still
  /// exceeds the available lot balance.
  insufficientCash,
}

/// Thrown by [UpdateCashExpenseUseCase.execute] when the update cannot proceed.
class UpdateCashExpenseException implements Exception {
  const UpdateCashExpenseException(this.reason, {this.underlyingException});

  final UpdateCashExpenseFailureReason reason;

  /// The original exception that triggered this failure, if any.
  final Object? underlyingException;

  @override
  String toString() => 'UpdateCashExpenseException(reason: $reason)';
}
