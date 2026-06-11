import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/cash_lot.dart';

/// Idempotent backfill for pre–Sprint 9A cash inflow transactions that have no
/// linked [cash_lots] row (`lot_id IS NULL`).
///
/// Safe to run on every database open and during schema upgrade: only touches
/// active inflow rows with no [cash_transactions.lot_id] and creates at most
/// one lot per eligible transaction.
class CashLotBackfill {
  CashLotBackfill({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  static const _inflowTypes = [
    'initial_cash',
    'manual_adjustment',
    'atm_withdrawal',
    'cash_refund',
    'currency_exchange_in',
  ];

  /// Returns how many cash transactions were linked to a (new or existing) lot.
  Future<int> backfillUnlinkedInflowLots(DatabaseExecutor db) async {
    final rows = await db.query(
      AppDatabase.cashTransactionsTable,
      where:
          'is_reversed = 0 AND lot_id IS NULL AND type IN (${_inflowTypes.map((_) => '?').join(', ')}) AND amount > 0',
      whereArgs: _inflowTypes,
      orderBy: 'created_at ASC, id ASC',
    );

    var linked = 0;
    for (final row in rows) {
      final didLink = await _backfillRow(db, row);
      if (didLink) {
        linked++;
      }
    }
    return linked;
  }

  Future<bool> _backfillRow(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final transactionId = row['id']! as String;

    // Re-check under concurrency / repeated calls.
    final stillUnlinked = await db.query(
      AppDatabase.cashTransactionsTable,
      columns: ['lot_id'],
      where: 'id = ? AND is_reversed = 0 AND lot_id IS NULL',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (stillUnlinked.isEmpty) {
      return false;
    }

    // Repair path: lot already exists for this transaction but lot_id was not set.
    final existingByRef = await db.query(
      AppDatabase.cashLotsTable,
      where:
          "source_ref_type = 'cash_transaction' AND source_ref_id = ? AND is_reversed = 0",
      whereArgs: [transactionId],
      limit: 1,
    );
    if (existingByRef.isNotEmpty) {
      await _linkTransactionToLot(
        db,
        transactionId: transactionId,
        lotId: existingByRef.first['id']! as String,
      );
      return true;
    }

    final type = row['type']! as String;
    switch (type) {
      case 'currency_exchange_in':
        if (await _backfillCurrencyExchangeIn(db, row)) {
          return true;
        }
      case 'cash_refund':
        if (await _backfillCashRefund(db, row)) {
          return true;
        }
      default:
        break;
    }

    return _createLotForTransaction(db, row);
  }

  Future<bool> _backfillCurrencyExchangeIn(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final transactionId = row['id']! as String;
    final tripId = row['trip_id']! as String;
    final amount = (row['amount'] as num).toDouble();
    final currency = (row['currency_code'] as String).trim().toUpperCase();
    final exchangeId = row['exchange_id'] as String?;

    Map<String, Object?>? exchangeRow;
    if (exchangeId != null) {
      final rows = await db.query(
        AppDatabase.currencyExchangesTable,
        where: 'id = ? AND is_reversed = 0',
        whereArgs: [exchangeId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        exchangeRow = rows.first;
      }
    } else {
      final rows = await db.query(
        AppDatabase.currencyExchangesTable,
        where:
            'trip_id = ? AND to_currency_code = ? AND to_amount = ? AND is_reversed = 0',
        whereArgs: [tripId, currency, amount],
        orderBy: 'created_at ASC',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        exchangeRow = rows.first;
      }
    }

    if (exchangeRow == null) {
      return false;
    }

    final resolvedExchangeId = exchangeRow['id']! as String;
    final toLotId = exchangeRow['to_lot_id'] as String?;
    if (toLotId != null) {
      final lotRows = await db.query(
        AppDatabase.cashLotsTable,
        where: 'id = ? AND is_reversed = 0',
        whereArgs: [toLotId],
        limit: 1,
      );
      if (lotRows.isNotEmpty) {
        await _linkTransactionToLot(
          db,
          transactionId: transactionId,
          lotId: toLotId,
        );
        return true;
      }
    }

    final existingExchangeLot = await db.query(
      AppDatabase.cashLotsTable,
      where:
          "source_ref_type = 'currency_exchange' AND source_ref_id = ? AND is_reversed = 0",
      whereArgs: [resolvedExchangeId],
      limit: 1,
    );
    if (existingExchangeLot.isNotEmpty) {
      await _linkTransactionToLot(
        db,
        transactionId: transactionId,
        lotId: existingExchangeLot.first['id']! as String,
      );
      return true;
    }

    final basis = await _exchangeDestinationBasis(db, resolvedExchangeId);
    if (basis == null) {
      return false;
    }

    final lot = CashLot.create(
      id: _uuid.v4(),
      tripId: tripId,
      sourceType: 'exchange_in',
      sourceRefType: 'currency_exchange',
      sourceRefId: resolvedExchangeId,
      currencyCode: currency,
      originalAmount: amount,
      remainingAmount: amount,
      homeCurrencyAmount: basis.$1,
      homeCurrencyCode: basis.$2,
      effectiveRate: basis.$3,
      createdAt: DateTime.parse(row['created_at']! as String),
      note: row['note'] as String?,
    );
    await _insertLotAndLink(db: db, transactionId: transactionId, lot: lot);
    return true;
  }

  Future<bool> _backfillCashRefund(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final transactionId = row['id']! as String;
    final tripId = row['trip_id']! as String;
    final amount = (row['amount'] as num).toDouble();
    final currency = (row['currency_code'] as String).trim().toUpperCase();
    final expenseId = row['expense_id'] as String?;

    Map<String, Object?>? refundRow;
    if (expenseId != null) {
      final rows = await db.query(
        AppDatabase.expenseRefundsTable,
        where:
            'expense_id = ? AND is_reversed = 0 AND destination = ? AND amount = ? AND currency_code = ?',
        whereArgs: [expenseId, 'cash', amount, currency],
        orderBy: 'created_at ASC',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        refundRow = rows.first;
      }
    }

    if (refundRow != null) {
      final returnedLotId = refundRow['returned_lot_id'] as String?;
      if (returnedLotId != null) {
        final lotRows = await db.query(
          AppDatabase.cashLotsTable,
          where: 'id = ? AND is_reversed = 0',
          whereArgs: [returnedLotId],
          limit: 1,
        );
        if (lotRows.isNotEmpty) {
          await _linkTransactionToLot(
            db,
            transactionId: transactionId,
            lotId: returnedLotId,
          );
          return true;
        }
      }

      final refundId = refundRow['id']! as String;
      final existingRefundLot = await db.query(
        AppDatabase.cashLotsTable,
        where:
            "source_ref_type = 'expense_refund' AND source_ref_id = ? AND is_reversed = 0",
        whereArgs: [refundId],
        limit: 1,
      );
      if (existingRefundLot.isNotEmpty) {
        await _linkTransactionToLot(
          db,
          transactionId: transactionId,
          lotId: existingRefundLot.first['id']! as String,
        );
        return true;
      }

      final refundHome = (refundRow['home_amount'] as num?)?.toDouble();
      final refundHomeCode =
          (refundRow['home_currency'] as String?)?.trim().toUpperCase();
      if (refundHome != null &&
          refundHome > 0 &&
          refundHomeCode != null &&
          refundHomeCode.isNotEmpty) {
        final lot = CashLot.create(
          id: _uuid.v4(),
          tripId: tripId,
          sourceType: 'cash_refund',
          sourceRefType: 'expense_refund',
          sourceRefId: refundId,
          currencyCode: currency,
          originalAmount: amount,
          remainingAmount: amount,
          homeCurrencyAmount: refundHome,
          homeCurrencyCode: refundHomeCode,
          effectiveRate: refundHome / amount,
          createdAt: DateTime.parse(row['created_at']! as String),
          note: row['note'] as String?,
        );
        await _insertLotAndLink(db: db, transactionId: transactionId, lot: lot);
        await db.update(
          AppDatabase.expenseRefundsTable,
          {'returned_lot_id': lot.id},
          where: 'id = ?',
          whereArgs: [refundId],
        );
        return true;
      }
    }

    return false;
  }

  Future<bool> _createLotForTransaction(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final transactionId = row['id']! as String;
    final type = row['type']! as String;
    final amount = (row['amount'] as num).toDouble();

    final sourceType = switch (type) {
      'initial_cash' => 'initial_cash',
      'manual_adjustment' => 'manual_adjustment',
      'atm_withdrawal' => 'atm_withdrawal',
      'cash_refund' => 'cash_refund',
      'currency_exchange_in' => 'exchange_in',
      _ => null,
    };
    if (sourceType == null) {
      return false;
    }

    final basis = _basisFromTransactionRow(row);
    final lot = CashLot.create(
      id: _uuid.v4(),
      tripId: row['trip_id']! as String,
      sourceType: sourceType,
      sourceRefType: 'cash_transaction',
      sourceRefId: transactionId,
      currencyCode: (row['currency_code']! as String).trim().toUpperCase(),
      originalAmount: amount,
      remainingAmount: amount,
      homeCurrencyAmount: basis.$1,
      homeCurrencyCode: basis.$2,
      effectiveRate: basis.$3,
      createdAt: DateTime.parse(row['created_at']! as String),
      note: row['note'] as String?,
    );
    await _insertLotAndLink(db: db, transactionId: transactionId, lot: lot);
    return true;
  }

  Future<(
    double homeAmount,
    String homeCode,
    double effectiveRate,
  )?> _exchangeDestinationBasis(
    DatabaseExecutor db,
    String exchangeId,
  ) async {
    final consumptionRows = await db.rawQuery(
      '''
      SELECT home_amount, home_currency_code
      FROM ${AppDatabase.cashLotConsumptionsTable}
      WHERE exchange_id = ? AND is_reversed = 0 AND home_amount IS NOT NULL
      ''',
      [exchangeId],
    );
    if (consumptionRows.isEmpty) {
      return null;
    }

    var totalHome = 0.0;
    String? homeCode;
    for (final row in consumptionRows) {
      totalHome += (row['home_amount'] as num).toDouble();
      homeCode ??= (row['home_currency_code'] as String?)?.trim().toUpperCase();
    }
    if (totalHome <= 0 || homeCode == null || homeCode.isEmpty) {
      return null;
    }

    final exchangeRows = await db.query(
      AppDatabase.currencyExchangesTable,
      columns: ['to_amount'],
      where: 'id = ?',
      whereArgs: [exchangeId],
      limit: 1,
    );
    if (exchangeRows.isEmpty) {
      return null;
    }
    final toAmount = (exchangeRows.first['to_amount'] as num).toDouble();
    if (toAmount <= 0) {
      return null;
    }

    return (totalHome, homeCode, totalHome / toAmount);
  }

  (double?, String?, double?) _basisFromTransactionRow(
    Map<String, Object?> row,
  ) {
    final amount = (row['amount'] as num).toDouble();
    final homeAmount = (row['home_currency_amount'] as num?)?.toDouble();
    final homeCode =
        (row['home_currency_code'] as String?)?.trim().toUpperCase();
    if (homeAmount != null &&
        homeAmount > 0 &&
        homeCode != null &&
        homeCode.isNotEmpty &&
        amount > 0) {
      return (homeAmount, homeCode, homeAmount / amount);
    }
    return (null, null, null);
  }

  Future<void> _insertLotAndLink({
    required DatabaseExecutor db,
    required String transactionId,
    required CashLot lot,
  }) async {
    await db.insert(
      AppDatabase.cashLotsTable,
      lot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    await _linkTransactionToLot(
      db,
      transactionId: transactionId,
      lotId: lot.id,
    );
  }

  Future<void> _linkTransactionToLot(
    DatabaseExecutor db, {
    required String transactionId,
    required String lotId,
  }) async {
    await db.update(
      AppDatabase.cashTransactionsTable,
      {'lot_id': lotId},
      where: 'id = ? AND lot_id IS NULL',
      whereArgs: [transactionId],
    );
  }
}
