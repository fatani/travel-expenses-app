import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../data/cash_lot_consumption_repository.dart';
import '../data/cash_lot_repository.dart';
import '../data/cash_wallet_repository.dart';
import '../data/currency_exchange_repository.dart';
import 'cash_lot.dart';
import 'cash_lot_consumption.dart';
import 'currency_exchange.dart';
import 'currency_exchange_engine.dart';
import 'currency_exchange_result.dart';

/// Use case that records a currency exchange atomically:
///
/// 1. Calls [CurrencyExchangeEngine.planExchange] — validates inputs, selects
///    source lots FIFO, computes transferred cost basis.  Throws before any
///    DB write if inputs are invalid or balance is insufficient.
/// 2. Opens one SQLite transaction containing:
///    a. Insert destination [cash_lots] row
///       (source_type = 'currency_exchange', sourceRefId patched afterwards).
///    b. Insert [cash_transactions] exchange_out row (fromCurrency, −fromAmount).
///    c. Insert [cash_transactions] exchange_in row (toCurrency, +toAmount,
///       lot_id = destination lot).
///    d. Insert [currency_exchanges] row (to_lot_id = destination lot).
///    e. Patch destination lot source_ref_id = exchange.id.
///    f. For each source lot in FIFO order:
///       - Insert [cash_lot_consumptions] row linked to the exchange.
///       - Update source lot remaining_amount.
///    g. Update [trip_cash_balances] (−fromAmount, +toAmount) — done inside
///       steps b & c via the wallet repository helpers.
///
/// ## Cost-basis rule (Transfer, not Revaluation)
///
/// ```
/// destinationLot.homeCurrencyAmount = plan.transferredHomeAmount
/// destinationLot.effectiveRate      = plan.destinationEffectiveRate
/// ```
///
/// The spot exchange rate is stored in [CurrencyExchange.exchangeRate] only
/// and never used to compute the destination lot's cost basis.
///
/// ## Atomicity
///
/// Any failure rolls back every write — no partial lot, no partial exchange,
/// no partial balance changes, no partial consumptions.
class RecordCurrencyExchangeUseCase {
  RecordCurrencyExchangeUseCase({
    required AppDatabase appDatabase,
    required CurrencyExchangeEngine exchangeEngine,
    required CashWalletRepository cashWalletRepository,
    required CashLotRepository lotRepository,
    required CashLotConsumptionRepository consumptionRepository,
    required CurrencyExchangeRepository exchangeRepository,
    Uuid? uuid,
  })  : _appDatabase = appDatabase,
        _exchangeEngine = exchangeEngine,
        _cashWalletRepository = cashWalletRepository,
        _lotRepository = lotRepository,
        _consumptionRepository = consumptionRepository,
        _exchangeRepository = exchangeRepository,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final CurrencyExchangeEngine _exchangeEngine;
  final CashWalletRepository _cashWalletRepository;
  final CashLotRepository _lotRepository;
  final CashLotConsumptionRepository _consumptionRepository;
  final CurrencyExchangeRepository _exchangeRepository;
  final Uuid _uuid;

