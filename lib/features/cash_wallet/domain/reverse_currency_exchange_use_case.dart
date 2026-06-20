import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../data/cash_lot_consumption_repository.dart';
import '../data/cash_lot_repository.dart';
import '../data/cash_wallet_repository.dart';
import '../data/currency_exchange_repository.dart';
import 'currency_exchange.dart';
import 'exchange_correction.dart';
import 'exchange_correction_service.dart';
import 'exchange_not_correctable_exception.dart';

/// Safely reverses (undoes) a single currency exchange whose received cash has
/// not been used.
///
/// Reversing means: restore the source cash, remove the destination cash, and
/// mark the exchange + its lot/consumptions/cash-transactions reversed — never
/// hard-deleting or editing any row. Balances behave as if the exchange never
/// happened.
///
/// This is the **Undo** operation. The corrected-exchange flow
/// (`CorrectCurrencyExchangeUseCase`) reuses [reverseInTransaction] so the
/// reverse-of-original and the new exchange share one atomic transaction.
class ReverseCurrencyExchangeUseCase {
  ReverseCurrencyExchangeUseCase({
    required AppDatabase appDatabase,
    required ExchangeCorrectionService correctionService,
    required CurrencyExchangeRepository exchangeRepository,
    required CashLotRepository lotRepository,
    required CashLotConsumptionRepository consumptionRepository,
    required CashWalletRepository cashWalletRepository,
  })  : _appDatabase = appDatabase,
        _correctionService = correctionService,
        _exchangeRepository = exchangeRepository,
        _lotRepository = lotRepository,
        _consumptionRepository = consumptionRepository,
        _cashWalletRepository = cashWalletRepository;

  final AppDatabase _appDatabase;
  final ExchangeCorrectionService _correctionService;
  final CurrencyExchangeRepository _exchangeRepository;
  final CashLotRepository _lotRepository;
  final CashLotConsumptionRepository _consumptionRepository;
  final CashWalletRepository _cashWalletRepository;

  /// Undoes the exchange [exchangeId] in its own atomic transaction.
  ///
  /// Throws [ExchangeNotCorrectableException] when the exchange is missing,
  /// already reversed, or its destination cash was used — in which case nothing
  /// is mutated.
  Future<CurrencyExchange> execute(String exchangeId) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) => reverseInTransaction(txn, exchangeId));
  }

  /// Reverses [exchangeId] inside the caller-supplied [txn].
  ///
  /// Re-validates correctability against the live (in-transaction) state before
  /// mutating, so a concurrent spend cannot slip through. Returns the original
  /// (now-reversed) exchange.
  Future<CurrencyExchange> reverseInTransaction(
    DatabaseExecutor txn,
    String exchangeId,
  ) async {
    final status = await _correctionService.getStatus(exchangeId, txn: txn);
    if (!status.canUndo) {
      throw ExchangeNotCorrectableException(
        exchangeId: exchangeId,
        reason: status.reasonCode ?? ExchangeCorrectionReason.destinationCashUsed,
        affectedTransactions: status.affectedTransactions,
      );
    }

    final exchange =
        await _exchangeRepository.getExchangeById(exchangeId, txn: txn);
    // getStatus already guaranteed a non-reversed exchange exists, but guard.
    if (exchange == null) {
      throw const ExchangeNotCorrectableException(
        exchangeId: '',
        reason: ExchangeCorrectionReason.exchangeNotFound,
      );
    }

    // 1. Restore each source lot by the amount the exchange drew from it.
    final sourceConsumptions = await _consumptionRepository
        .getActiveConsumptionsByExchangeId(exchangeId, txn: txn);
    for (final consumption in sourceConsumptions) {
      await _lotRepository.restoreLotConsumption(
        consumption.lotId,
        consumption.consumedAmount,
        txn: txn,
      );
    }

    // 2. Mark those source consumptions reversed.
    await _consumptionRepository.markConsumptionsReversedForExchange(
      txn,
      exchangeId,
    );

    // 3. Reverse the destination lot (the received cash, proven unused).
    await _lotRepository.markLotReversed(exchange.toLotId, txn: txn);

    // 4. Reverse both exchange cash transactions and restore balances
    //    (source +fromAmount, destination −toAmount).
    await _cashWalletRepository.reverseCurrencyExchangeTransactionsInTxn(
      txn,
      exchangeId: exchangeId,
    );

    // 5. Mark the exchange row reversed (records reversedAt).
    await _exchangeRepository.markExchangeReversed(exchangeId, txn: txn);

    return exchange;
  }
}
