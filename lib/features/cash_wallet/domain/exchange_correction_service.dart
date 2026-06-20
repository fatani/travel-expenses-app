import 'package:sqflite/sqflite.dart';

import '../../expenses/data/expense_repository.dart';
import '../data/cash_lot_consumption_repository.dart';
import '../data/cash_lot_repository.dart';
import '../data/currency_exchange_repository.dart';
import 'cash_lot.dart';
import 'cash_lot_consumption.dart';
import 'currency_exchange.dart';
import 'exchange_correction.dart';

/// Read-only query that decides whether a currency exchange can be safely
/// undone or corrected, and resolves the later transactions that consumed the
/// received cash when it cannot.
///
/// An exchange is correctable/undoable **only** when its destination lot is
/// fully unused:
/// * the exchange exists and is not reversed,
/// * the destination lot exists and is not reversed,
/// * `remainingAmount == originalAmount`,
/// * no active consumptions draw from the destination lot.
class ExchangeCorrectionService {
  ExchangeCorrectionService({
    required CurrencyExchangeRepository exchangeRepository,
    required CashLotRepository lotRepository,
    required CashLotConsumptionRepository consumptionRepository,
    ExpenseRepository? expenseRepository,
  })  : _exchangeRepository = exchangeRepository,
        _lotRepository = lotRepository,
        _consumptionRepository = consumptionRepository,
        _expenseRepository = expenseRepository;

  final CurrencyExchangeRepository _exchangeRepository;
  final CashLotRepository _lotRepository;
  final CashLotConsumptionRepository _consumptionRepository;
  final ExpenseRepository? _expenseRepository;

  static const double _epsilon = 1e-9;

  /// Computes the correction status for [exchangeId].
  ///
  /// Pass [txn] to evaluate inside an existing transaction (used by the
  /// reverse/correct use cases to re-validate just before mutating). When [txn]
  /// is supplied, affected-transaction titles are not enriched (no nested
  /// reads), keeping the in-transaction check cheap.
  Future<ExchangeCorrectionStatus> getStatus(
    String exchangeId, {
    DatabaseExecutor? txn,
  }) async {
    final exchange =
        await _exchangeRepository.getExchangeById(exchangeId, txn: txn);
    if (exchange == null) {
      return ExchangeCorrectionStatus.blocked(
        exchangeId: exchangeId,
        reasonCode: ExchangeCorrectionReason.exchangeNotFound,
      );
    }
    if (exchange.isReversed) {
      return ExchangeCorrectionStatus.blocked(
        exchangeId: exchangeId,
        reasonCode: ExchangeCorrectionReason.exchangeAlreadyReversed,
        destinationLotId: exchange.toLotId,
      );
    }

    final destLot =
        await _lotRepository.getCashLotById(exchange.toLotId, txn: txn);
    if (destLot == null) {
      return ExchangeCorrectionStatus.blocked(
        exchangeId: exchangeId,
        reasonCode: ExchangeCorrectionReason.destinationLotMissing,
        destinationLotId: exchange.toLotId,
      );
    }
    if (destLot.isReversed) {
      return ExchangeCorrectionStatus.blocked(
        exchangeId: exchangeId,
        reasonCode: ExchangeCorrectionReason.destinationLotReversed,
        destinationLotId: destLot.id,
      );
    }

    final activeConsumptions = await _consumptionRepository
        .getActiveConsumptionsByLotId(destLot.id, txn: txn);
    final remainingDiffers =
        (destLot.originalAmount - destLot.remainingAmount).abs() > _epsilon;

    if (activeConsumptions.isNotEmpty || remainingDiffers) {
      final affected = await _resolveAffected(
        destLot: destLot,
        consumptions: activeConsumptions,
        enrich: txn == null,
      );
      return ExchangeCorrectionStatus.blocked(
        exchangeId: exchangeId,
        reasonCode: ExchangeCorrectionReason.destinationCashUsed,
        destinationLotId: destLot.id,
        affectedTransactions: affected,
      );
    }

    return ExchangeCorrectionStatus.correctable(
      exchangeId: exchangeId,
      destinationLotId: destLot.id,
    );
  }

  /// Resolves the destination-lot consumptions into [AffectedCashUse] entries.
  ///
  /// Amount/currency/date/type come straight from the consumption + lot, so the
  /// fact that the cash was used is never hidden even if reference lookups fail.
  /// When [enrich] is true the expense title is best-effort resolved.
  Future<List<AffectedCashUse>> _resolveAffected({
    required CashLot destLot,
    required List<CashLotConsumption> consumptions,
    required bool enrich,
  }) async {
    final result = <AffectedCashUse>[];
    for (final c in consumptions) {
      final type = _typeFor(c.consumptionType);
      String? title;
      final referenceId = c.expenseId ?? c.exchangeId;
      if (enrich &&
          type == AffectedCashUseType.cashExpense &&
          c.expenseId != null &&
          _expenseRepository != null) {
        try {
          final expense = await _expenseRepository.getExpenseById(c.expenseId!);
          title = expense?.title;
        } catch (_) {
          // Best-effort only — never fail the status query over a missing title.
        }
      }
      result.add(
        AffectedCashUse(
          type: type,
          amount: c.consumedAmount,
          currencyCode: destLot.currencyCode,
          date: c.createdAt,
          referenceId: referenceId,
          title: title,
        ),
      );
    }
    return result;
  }

  AffectedCashUseType _typeFor(String consumptionType) {
    switch (consumptionType) {
      case 'cash_expense':
        return AffectedCashUseType.cashExpense;
      case 'exchange_out':
        return AffectedCashUseType.exchange;
      case 'manual_reduction':
      default:
        return AffectedCashUseType.manualReduction;
    }
  }

  /// Reads the destination-lot id for an exchange, used by callers that already
  /// know the exchange is correctable.
  String? destinationLotIdOf(CurrencyExchange exchange) => exchange.toLotId;
}
