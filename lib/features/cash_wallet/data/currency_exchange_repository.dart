import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/currency_exchange.dart';

class CurrencyExchangeRepository {
  CurrencyExchangeRepository(this._appDatabase, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<CurrencyExchange> insertCurrencyExchange(
    CurrencyExchange exchange, {
    DatabaseExecutor? txn,
  }) async {
    final entity = exchange.id.isEmpty
        ? CurrencyExchange(
            id: _uuid.v4(),
            tripId: exchange.tripId,
            fromCurrencyCode: exchange.fromCurrencyCode,
            fromAmount: exchange.fromAmount,
            toCurrencyCode: exchange.toCurrencyCode,
            toAmount: exchange.toAmount,
            exchangeRate: exchange.exchangeRate,
            toLotId: exchange.toLotId,
            isReversed: exchange.isReversed,
            reversedAt: exchange.reversedAt,
            note: exchange.note,
            createdAt: exchange.createdAt,
          )
        : exchange;
    final executor = txn ?? await _appDatabase.database;
    await executor.insert(
      AppDatabase.currencyExchangesTable,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return entity;
  }

  Future<CurrencyExchange?> getExchangeById(
    String id, {
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await _appDatabase.database;
    final rows = await executor.query(
      AppDatabase.currencyExchangesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CurrencyExchange.fromMap(rows.first);
  }

  Future<List<CurrencyExchange>> getExchangesByTripId(String tripId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.currencyExchangesTable,
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'created_at DESC',
    );
    return rows.map(CurrencyExchange.fromMap).toList();
  }

  Future<void> markExchangeReversed(
    String id, {
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await _appDatabase.database;
    final now = DateTime.now().toUtc();
    await executor.update(
      AppDatabase.currencyExchangesTable,
      {
        'is_reversed': 1,
        'reversed_at': now.toIso8601String(),
      },
      where: 'id = ? AND is_reversed = 0',
      whereArgs: [id],
    );
  }
}
