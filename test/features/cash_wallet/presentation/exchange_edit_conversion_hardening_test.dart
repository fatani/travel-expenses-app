import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

/// Exchange Edit Conversion Hardening — UI level.
///
/// Editing a manual cash transaction must not offer "Exchange office" as a
/// source (converting a manual row into an exchange would bypass the engine),
/// while ordinary manual source types remain available and editable.
void main() {
  final trip = Trip.create(
    id: 'trip-exchange-edit-conversion',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
  );

  final manualRow = CashTransaction.create(
    id: 'adj1',
    tripId: trip.id,
    type: CashTransactionType.manualAdjustment,
    amount: 300,
    currencyCode: 'CNY',
    createdAt: DateTime.now().toUtc(),
  );

  Widget buildApp(CashWalletRepository repo) => ProviderScope(
        overrides: [cashWalletRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCashWalletScreen(trip: trip),
        ),
      );

  void sizeLarge(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> openEditDropdown(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
    await tester.pumpAndSettle();
  }

  // ── Test 1 — edit mode does not offer Exchange office ──────────────────────
  testWidgets('editing a manual row does not offer Exchange office',
      (tester) async {
    sizeLarge(tester);
    await tester.pumpWidget(buildApp(_StubCashWalletRepository([manualRow])));
    await tester.pumpAndSettle();

    await openEditDropdown(tester);

    expect(find.text('Exchange office'), findsNothing);
    // Ordinary manual sources remain.
    expect(find.text('Received or Found Cash'), findsWidgets);
    expect(find.text('Cash I Brought'), findsWidgets);
  });

  // ── Test 4 — other manual source types still work in edit mode ─────────────
  testWidgets('editing a manual row to another manual type still saves',
      (tester) async {
    sizeLarge(tester);
    final repo = _StubCashWalletRepository([manualRow]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await openEditDropdown(tester);
    await tester.tap(find.text('Cash I Brought').last); // initialCash
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repo.updateCallCount, 1);
    expect(repo.lastNextType, CashTransactionType.initialCash);
  });
}

class _StubCashWalletRepository extends CashWalletRepository {
  _StubCashWalletRepository(this.transactions) : super(AppDatabase());

  final List<CashTransaction> transactions;
  int updateCallCount = 0;
  CashTransactionType? lastNextType;

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async =>
      const [];

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async =>
      transactions;

  @override
  Future<void> updateManualCashTransaction({
    required CashTransaction existingTransaction,
    required CashTransactionType nextType,
    required double nextAmount,
    required String nextCurrencyCode,
    double? nextHomeCurrencyAmount,
    String? nextHomeCurrencyCode,
    String? nextNote,
    DateTime? nextCreatedAt,
  }) async {
    updateCallCount += 1;
    lastNextType = nextType;
  }
}
