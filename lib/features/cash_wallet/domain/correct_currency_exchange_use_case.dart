import '../../../core/database/app_database.dart';
import 'currency_exchange_result.dart';
import 'record_currency_exchange_use_case.dart';
import 'reverse_currency_exchange_use_case.dart';

/// Safely corrects a currency exchange whose received cash has not been used.
///
/// Correction is **not** an in-place edit. It is modelled as:
/// ```
/// reverse the original exchange  +  record a new corrected exchange
/// ```
/// Both halves run in a single atomic transaction, so the source lots restored
/// by the reverse are visible to the new exchange's FIFO planning, and a
/// failure in either half rolls the whole thing back — the original is never
/// left half-reversed.
///
/// The caller is responsible for only invoking this after the user confirms the
/// corrected values; opening the correction sheet must NOT trigger a reversal.
class CorrectCurrencyExchangeUseCase {
  CorrectCurrencyExchangeUseCase({
    required AppDatabase appDatabase,
    required ReverseCurrencyExchangeUseCase reverseUseCase,
    required RecordCurrencyExchangeUseCase recordUseCase,
  })  : _appDatabase = appDatabase,
        _reverseUseCase = reverseUseCase,
        _recordUseCase = recordUseCase;

  final AppDatabase _appDatabase;
  final ReverseCurrencyExchangeUseCase _reverseUseCase;
  final RecordCurrencyExchangeUseCase _recordUseCase;

  /// Reverses [originalExchangeId] and records a corrected exchange with the
  /// supplied amounts, atomically.
  ///
  /// Throws [ExchangeNotCorrectableException] (from the reverse step) when the
  /// original is no longer correctable — leaving it untouched. Throws
  /// [ArgumentError] / [InsufficientCashException] (from the record step) for
  /// invalid corrected values, also rolling back the reverse.
  Future<CurrencyExchangeResult> execute({
    required String originalExchangeId,
    required String fromCurrencyCode,
    required double fromAmount,
    required String toCurrencyCode,
    required double toAmount,
    String? note,
    DateTime? createdAt,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      // Reverse first; this also re-validates correctability and returns the
      // original so we inherit its trip.
      final original =
          await _reverseUseCase.reverseInTransaction(txn, originalExchangeId);

      // Record the corrected exchange in the same transaction — restored source
      // lots are now visible to FIFO.
      return _recordUseCase.recordInTransaction(
        txn,
        tripId: original.tripId,
        fromCurrencyCode: fromCurrencyCode,
        fromAmount: fromAmount,
        toCurrencyCode: toCurrencyCode,
        toAmount: toAmount,
        note: note,
        createdAt: createdAt,
      );
    });
  }
}
