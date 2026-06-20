import '../../../core/database/app_database.dart';
import 'atm_withdrawal_result.dart';
import 'record_atm_withdrawal_use_case.dart';
import 'reverse_atm_withdrawal_use_case.dart';

/// Safely corrects an ATM withdrawal whose generated cash has not been used.
///
/// Correction is **not** an in-place edit. It is modelled as:
/// ```
/// reverse the original ATM withdrawal  +  record a new corrected withdrawal
/// ```
/// Both halves run in a single atomic transaction, so a failure in either half
/// rolls the whole thing back — the original is never left half-reversed.
///
/// The caller is responsible for only invoking this after the user confirms the
/// corrected values; opening the correction sheet must NOT trigger a reversal.
class CorrectAtmWithdrawalUseCase {
  CorrectAtmWithdrawalUseCase({
    required AppDatabase appDatabase,
    required ReverseAtmWithdrawalUseCase reverseUseCase,
    required RecordAtmWithdrawalUseCase recordUseCase,
  })  : _appDatabase = appDatabase,
        _reverseUseCase = reverseUseCase,
        _recordUseCase = recordUseCase;

  final AppDatabase _appDatabase;
  final ReverseAtmWithdrawalUseCase _reverseUseCase;
  final RecordAtmWithdrawalUseCase _recordUseCase;

  /// Reverses [originalAtmCashTransactionId] and records a corrected ATM
  /// withdrawal with the supplied values, atomically.
  ///
  /// [chargedAmount]/[feeAmount] are denominated in [homeCurrencyCode] (the
  /// charged total is what the bank debited; the received cash stays in
  /// [receivedCurrency], locked to the trip currency by the UI).
  ///
  /// Throws [AtmNotCorrectableException] (from the reverse step) when the
  /// original is no longer correctable — leaving it untouched. Throws
  /// [ArgumentError] (from the record step) for invalid corrected values, also
  /// rolling back the reverse.
  Future<AtmWithdrawalResult> execute({
    required String tripId,
    required String originalAtmCashTransactionId,
    required double receivedAmount,
    required String receivedCurrency,
    double? chargedAmount,
    double? feeAmount,
    int? fundingCardId,
    String? homeCurrencyCode,
    String? note,
    DateTime? createdAt,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      // Reverse first; this re-validates correctability and rolls back the
      // whole transaction if the original is no longer safe to touch.
      await _reverseUseCase.reverseInTransaction(
        txn,
        originalAtmCashTransactionId,
      );

      // Record the corrected withdrawal in the same transaction.
      return _recordUseCase.recordInTransaction(
        txn,
        tripId: tripId,
        receivedAmount: receivedAmount,
        receivedCurrency: receivedCurrency,
        chargedAmount: chargedAmount,
        chargedCurrency: chargedAmount != null ? homeCurrencyCode : null,
        feeAmount: feeAmount,
        feeCurrency: feeAmount != null ? homeCurrencyCode : null,
        fundingCardId: fundingCardId,
        homeCurrencyCode: homeCurrencyCode,
        note: note,
        createdAt: createdAt,
      );
    });
  }
}
