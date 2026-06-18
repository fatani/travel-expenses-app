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

/// Exchange Edit/Delete Hardening — UI affordance level.
///
/// Exchange rows must expose no edit/delete controls (they are one half of a
/// two-sided exchange owned by the engine), while ordinary manual rows keep
/// their edit/delete affordances.
void main() {
  final trip = Trip.create(
    id: 'trip-exchange-edit-delete',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
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

  CashTransaction row(CashTransactionType type, String id) =>
      CashTransaction.create(
        id: id,
        tripId: trip.id,
        type: type,
        amount: 2000,
        currencyCode: 'CNY',
        createdAt: DateTime.now().toUtc(),
      );

  // ── Test 1 & 2 — exchange row exposes neither edit nor delete ──────────────
  testWidgets('exchange transaction has no edit or delete controls',
      (tester) async {
    sizeLarge(tester);

    await tester.pumpWidget(buildApp(
      _StubCashWalletRepository(
        transactions: [row(CashTransactionType.currencyExchangeIn, 'ex1')],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  // ── Test 5 & 6 (UI) — ordinary manual row keeps edit + delete ──────────────
  testWidgets('manual adjustment keeps edit and delete controls',
      (tester) async {
    sizeLarge(tester);

    await tester.pumpWidget(buildApp(
      _StubCashWalletRepository(
        transactions: [row(CashTransactionType.manualAdjustment, 'adj1')],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });
}

class _StubCashWalletRepository extends CashWalletRepository {
  _StubCashWalletRepository({required this.transactions})
      : super(AppDatabase());

  final List<CashTransaction> transactions;

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
}
