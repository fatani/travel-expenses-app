import 'package:sqflite/sqflite.dart';

import '../data/cash_lot_repository.dart';
import 'cash_lot.dart';
import 'insufficient_cash_exception.dart';
import 'lot_consumption_plan.dart';

/// Pure FIFO consumption-planning engine.
///
/// Given a trip, currency, and required amount, [planConsumption] returns an
/// ordered list of [LotConsumptionPlan] objects that describe which lots to
/// draw from and how much to take from each — without performing any DB writes.
///
/// ## FIFO order
/// Lots are consumed oldest-first (`created_at ASC, id ASC`), matching the
/// ordering guaranteed by [CashLotRepository.getOpenLotsForCurrency].
///
/// ## Home-currency cost basis
/// For each lot the engine calculates:
/// ```
/// homeAmount = consumedAmount × lot.effectiveRate
/// ```
/// When a lot has no cost-basis snapshot (`effectiveRate` is null), both
/// [LotConsumptionPlan.homeAmount] and [LotConsumptionPlan.homeCurrencyCode]
/// are left null.
///
/// ## Insufficient balance
/// If the sum of all open-lot remaining amounts is less than [requiredAmount]
/// (with a 1 × 10⁻⁹ epsilon for floating-point tolerance), an
/// [InsufficientCashException] is thrown before any plan entries are produced.
class CashLotFifoEngine {
  const CashLotFifoEngine(this._lotRepository);

  final CashLotRepository _lotRepository;

  /// Computes a FIFO consumption plan for [requiredAmount] units of
  /// [currencyCode] within [tripId].
  ///
  /// Returns a non-empty list of [LotConsumptionPlan]s in FIFO order.
  ///
  /// Throws [InsufficientCashException] when total open balance is too low.
  ///
  /// Pass [txn] to run the underlying lot query inside an existing SQLite
  /// transaction so in-progress writes (e.g. lot restorations performed
  /// earlier in the same transaction) are visible to the planner.
  Future<List<LotConsumptionPlan>> planConsumption({
    required String tripId,
    required String currencyCode,
    required double requiredAmount,
    DatabaseExecutor? txn,
  }) async {
    final lots = await _lotRepository.getOpenLotsForCurrency(
      tripId,
      currencyCode.trim().toUpperCase(),
      txn: txn,
    );
    return _buildPlan(lots, requiredAmount, currencyCode.trim().toUpperCase());
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  List<LotConsumptionPlan> _buildPlan(
    List<CashLot> lots,
    double requiredAmount,
    String currencyCode,
  ) {
    const epsilon = 1e-9;

    // Check total available balance first.
    final available = lots.fold<double>(
      0,
      (sum, lot) => sum + lot.remainingAmount,
    );
    if (available < requiredAmount - epsilon) {
      throw InsufficientCashException(
        required: requiredAmount,
        available: available,
        currencyCode: currencyCode,
      );
    }

    final plans = <LotConsumptionPlan>[];
    var remaining = requiredAmount;

    for (final lot in lots) {
      if (remaining <= epsilon) break;

      // Take the smaller of what is needed vs what the lot holds.
      final consume =
          remaining <= lot.remainingAmount + epsilon ? remaining : lot.remainingAmount;
      // Clamp to the lot's actual remaining to avoid floating-point overshoot.
      final actualConsume =
          consume > lot.remainingAmount ? lot.remainingAmount : consume;

      final remainingAfter = lot.remainingAmount - actualConsume;

      // Derive home-currency cost basis from this lot's effective rate.
      double? homeAmount;
      String? homeCurrencyCode;
      final rate = lot.effectiveRate;
      final homeCode = lot.homeCurrencyCode;
      if (rate != null && homeCode != null) {
        homeAmount = actualConsume * rate;
        homeCurrencyCode = homeCode;
      }

      plans.add(LotConsumptionPlan(
        lotId: lot.id,
        consumedAmount: actualConsume,
        homeAmount: homeAmount,
        homeCurrencyCode: homeCurrencyCode,
        remainingAmountAfter: remainingAfter < epsilon ? 0.0 : remainingAfter,
      ));

      remaining -= actualConsume;
    }

    return plans;
  }
}
