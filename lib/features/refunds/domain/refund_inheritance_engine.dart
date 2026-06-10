import 'over_refund_exception.dart';
import 'refund_destination.dart';
import 'refund_plan.dart';

/// Pure domain engine that computes a refund cost-basis plan.
///
/// All methods are synchronous — the engine performs no DB access.  The caller
/// is responsible for pre-fetching any expense data needed for the over-refund
/// guard and passing it in.
///
/// ## Cash refund — linked
/// When [expenseId] is non-null the engine inherits the expense's cost basis:
/// the new cash lot receives [homeAmount] / [homeCurrency] as its basis and
/// `effectiveRate = homeAmount / refundAmount`.
///
/// ## Cash refund — unlinked
/// When [expenseId] is null, [homeAmount] and [homeCurrency] are **required**.
/// The lot receives the caller-supplied basis directly.
///
/// ## Card refund
/// No cash lot is created ([RefundPlan.shouldCreateCashLot] == false).
/// [homeAmount] is optional for both linked and unlinked card refunds.
///
/// ## Over-refund guard
/// When a linked expense has a known home-currency amount and the new refund
/// would push the total above that amount, [OverRefundException] is thrown.
///
/// ## Validation
/// | Condition | Exception |
/// |-----------|-----------|
/// | refundAmount ≤ 0 | [ArgumentError] |
/// | homeAmount provided without homeCurrency (or vice versa) | [ArgumentError] |
/// | Unlinked cash refund with no homeAmount | [ArgumentError] |
/// | Over-refund detected | [OverRefundException] |
class RefundInheritanceEngine {
  const RefundInheritanceEngine();

  /// Plans a **cash** refund.
  ///
  /// Parameters:
  /// * [expenseId] — the expense being refunded; null for unlinked refunds.
  /// * [refundAmount] — face-value amount being refunded (must be > 0).
  /// * [refundCurrency] — currency of the refund (will be upper-cased).
  /// * [homeAmount] — home-currency amount; required when [expenseId] is null.
  /// * [homeCurrency] — home-currency code; required when [homeAmount] is
  ///   non-null.
  /// * [linkedExpenseHomeAmount] — the expense's [convertedHomeAmount]; used
  ///   for the over-refund guard.
  /// * [linkedExpenseHomeCurrency] — home-currency code of the linked expense.
  /// * [existingRefundsHomeTotal] — sum of [homeAmount] of all active (non-
  ///   reversed) refunds already recorded for [expenseId].  Defaults to 0.
  RefundPlan planCashRefund({
    String? expenseId,
    required double refundAmount,
    required String refundCurrency,
    double? homeAmount,
    String? homeCurrency,
    double? linkedExpenseHomeAmount,
    String? linkedExpenseHomeCurrency,
    double existingRefundsHomeTotal = 0.0,
  }) {
    _validateCommon(
      expenseId: expenseId,
      refundAmount: refundAmount,
      homeAmount: homeAmount,
      homeCurrency: homeCurrency,
      destination: RefundDestination.cash,
    );

    _assertOverRefundGuard(
      homeAmount: homeAmount,
      linkedExpenseHomeAmount: linkedExpenseHomeAmount,
      linkedExpenseHomeCurrency: linkedExpenseHomeCurrency,
      existingRefundsHomeTotal: existingRefundsHomeTotal,
    );

    final currency = refundCurrency.trim().toUpperCase();
    final homeCurrencyNorm = homeCurrency?.trim().toUpperCase();
    final effectiveRate =
        (homeAmount != null && refundAmount > 0) ? homeAmount / refundAmount : null;

    return RefundPlan(
      destination: RefundDestination.cash,
      shouldCreateCashLot: true,
      refundAmount: refundAmount,
      refundCurrency: currency,
      cashLotAmount: refundAmount,
      cashLotCurrency: currency,
      inheritedHomeAmount: homeAmount,
      inheritedHomeCurrency: homeCurrencyNorm,
      effectiveRate: effectiveRate,
      isUnlinked: expenseId == null,
      linkedExpenseId: expenseId,
    );
  }

  /// Plans a **card** refund.
  ///
  /// Card refunds never create a cash lot and have no wallet impact.
  /// [homeAmount] is optional regardless of whether the refund is linked.
  ///
  /// Parameters are identical to [planCashRefund] except that an unlinked
  /// card refund with [homeAmount] == null is accepted.
  RefundPlan planCardRefund({
    String? expenseId,
    required double refundAmount,
    required String refundCurrency,
    double? homeAmount,
    String? homeCurrency,
    double? linkedExpenseHomeAmount,
    String? linkedExpenseHomeCurrency,
    double existingRefundsHomeTotal = 0.0,
  }) {
    _validateCommon(
      expenseId: expenseId,
      refundAmount: refundAmount,
      homeAmount: homeAmount,
      homeCurrency: homeCurrency,
      destination: RefundDestination.card,
    );

    _assertOverRefundGuard(
      homeAmount: homeAmount,
      linkedExpenseHomeAmount: linkedExpenseHomeAmount,
      linkedExpenseHomeCurrency: linkedExpenseHomeCurrency,
      existingRefundsHomeTotal: existingRefundsHomeTotal,
    );

    final currency = refundCurrency.trim().toUpperCase();
    final homeCurrencyNorm = homeCurrency?.trim().toUpperCase();

    return RefundPlan(
      destination: RefundDestination.card,
      shouldCreateCashLot: false,
      refundAmount: refundAmount,
      refundCurrency: currency,
      cashLotAmount: null,
      cashLotCurrency: null,
      inheritedHomeAmount: homeAmount,
      inheritedHomeCurrency: homeCurrencyNorm,
      effectiveRate: null, // card refunds don't produce a lot, so no rate
      isUnlinked: expenseId == null,
      linkedExpenseId: expenseId,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _validateCommon({
    required String? expenseId,
    required double refundAmount,
    required double? homeAmount,
    required String? homeCurrency,
    required RefundDestination destination,
  }) {
    // refundAmount must be positive.
    if (refundAmount <= 0) {
      throw ArgumentError.value(
        refundAmount,
        'refundAmount',
        'refundAmount must be > 0',
      );
    }

    // homeAmount and homeCurrency must both be present or both absent.
    if (homeAmount != null && (homeCurrency == null || homeCurrency.trim().isEmpty)) {
      throw ArgumentError(
        'homeCurrency is required when homeAmount is provided',
      );
    }
    if (homeCurrency != null && homeCurrency.trim().isNotEmpty && homeAmount == null) {
      throw ArgumentError(
        'homeAmount is required when homeCurrency is provided',
      );
    }

    // Unlinked cash refunds require a home-currency amount for the lot basis.
    if (destination == RefundDestination.cash && expenseId == null && homeAmount == null) {
      throw ArgumentError(
        'homeAmount and homeCurrency are required for unlinked cash refunds',
      );
    }
  }

  void _assertOverRefundGuard({
    required double? homeAmount,
    required double? linkedExpenseHomeAmount,
    required String? linkedExpenseHomeCurrency,
    required double existingRefundsHomeTotal,
  }) {
    if (homeAmount == null) return;
    if (linkedExpenseHomeAmount == null) return;
    if (linkedExpenseHomeCurrency == null) return;

    const epsilon = 1e-6;
    if (existingRefundsHomeTotal + homeAmount > linkedExpenseHomeAmount + epsilon) {
      throw OverRefundException(
        requested: homeAmount,
        existing: existingRefundsHomeTotal,
        limit: linkedExpenseHomeAmount,
      );
    }
  }
}
