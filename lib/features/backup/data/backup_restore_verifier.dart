import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../cash_wallet/domain/cash_balance_recompute.dart';
import '../../cash_wallet/domain/trip_cash_balance.dart';
import '../domain/backup_envelope.dart';

/// In-transaction checks run before a restore transaction commits.
class BackupRestoreVerifier {
  const BackupRestoreVerifier();

  /// When set in tests, runs instead of [verify] and can force rollback.
  static Future<void> Function(Transaction txn, BackupEnvelope envelope)?
      testHook;

  Future<void> verify(Transaction txn, BackupEnvelope envelope) async {
    final hook = testHook;
    if (hook != null) {
      await hook(txn, envelope);
      return;
    }

    await _verifyForeignKeys(txn);
    await _verifyCounts(txn, envelope);
    await _verifyOrphans(txn);
    await _verifyBalances(txn, envelope);
  }

  Future<void> _verifyForeignKeys(Transaction txn) async {
    final violations = await txn.rawQuery('PRAGMA foreign_key_check');
    if (violations.isNotEmpty) {
      throw StateError('foreign_key_check failed: $violations');
    }
  }

  Future<void> _verifyCounts(Transaction txn, BackupEnvelope envelope) async {
    final expected = <String, int>{
      AppDatabase.userFinancialProfileTable:
          envelope.userFinancialProfile.length,
      AppDatabase.settingsTable: envelope.settings.length,
      AppDatabase.cardsTable: envelope.cards.length,
      AppDatabase.tripsTable: envelope.trips.length,
      AppDatabase.manualExchangeRatesTable:
          envelope.manualExchangeRates.length,
      AppDatabase.expensesTable: envelope.expenses.length,
      AppDatabase.cashTransactionsTable: envelope.cashTransactions.length,
      AppDatabase.expenseRefundsTable: envelope.expenseRefunds.length,
    };

    for (final entry in expected.entries) {
      final rows = await txn.rawQuery('SELECT COUNT(*) AS c FROM ${entry.key}');
      final count = (rows.first['c'] as num).toInt();
      if (count != entry.value) {
        throw StateError(
          'count mismatch for ${entry.key}: expected ${entry.value}, got $count',
        );
      }
    }
  }

  Future<void> _verifyOrphans(Transaction txn) async {
    final orphanChecks = <String>[
      '''
      SELECT COUNT(*) AS c FROM ${AppDatabase.expensesTable} e
      LEFT JOIN ${AppDatabase.tripsTable} t ON e.trip_id = t.id
      WHERE t.id IS NULL
      ''',
      '''
      SELECT COUNT(*) AS c FROM ${AppDatabase.cashTransactionsTable} ct
      LEFT JOIN ${AppDatabase.tripsTable} t ON ct.trip_id = t.id
      WHERE t.id IS NULL
      ''',
      '''
      SELECT COUNT(*) AS c FROM ${AppDatabase.manualExchangeRatesTable} r
      WHERE r.trip_id IS NOT NULL
        AND r.trip_id NOT IN (SELECT id FROM ${AppDatabase.tripsTable})
      ''',
      '''
      SELECT COUNT(*) AS c FROM ${AppDatabase.expensesTable} e
      WHERE e.card_profile_id IS NOT NULL
        AND e.card_profile_id NOT IN (SELECT id FROM ${AppDatabase.cardsTable})
      ''',
      '''
      SELECT COUNT(*) AS c FROM ${AppDatabase.cashTransactionsTable} ct
      WHERE ct.expense_id IS NOT NULL
        AND ct.expense_id NOT IN (SELECT id FROM ${AppDatabase.expensesTable})
      ''',
      '''
      SELECT COUNT(*) AS c FROM ${AppDatabase.expenseRefundsTable} r
      LEFT JOIN ${AppDatabase.tripsTable} t ON r.trip_id = t.id
      WHERE t.id IS NULL
      ''',
      '''
      SELECT COUNT(*) AS c FROM ${AppDatabase.tripCashBalancesTable} b
      LEFT JOIN ${AppDatabase.tripsTable} t ON b.trip_id = t.id
      WHERE t.id IS NULL
      ''',
    ];

    for (final sql in orphanChecks) {
      final rows = await txn.rawQuery(sql);
      final orphans = (rows.first['c'] as num).toInt();
      if (orphans > 0) {
        throw StateError('orphan rows detected: $sql');
      }
    }
  }

  Future<void> _verifyBalances(Transaction txn, BackupEnvelope envelope) async {
    final expected = CashBalanceRecompute.recomputeTripCashBalances(
      envelope.cashTransactions,
    );
    final actualRows = await txn.query(AppDatabase.tripCashBalancesTable);
    final actual = [
      for (final row in actualRows) TripCashBalance.fromMap(row),
    ];

    if (actual.length != expected.length) {
      throw StateError(
        'balance row count mismatch: expected ${expected.length}, got ${actual.length}',
      );
    }

    final expectedByKey = {
      for (final balance in expected)
        '${balance.tripId}|${balance.currencyCode}': balance.balanceAmount,
    };
    for (final balance in actual) {
      final key = '${balance.tripId}|${balance.currencyCode}';
      final expectedAmount = expectedByKey[key];
      if (expectedAmount == null) {
        throw StateError('unexpected balance row: $key');
      }
      if ((expectedAmount - balance.balanceAmount).abs() > 0.000001) {
        throw StateError(
          'balance mismatch for $key: expected $expectedAmount, got ${balance.balanceAmount}',
        );
      }
    }
  }
}
