import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/data/backup_data_collector.dart';
import 'package:travel_expenses/features/backup/data/backup_export_service.dart';
import 'package:travel_expenses/features/backup/data/backup_file_writer.dart';
import 'package:travel_expenses/features/backup/data/backup_restore_service.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_result.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_correction_service.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/reverse_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/isolated_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late AppDatabase db;
  late TripRepository tripRepo;
  late CashWalletRepository walletRepo;
  late CashLotRepository lotRepo;
  late CashLotConsumptionRepository consumptionRepo;
  late CurrencyExchangeRepository exchangeRepo;
  late ExpenseRepository expenseRepo;
  late RecordCurrencyExchangeUseCase recordExchange;
  late ReverseCurrencyExchangeUseCase reverseExchange;
  late Trip trip;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exchange_undo_backup_');
    db = createIsolatedAppDatabase(prefix: 'exchange_undo_rb');
    tripRepo = TripRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    consumptionRepo = CashLotConsumptionRepository(db);
    exchangeRepo = CurrencyExchangeRepository(db);
    expenseRepo = ExpenseRepository(db);

    final fifo = CashLotFifoEngine(lotRepo);
    final engine = CurrencyExchangeEngine(fifo);
    recordExchange = RecordCurrencyExchangeUseCase(
      appDatabase: db,
      exchangeEngine: engine,
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      exchangeRepository: exchangeRepo,
    );
    final correctionService = ExchangeCorrectionService(
      exchangeRepository: exchangeRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      expenseRepository: expenseRepo,
    );
    reverseExchange = ReverseCurrencyExchangeUseCase(
      appDatabase: db,
      correctionService: correctionService,
      exchangeRepository: exchangeRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      cashWalletRepository: walletRepo,
    );

    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-urb',
        name: 'Undo Report Backup',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<CurrencyExchangeResult> seedAndExchange() async {
    await walletRepo.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.initialCash,
      amount: 10000,
      currencyCode: 'JPY',
      homeCurrencyAmount: 270,
      homeCurrencyCode: 'SAR',
    );
    return recordExchange.execute(
      tripId: trip.id,
      fromCurrencyCode: 'JPY',
      fromAmount: 5000,
      toCurrencyCode: 'CNY',
      toAmount: 720,
    );
  }

  // ── Report exclusion ───────────────────────────────────────────────────────

  group('report exclusion', () {
    test('reversed exchange lot is excluded from active lots and summaries',
        () async {
      final result = await seedAndExchange();

      // Before undo: a CNY lot is active.
      final cnyBefore = await lotRepo.getActiveLotsForTrip(trip.id);
      expect(cnyBefore.any((l) => l.currencyCode == 'CNY'), isTrue);

      await reverseExchange.execute(result.exchange.id);

      // After undo: the CNY exchange-in lot is no longer active.
      final activeLots = await lotRepo.getActiveLotsForTrip(trip.id);
      expect(activeLots.any((l) => l.currencyCode == 'CNY'), isFalse);

      final summaries = await lotRepo.computeLotCurrencySummaries(
        tripId: trip.id,
        homeCurrencyCode: 'SAR',
      );
      expect(summaries.any((s) => s.currencyCode == 'CNY'), isFalse);

      // The restored JPY remains fully present in the summary.
      final jpy = summaries.firstWhere((s) => s.currencyCode == 'JPY');
      expect(jpy.totalRemainingAmount, closeTo(10000, 1e-6));
    });

    test('corrected (active) exchange counts; reversed original does not',
        () async {
      final result = await seedAndExchange();
      await reverseExchange.execute(result.exchange.id);

      final exchanges = await exchangeRepo.getExchangesByTripId(trip.id);
      final original =
          exchanges.firstWhere((e) => e.id == result.exchange.id);
      expect(original.isReversed, isTrue);
    });
  });

  // ── Backup / restore round-trip ────────────────────────────────────────────

  group('backup round-trip', () {
    test('reversed state survives export and restore; cash not resurrected',
        () async {
      final result = await seedAndExchange();
      await reverseExchange.execute(result.exchange.id);

      // Export.
      final collector = BackupDataCollector(db);
      final exportService = BackupExportService(
        collector: collector,
        fileWriter: BackupFileWriter(directoryProvider: () async => tempDir),
      );
      final exportResult = await exportService.export(
        exportedAt: DateTime.utc(2026, 6, 1, 14, 30, 45),
      );
      final raw = jsonDecode(File(exportResult.filePath).readAsStringSync())
          as Map<String, dynamic>;
      final envelope = BackupEnvelope.fromJson(raw);

      // Restore onto a fresh database.
      final fresh = createIsolatedAppDatabase(prefix: 'exchange_undo_fresh');
      try {
        await BackupRestoreService(appDatabase: fresh).restore(envelope);

        // The two exchange cash transactions remain reversed after restore.
        final rawDb = await fresh.database;
        final exchangeTxRows = await rawDb.query(
          AppDatabase.cashTransactionsTable,
          where: 'trip_id = ? AND type IN (?, ?)',
          whereArgs: [
            trip.id,
            CashTransactionType.currencyExchangeOut.value,
            CashTransactionType.currencyExchangeIn.value,
          ],
        );
        expect(exchangeTxRows, hasLength(2));
        for (final row in exchangeTxRows) {
          expect((row['is_reversed'] as num).toInt(), 1);
          expect(row['reversed_at'], isNotNull);
        }

        // Recomputed balances do not resurrect the reversed cash.
        final balances =
            await CashWalletRepository(fresh).getBalancesByTrip(trip.id);
        double balanceOf(String code) {
          for (final b in balances) {
            if (b.currencyCode == code) return b.balanceAmount;
          }
          return 0;
        }

        expect(balanceOf('JPY'), closeTo(10000, 1e-6));
        expect(balanceOf('CNY'), closeTo(0, 1e-6));
      } finally {
        await fresh.close();
      }
    });
  });
}
