import 'package:sqflite/sqflite.dart';

import 'cash_lot_fifo_engine.dart';
import 'exchange_plan.dart';

/// Plan-only engine for currency exchange cost-basis transfer.
///
/// Given a trip, source currency/amount, and destination currency/amount,
/// [planExchange] orchestrates the FIFO engine to select source lots and
/// computes the [ExchangePlan] — including the transferred cost basis for
/// the destination lot — without performing any DB writes.
///
/// ## Cost-basis transfer rule
/// ```
/// destination.effectiveRate = SUM(sourceLot.homeAmount) / toAmount
/// ```
/// This is a historical-cost transfer, not a revaluation: the home-currency
/// value of the destination lot equals exactly what was paid for the source
/// cash, not the current market rate.
///
/// If ALL source lots lack a cost-basis snapshot, [ExchangePlan.transferredHomeAmount]
/// and [ExchangePlan.destinationEffectiveRate] are null.  If only some source
/// lots have a cost basis the non-null values are summed (partial basis).
///
/// ## Validation
/// | Condition | Exception |
/// |-----------|-----------|
/// | fromCurrency == toCurrency | [ArgumentError] |
/// | fromAmount ≤ 0 | [ArgumentError] |
/// | toAmount ≤ 0 | [ArgumentError] |
/// | Insufficient source balance | [InsufficientCashException] (from FIFO engine) |
class CurrencyExchangeEngine {
  const CurrencyExchangeEngine(this._fifoEngine);

  final CashLotFifoEngine _fifoEngine;

  /// Computes a complete exchange plan.
  ///
  /// Throws [ArgumentError] for invalid inputs.
  /// Throws [InsufficientCashException] when the wallet lacks sufficient
  /// [fromCurrencyCode] balance.
  /// Pass [txn] to plan inside an existing transaction so in-progress writes
  /// (e.g. source lots restored by a prior reversal in the same transaction)
  /// are visible to FIFO selection. Used by the correct-exchange flow.
  Future<ExchangePlan> planExchange({
    required String tripId,
    required String fromCurrencyCode,
    required double fromAmount,
    required String toCurrencyCode,
    required double toAmount,
    DatabaseExecutor? txn,
  }) async {
    final from = fromCurrencyCode.trim().toUpperCase();
    final to = toCurrencyCode.trim().toUpperCase();

    // --- Validation --------------------------------------------------------
    if (from == to) {
      throw ArgumentError.value(
        toCurrencyCode,
        'toCurrencyCode',
        'fromCurrencyCode and toCurrencyCode must differ (both resolved to "$from")',
      );
    }
    if (fromAmount <= 0) {
      throw ArgumentError.value(
        fromAmount,
        'fromAmount',
        'fromAmount must be > 0',
      );
    }
    if (toAmount <= 0) {
      throw ArgumentError.value(
        toAmount,
        'toAmount',
        'toAmount must be > 0',
      );
    }

    // --- FIFO source plan ---------------------------------------------------
    final sourcePlans = await _fifoEngine.planConsumption(
      tripId: tripId,
      currencyCode: from,
      requiredAmount: fromAmount,
      txn: txn,
    );

    // --- Cost-basis transfer ------------------------------------------------
    // Sum non-null homeAmounts.  Null only when ALL source lots lack a basis.
    double? transferredHomeAmount;
    String? homeCurrencyCode;

    for (final plan in sourcePlans) {
      final h = plan.homeAmount;
      if (h != null) {
        transferredHomeAmount = (transferredHomeAmount ?? 0.0) + h;
        homeCurrencyCode ??= plan.homeCurrencyCode;
      }
    }

    // --- Destination effective rate -----------------------------------------
    final destinationEffectiveRate = transferredHomeAmount != null
        ? transferredHomeAmount / toAmount
        : null;

    return ExchangePlan(
      fromCurrencyCode: from,
      fromAmount: fromAmount,
      toCurrencyCode: to,
      toAmount: toAmount,
      exchangeRate: toAmount / fromAmount,
      transferredHomeAmount: transferredHomeAmount,
      homeCurrencyCode: homeCurrencyCode,
      destinationEffectiveRate: destinationEffectiveRate,
      sourcePlans: sourcePlans,
    );
  }
}