  /// Records a currency exchange.
  ///
  /// [fromCurrencyCode] — the currency being sold / drawn from.
  /// [fromAmount]       — amount consumed from the source wallet (> 0).
  /// [toCurrencyCode]   — the currency being acquired.
  /// [toAmount]         — amount credited to the destination wallet (> 0).
  /// [note]             — free-text note on both cash transactions.
  /// [createdAt]        — timestamp; defaults to now.
  ///
  /// Throws [ArgumentError] for invalid inputs (same currency, non-positive
  /// amounts).
  /// Throws [InsufficientCashException] when the wallet has insufficient
  /// [fromCurrencyCode] balance.
  Future<CurrencyExchangeResult> execute({
    required String tripId,
    required String fromCurrencyCode,
    required double fromAmount,
    required String toCurrencyCode,
    required double toAmount,
    String? note,
    DateTime? createdAt,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) {
      return recordInTransaction(
        txn,
        tripId: tripId,
        fromCurrencyCode: fromCurrencyCode,
        fromAmount: fromAmount,
        toCurrencyCode: toCurrencyCode,
        toAmount: toAmount,
        note: note,
        createdAt: createdAt,
      );
    });
  }

  /// Records a currency exchange inside the caller-supplied [txn].
  ///
  /// Used directly by the correct-exchange flow so the reverse-of-original and
  /// the recording of the corrected exchange share one atomic transaction (the
  /// plan runs inside [txn] so source lots restored by the reverse are visible
  /// to FIFO). [execute] wraps this in its own transaction.
  Future<CurrencyExchangeResult> recordInTransaction(
    DatabaseExecutor txn, {
    required String tripId,
    required String fromCurrencyCode,
    required double fromAmount,
    required String toCurrencyCode,
    required double toAmount,
    String? note,
    DateTime? createdAt,
  }) async {
    // ── 1. Plan (validates + FIFO) — no DB writes ──────────────────────────
    final plan = await _exchangeEngine.planExchange(
      tripId: tripId,
      fromCurrencyCode: fromCurrencyCode,
      fromAmount: fromAmount,
      toCurrencyCode: toCurrencyCode,
      toAmount: toAmount,
      txn: txn,
    );

    final timestamp = (createdAt ?? DateTime.now()).toUtc();
    final destLotId = _uuid.v4();
    // Generate the exchange id up front so both exchange cash transactions can
    // carry exchange_id, giving undo/correct a reliable link to reverse them.
    final exchangeId = _uuid.v4();

    // ── 2. Build destination lot. The exchange id is known up front, so the
    //       lot's source_ref_id is set directly (no post-insert patch).
    final destLot = CashLot.create(
      id: destLotId,
      tripId: tripId,
      sourceType: 'exchange_in',
      sourceRefType: 'currency_exchange',
      sourceRefId: exchangeId,
      currencyCode: plan.toCurrencyCode,
      originalAmount: toAmount,
      remainingAmount: toAmount,
      homeCurrencyAmount: plan.transferredHomeAmount,
      homeCurrencyCode: plan.homeCurrencyCode,
      effectiveRate: plan.destinationEffectiveRate,
      createdAt: timestamp,
      note: note,
    );

    // ── 3. Writes (atomic — caller owns the transaction) ───────────────────
    // Write order respects FKs: the destination lot and the currency_exchanges
    // row must exist before the cash transactions reference them (lot_id /
    // exchange_id), and before the source consumptions reference the exchange.

    // a. Insert destination lot (to_lot_id target for the exchange row).
    final insertedLot = await _lotRepository.insertCashLot(destLot, txn: txn);

    // b. Insert currency_exchanges row (id pre-generated so the cash
    //    transactions below can carry exchange_id).
    final exchange = await _exchangeRepository.insertCurrencyExchange(
      CurrencyExchange.create(
        id: exchangeId,
        tripId: tripId,
        fromCurrencyCode: plan.fromCurrencyCode,
        fromAmount: plan.fromAmount,
        toCurrencyCode: plan.toCurrencyCode,
        toAmount: plan.toAmount,
        exchangeRate: plan.exchangeRate,
        toLotId: insertedLot.id,
        note: note,
        createdAt: timestamp,
      ),
      txn: txn,
    );

    // c. Exchange-out transaction (fromCurrency, −fromAmount, updates balance).
    final outTx = await _cashWalletRepository.recordCurrencyExchangeOutflow(
      txn: txn,
      tripId: tripId,
      fromAmount: plan.fromAmount,
      fromCurrencyCode: plan.fromCurrencyCode,
      exchangeId: exchangeId,
      note: note,
      createdAt: timestamp,
    );

    // d. Exchange-in transaction (toCurrency, +toAmount, lot_id=destLotId).
    final inTx = await _cashWalletRepository.recordCurrencyExchangeInflow(
      txn: txn,
      tripId: tripId,
      toLotId: insertedLot.id,
      toAmount: plan.toAmount,
      toCurrencyCode: plan.toCurrencyCode,
      exchangeId: exchangeId,
      note: note,
      createdAt: timestamp,
    );

    // e. Consumptions + source lot updates
    final consumptions = <CashLotConsumption>[];
    for (final sourcePlan in plan.sourcePlans) {
      final consumption = await _consumptionRepository.insertConsumption(
        CashLotConsumption.create(
          lotId: sourcePlan.lotId,
          consumptionType: 'exchange_out',
          exchangeId: exchange.id,
          consumedAmount: sourcePlan.consumedAmount,
          homeAmount: sourcePlan.homeAmount,
          homeCurrencyCode: sourcePlan.homeCurrencyCode,
          createdAt: timestamp,
        ),
        txn: txn,
      );
      consumptions.add(consumption);

      await _lotRepository.updateLotRemainingAmount(
        sourcePlan.lotId,
        sourcePlan.remainingAmountAfter,
        txn: txn,
      );
    }

    return CurrencyExchangeResult(
      exchange: exchange,
      destinationLot: insertedLot.copyWith(sourceRefId: exchange.id),
      exchangeOutTransaction: outTx,
      exchangeInTransaction: inTx,
      consumptions: consumptions,
    );
  }
}
