import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../cash_wallet/data/cash_wallet_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/integrity/data_integrity.dart';
import '../domain/expense.dart';
import '../domain/money_model.dart';

class CashExpenseCreateResult {
  const CashExpenseCreateResult({
    required this.expense,
    required this.deduction,
  });

  final Expense expense;
  final CashExpenseDeductionResult deduction;
}

class ExpenseRepository {
  ExpenseRepository(this._appDatabase, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  AppDatabase get appDatabase => _appDatabase;

  Future<Expense> createExpense(
    Expense expense, {
    DatabaseExecutor? txn,
  }) async {
    final now = DateTime.now().toUtc();
    final entity = expense.copyWith(
      id: expense.id.isEmpty ? _uuid.v4() : expense.id,
      updatedAt: now,
    );

    Future<void> insert(DatabaseExecutor executor) async {
      await _assertTripExists(executor, entity.tripId);
      DataIntegrity.requireExpense(entity);
      await executor.insert(
        AppDatabase.expensesTable,
        entity.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }

    if (txn != null) {
      await insert(txn);
    } else {
      final db = await _appDatabase.database;
      await db.transaction(insert);
    }

    return entity;
  }

  Future<CashExpenseCreateResult> createCashExpenseWithWalletDeduction({
    required Expense expense,
    required CashWalletRepository cashWallet,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final created = await createExpense(expense, txn: txn);
      final deduction = await cashWallet.recordCashExpenseDeduction(
        tripId: created.tripId,
        expenseId: created.id,
        amount: created.transactionAmount,
        currencyCode: created.transactionCurrency,
        note: created.note,
        txn: txn,
      );

      return CashExpenseCreateResult(expense: created, deduction: deduction);
    });
  }

  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    DataIntegrity.requireNonEmptyTripId(tripId);
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.expensesTable,
      where: 'trip_id = ? AND is_reversed = 0',
      whereArgs: [tripId],
      orderBy: 'spent_at DESC, created_at DESC',
    );

    return _parseExpenseRows(rows);
  }

  Future<List<MoneyModel>> getMoneyModelsByTrip(String tripId) async {
    final expenses = await getExpensesByTrip(tripId);
    return expenses.map((expense) => expense.moneyModel).toList();
  }

  Future<List<MoneyModel>> getInternationalMoneyModelsByTrip(String tripId) async {
    final moneyModels = await getMoneyModelsByTrip(tripId);
    return moneyModels.where((money) => money.isInternational).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    if (id.trim().isEmpty) {
      return null;
    }

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

    return Expense.tryFromMap(rows.first);
  }

  /// Returns active (non-reversed) expenses linked to a financial event via the
  /// generic source reference — e.g. the ATM fee for an ATM cash transaction
  /// (`sourceRefType = 'atm_withdrawal'`, `sourceRefId = atmCashTransactionId`).
  ///
  /// Returns empty for unlinked/legacy rows (null source ref). This is the
  /// reliable lookup the future ATM Safe Undo/Correct flow will use; it never
  /// falls back to timestamp/amount matching.
  Future<List<Expense>> getActiveExpensesBySourceRef(
    String sourceRefType,
    String sourceRefId, {
    DatabaseExecutor? txn,
  }) async {
    if (sourceRefType.trim().isEmpty || sourceRefId.trim().isEmpty) {
      return const [];
    }
    final executor = txn ?? await _appDatabase.database;
    final rows = await executor.query(
      AppDatabase.expensesTable,
      where: 'source_ref_type = ? AND source_ref_id = ? AND is_reversed = 0',
      whereArgs: [sourceRefType, sourceRefId],
      orderBy: 'spent_at DESC, created_at DESC',
    );

    return _parseExpenseRows(rows);
  }

  Future<Expense> updateExpense(Expense expense, {DatabaseExecutor? txn}) async {
    final entity = expense.copyWith(updatedAt: DateTime.now().toUtc());

    Future<void> doUpdate(DatabaseExecutor executor) async {
      await _assertTripExists(executor, entity.tripId);
      DataIntegrity.requireExpense(entity);
      final updated = await executor.update(
        AppDatabase.expensesTable,
        entity.toMap(),
        where: 'id = ?',
        whereArgs: [entity.id],
      );
      if (updated == 0) {
        throw const DataIntegrityException('expenseNotFound');
      }
    }

    if (txn != null) {
      await doUpdate(txn);
    } else {
      final db = await _appDatabase.database;
      await db.transaction(doUpdate);
    }

    return entity;
  }

  Future<void> deleteExpense(String id, {DatabaseExecutor? txn}) async {
    DataIntegrity.requireNonEmptyId(id, field: 'expenseId');
    if (txn != null) {
      await txn.delete(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      final db = await _appDatabase.database;
      await db.delete(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  @Deprecated(
    'Unsafe across mixed currencies: this raw SUM(amount) can be mathematically misleading. '
    'Use currency-grouped totals from report calculators instead.',
  )
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

  /// Returns the card_profile_id of the most recent card expense for the given
  /// trip, or null if no card expense exists. Only considers expenses whose
  /// payment_channel is a card channel (POS Purchase / Online Purchase).
  Future<int?> getLastCardExpenseCardId(String tripId) async {
    DataIntegrity.requireNonEmptyTripId(tripId);
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.expensesTable,
      columns: ['card_profile_id'],
      where:
          'trip_id = ? AND card_profile_id IS NOT NULL'
          ' AND payment_channel IN (?, ?)',
      whereArgs: [tripId, 'POS Purchase', 'Online Purchase'],
      orderBy: 'spent_at DESC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['card_profile_id'] as int?;
  }

  Future<void> _assertTripExists(DatabaseExecutor db, String tripId) async {
    DataIntegrity.requireNonEmptyTripId(tripId);
    final rows = await db.query(
      AppDatabase.tripsTable,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const DataIntegrityException('tripNotFound');
    }
  }

  List<Expense> _parseExpenseRows(List<Map<String, Object?>> rows) {
    final expenses = <Expense>[];
    for (final row in rows) {
      final expense = Expense.tryFromMap(row);
      if (expense != null) {
        expenses.add(expense);
      }
    }
    return expenses;
  }
}
