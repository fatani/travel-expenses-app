import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_correction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_correction_service.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/reverse_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_correction.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

/// ATM Safe Undo / Correct v1 — UI wiring on the Cash Wallet screen.
///
/// Uses in-memory fakes (a fake AtmCorrectionService returns the chosen status)
/// so the row actions are exercised deterministically without real DB I/O.
void main() {
  final trip = Trip.create(
    id: 'trip-atm-ui',
    name: 'Beijing',
    destination: 'Beijing',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
  );

  CashTransaction atmRow() => CashTransaction.create(
        id: 'tx-atm',
        tripId: trip.id,
        type: CashTransactionType.atmWithdrawal,
        amount: 1000,
        currencyCode: 'CNY',
        homeCurrencyAmount: 510,
        homeCurrencyCode: 'SAR',
        lotId: 'lot-atm',
        createdAt: DateTime.now().toUtc(),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  late _SpyReverseUseCase reverseSpy;

  Future<void> pump(
    WidgetTester tester, {
    required AtmCorrectionStatus status,
    Locale? locale,
  }) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    reverseSpy = _SpyReverseUseCase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashWalletRepositoryProvider
              .overrideWithValue(_FakeCashWalletRepository([atmRow()])),
          cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
          atmCorrectionServiceProvider
              .overrideWithValue(_FakeAtmCorrectionService(status)),
          reverseAtmWithdrawalUseCaseProvider.overrideWithValue(reverseSpy),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCashWalletScreen(trip: trip),
        ),
      ),
    );
    await settle(tester);
  }

  AtmCorrectionStatus correctable() => const AtmCorrectionStatus.correctable(
        cashTransactionId: 'tx-atm',
        lotId: 'lot-atm',
      );

  AtmCorrectionStatus usedCash() => AtmCorrectionStatus.blocked(
        cashTransactionId: 'tx-atm',
        reasonCode: AtmCorrectionReason.cashUsed,
        lotId: 'lot-atm',
        affectedTransactions: [
          AffectedCashUse(
            type: AffectedCashUseType.cashExpense,
            amount: 300,
            currencyCode: 'CNY',
            date: DateTime.utc(2026, 6, 1),
          ),
        ],
      );

  AtmCorrectionStatus unavailable() => const AtmCorrectionStatus.blocked(
        cashTransactionId: 'tx-atm',
        reasonCode: AtmCorrectionReason.legacyUnlinked,
        lotId: 'lot-atm',
      );

  testWidgets('unused ATM row shows Correct/Undo, no generic Edit/Delete',
      (tester) async {
    await pump(tester, status: correctable());

    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('Undo shows confirmation with distinct actions then reverses',
      (tester) async {
    await pump(tester, status: correctable());

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Undo ATM withdrawal?'), findsOneWidget);
    // Distinct cancel/confirm labels — no two identical buttons.
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Undo withdrawal'), findsOneWidget);

    await tester.tap(find.text('Undo withdrawal'));
    await settle(tester);

    expect(reverseSpy.executedIds, ['tx-atm']);
  });

  testWidgets('Undo confirmation Cancel dismisses without reversing',
      (tester) async {
    await pump(tester, status: correctable());

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Undo ATM withdrawal?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Undo ATM withdrawal?'), findsNothing);
    expect(reverseSpy.executedIds, isEmpty);
  });

  testWidgets('Arabic Undo dialog has distinct labels (not two إلغاء)',
      (tester) async {
    await pump(tester, status: correctable(), locale: const Locale('ar'));

    await tester.tap(find.text('إلغاء')); // the row "Undo" action
    await settle(tester);

    expect(find.text('إلغاء سحب الصراف؟'), findsOneWidget);
    // Cancel = تراجع, destructive confirm = إلغاء السحب — no bare "إلغاء" button.
    expect(find.text('تراجع'), findsOneWidget);
    expect(find.text('إلغاء السحب'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'إلغاء'), findsNothing);

    await tester.tap(find.text('إلغاء السحب'));
    await settle(tester);
    expect(reverseSpy.executedIds, ['tx-atm']);
  });

  testWidgets('Correct opens the dedicated ATM correction sheet',
      (tester) async {
    await pump(tester, status: correctable());

    await tester.tap(find.text('Correct'));
    await settle(tester);

    expect(find.text('Correct ATM withdrawal'), findsOneWidget);
    expect(find.text('Save correction'), findsOneWidget);
    expect(find.text('Edit cash entry'), findsNothing);
  });

  testWidgets('used ATM shows View affected transactions, not Correct/Undo',
      (tester) async {
    await pump(tester, status: usedCash());

    expect(find.text('View affected transactions'), findsOneWidget);
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('legacy/unlinked ATM shows Correction unavailable',
      (tester) async {
    await pump(tester, status: unavailable());

    expect(find.text('Correction unavailable'), findsOneWidget);
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository(this._rows) : super(AppDatabase());

  final List<CashTransaction> _rows;

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async =>
      const [];

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async =>
      _rows;

  @override
  Future<CashTransaction?> getCashTransactionById(
    String id, {
    DatabaseExecutor? txn,
  }) async {
    for (final t in _rows) {
      if (t.id == id) return t;
    }
    return null;
  }
}

class _EmptyCardRepository extends CardRepository {
  _EmptyCardRepository() : super(AppDatabase());

  @override
  Future<List<CardProfile>> getAllCards() async => const [];
}

class _FakeAtmCorrectionService extends AtmCorrectionService {
  _FakeAtmCorrectionService(this._status)
      : super(
          cashWalletRepository: _FakeCashWalletRepository(const []),
          lotRepository: CashLotRepository(AppDatabase()),
          consumptionRepository: CashLotConsumptionRepository(AppDatabase()),
          expenseRepository: ExpenseRepository(AppDatabase()),
        );

  final AtmCorrectionStatus _status;

  @override
  Future<AtmCorrectionStatus> getStatus(
    String atmCashTransactionId, {
    DatabaseExecutor? txn,
  }) async =>
      _status;
}

class _SpyReverseUseCase extends ReverseAtmWithdrawalUseCase {
  _SpyReverseUseCase()
      : super(
          appDatabase: AppDatabase(),
          correctionService: _FakeAtmCorrectionService(
            const AtmCorrectionStatus.correctable(
              cashTransactionId: 'tx-atm',
              lotId: 'lot-atm',
            ),
          ),
          cashWalletRepository: _FakeCashWalletRepository(const []),
          expenseRepository: ExpenseRepository(AppDatabase()),
        );

  final List<String> executedIds = [];

  @override
  Future<CashTransaction> execute(String atmCashTransactionId) async {
    executedIds.add(atmCashTransactionId);
    return CashTransaction.create(
      id: atmCashTransactionId,
      tripId: 'trip-atm-ui',
      type: CashTransactionType.atmWithdrawal,
      amount: 1000,
      currencyCode: 'CNY',
    );
  }
}
