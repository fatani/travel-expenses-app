import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this._appDatabase, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<Expense> createExpense(Expense expense) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();
    final entity = expense.copyWith(
      id: expense.id.isEmpty ? _uuid.v4() : expense.id,
      updatedAt: now,
    );

    await db.insert(
      AppDatabase.expensesTable,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return entity;
  }

  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.expensesTable,
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'spent_at DESC, created_at DESC',
    );

    return rows.map(Expense.fromMap).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.expensesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Expense.fromMap(rows.first);
  }

  Future<Expense> updateExpense(Expense expense) async {
    final db = await _appDatabase.database;
    final entity = expense.copyWith(updatedAt: DateTime.now().toUtc());

    await db.update(
      AppDatabase.expensesTable,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );

    return entity;
  }

  Future<void> deleteExpense(String id) async {
    final db = await _appDatabase.database;
    await db.delete(
      AppDatabase.expensesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalByTrip(String tripId) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM ${AppDatabase.expensesTable} WHERE trip_id = ?',
      [tripId],
    );

    if (result.isEmpty) {
      return 0;
    }

    return ((result.first['total'] as num?) ?? 0).toDouble();
  }
}
