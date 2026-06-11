import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../cash_wallet/domain/cash_balance_recompute.dart';
import '../domain/backup_envelope.dart';
import '../domain/backup_restore_failure.dart';
import '../domain/backup_restore_preview.dart';
import '../domain/backup_restore_validation_issue.dart';
import '../domain/backup_restore_validator.dart';
import 'backup_file_reader.dart';
import 'backup_restore_verifier.dart';

/// Full-replace restore: parse, validate, transactional write, balance recompute.
class BackupRestoreService {
  BackupRestoreService({
    required AppDatabase appDatabase,
    BackupFileReader? fileReader,
    BackupRestoreValidator? validator,
    BackupRestoreVerifier? verifier,
  })  : _appDatabase = appDatabase,
        _fileReader = fileReader ?? const BackupFileReader(),
        _validator = validator ?? const BackupRestoreValidator(),
        _verifier = verifier ?? const BackupRestoreVerifier();

  final AppDatabase _appDatabase;
  final BackupFileReader _fileReader;
  final BackupRestoreValidator _validator;
  final BackupRestoreVerifier _verifier;

  /// Reads a `.clbackup` file, strict-parses, and runs pre-DB validation gates.
  BackupRestorePreview loadPreview({
    required String fileName,
    required String contents,
  }) {
    final json = _fileReader.readJson(fileName: fileName, contents: contents);
    return previewFromJson(json);
  }

  /// Validates already-parsed JSON (e.g. tests) without file-name checks.
  BackupRestorePreview previewFromJson(Map<String, dynamic> json) {
    final validation = _validator.validateJson(json);
    if (!validation.isValid) {
      throw _exceptionForValidation(validation.issues);
    }

    final envelope = BackupEnvelope.fromJsonStrict(json);
    return BackupRestorePreview(envelope: envelope);
  }

  /// Replaces all CalmLedger tables inside a single database transaction.
  Future<void> restore(BackupEnvelope envelope) async {
    final validation = _validator.validate(envelope);
    if (!validation.isValid) {
      throw _exceptionForValidation(validation.issues);
    }

    final db = await _appDatabase.database;
    try {
      await db.transaction((txn) async {
        await _wipeAllTables(txn);
        await _insertRestoredRows(txn, envelope);
        await _insertRecomputedBalances(txn, envelope);
        await _verifier.verify(txn, envelope);
      });
    } on BackupRestoreException {
      rethrow;
    } catch (_) {
      throw const BackupRestoreException(BackupRestoreFailureKind.restoreFailed);
    }
  }

  Future<void> _wipeAllTables(Transaction txn) async {
    const wipeOrder = [
      AppDatabase.cashTransactionsTable,
      AppDatabase.expenseRefundsTable,
      AppDatabase.tripCashBalancesTable,
      AppDatabase.expensesTable,
      AppDatabase.manualExchangeRatesTable,
      AppDatabase.tripsTable,
      AppDatabase.cardsTable,
      AppDatabase.settingsTable,
      AppDatabase.userFinancialProfileTable,
    ];

    for (final table in wipeOrder) {
      await txn.delete(table);
    }
  }

  Future<void> _insertRestoredRows(
    Transaction txn,
    BackupEnvelope envelope,
  ) async {
    await _insertRows(
      txn,
      AppDatabase.userFinancialProfileTable,
      envelope.userFinancialProfile,
    );
    await _insertRows(txn, AppDatabase.settingsTable, envelope.settings);
    await _insertRows(txn, AppDatabase.cardsTable, envelope.cards);
    await _insertRows(txn, AppDatabase.tripsTable, envelope.trips);
    await _insertRows(
      txn,
      AppDatabase.manualExchangeRatesTable,
      envelope.manualExchangeRates,
    );
    await _insertRows(txn, AppDatabase.expensesTable, envelope.expenses);
    // Backup format v1 does not include the FIFO lot ledger (cash_lots,
    // cash_lot_consumptions, currency_exchanges). Strip lot/exchange
    // references so restored rows do not violate foreign keys against
    // tables that are not part of the backup. Lot-ledger round-trip is a
    // backup-format v2 follow-up.
    await _insertRows(
      txn,
      AppDatabase.cashTransactionsTable,
      _withoutColumns(envelope.cashTransactions, const {'lot_id', 'exchange_id'}),
    );
    await _insertRows(
      txn,
      AppDatabase.expenseRefundsTable,
      _withoutColumns(envelope.expenseRefunds, const {'returned_lot_id'}),
    );
  }

  List<Map<String, dynamic>> _withoutColumns(
    List<Map<String, dynamic>> rows,
    Set<String> columns,
  ) {
    return [
      for (final row in rows)
        Map<String, dynamic>.from(row)..removeWhere((key, _) => columns.contains(key)),
    ];
  }

  Future<void> _insertRecomputedBalances(
    Transaction txn,
    BackupEnvelope envelope,
  ) async {
    final balances = CashBalanceRecompute.recomputeTripCashBalances(
      envelope.cashTransactions,
    );
    for (final balance in balances) {
      await txn.insert(
        AppDatabase.tripCashBalancesTable,
        balance.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<void> _insertRows(
    Transaction txn,
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      await txn.insert(
        table,
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  BackupRestoreException _exceptionForValidation(
    List<BackupRestoreValidationIssue> issues,
  ) {
    if (issues.any((issue) => issue.code == 'unsupported_backup_format_version')) {
      return BackupRestoreException(
        BackupRestoreFailureKind.unsupportedBackupVersion,
        issues: issues,
      );
    }
    if (issues.any((issue) => issue.code == 'unsupported_schema_version')) {
      return BackupRestoreException(
        BackupRestoreFailureKind.unsupportedSchemaVersion,
        issues: issues,
      );
    }
    if (issues.any((issue) => issue.code == 'invalid_json_shape')) {
      return const BackupRestoreException(BackupRestoreFailureKind.corruptBackup);
    }
    return BackupRestoreException(
      BackupRestoreFailureKind.corruptBackup,
      issues: issues,
    );
  }
}
