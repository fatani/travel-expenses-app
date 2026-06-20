import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

/// Pre-launch hardening: ATM withdrawal rows must not be editable or deletable
/// through the generic manual-cash path (which would orphan the ATM fee expense
/// and break the card/cash relationship). Generic cash sources stay editable.
void main() {
  final trip = Trip.create(
    id: 'trip-atm-hardening',
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
        lotId: 'lot-atm',
        createdAt: DateTime.now().toUtc(),
      );

  CashTransaction manualRow() => CashTransaction.create(
        id: 'tx-manual',
        tripId: trip.id,
        type: CashTransactionType.manualAdjustment,
        amount: 200,
        currencyCode: 'CNY',
        createdAt: DateTime.now().toUtc(),
      );

  // The Cash Wallet hero animates continuously once a balance exists, so use
  // bounded pumps instead of pumpAndSettle (which would never settle).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  late _FakeCashWalletRepository repo;

  Future<void> pump(WidgetTester tester, List<CashTransaction> rows) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    repo = _FakeCashWalletRepository(rows);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashWalletRepositoryProvider.overrideWithValue(repo),
          cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCashWalletScreen(trip: trip),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('ATM row edit shows a blocked message, not the generic sheet',
      (tester) async {
    await pump(tester, [atmRow()]);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);

    // Blocked message shown; the generic "Edit cash entry" sheet never opens.
    expect(find.textContaining("ATM withdrawals can't be edited"),
        findsOneWidget);
    expect(find.text('Edit cash entry'), findsNothing);
  });

  testWidgets('ATM row delete is blocked and never reverses the transaction',
      (tester) async {
    await pump(tester, [atmRow()]);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await settle(tester);

    expect(find.textContaining("ATM withdrawals can't be deleted"),
        findsOneWidget);
    // No generic delete confirmation, and the reversal use case is never hit —
    // so the ATM fee expense cannot be orphaned.
    expect(repo.reverseCallCount, 0);
  });

  testWidgets('generic manual cash row still opens the edit sheet',
      (tester) async {
    await pump(tester, [manualRow()]);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);

    expect(find.text('Edit cash entry'), findsOneWidget);
    expect(find.textContaining("can't be edited"), findsNothing);
  });

  testWidgets('generic manual cash row still opens the delete confirmation',
      (tester) async {
    await pump(tester, [manualRow()]);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await settle(tester);

    // Generic confirmation dialog (Cancel / Delete) is offered.
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.textContaining("can't be deleted"), findsNothing);
  });
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository(this._rows) : super(AppDatabase());

  final List<CashTransaction> _rows;
  int reverseCallCount = 0;

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
  Future<void> reverseManualCashTransaction({
    required CashTransaction transaction,
  }) async {
    reverseCallCount += 1;
  }
}

class _EmptyCardRepository extends CardRepository {
  _EmptyCardRepository() : super(AppDatabase());

  @override
  Future<List<CardProfile>> getAllCards() async => const [];
}
