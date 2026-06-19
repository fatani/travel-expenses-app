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

/// Exchange Office is no longer reachable from generic Add Cash — the orphan
/// inflow path is removed at the UI level because the source option was deleted.
void main() {
  final trip = Trip.create(
    id: 'trip-exchange-orphan-block',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  testWidgets('generic Add Cash no longer offers Exchange office',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final walletRepo = _SpyCashWalletRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashWalletRepositoryProvider.overrideWithValue(walletRepo),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCashWalletScreen(trip: trip),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
    await tester.pumpAndSettle();

    expect(find.text('Exchange office'), findsNothing);
    expect(find.text('Cash I Brought'), findsWidgets);
    expect(find.text('Received or Found Cash'), findsOneWidget);
  });
}

class _SpyCashWalletRepository extends CashWalletRepository {
  _SpyCashWalletRepository() : super(AppDatabase());

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async =>
      const [];

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async =>
      const [];
}
