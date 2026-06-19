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

void main() {
  final trip = Trip.create(
    id: 'trip-atm-1a',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  Future<void> openGenericAddCashSheet(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
    await tester.pumpAndSettle();
  }

  group('Sprint ATM-1A — ATM removed from generic Add Cash', () {
    testWidgets('1 — generic source selector does not show ATM Withdrawal',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp(trip: trip));
      await tester.pumpAndSettle();

      await openGenericAddCashSheet(tester);

      expect(find.text('ATM withdrawal'), findsNothing);
    });

    testWidgets('2-4 — generic selector keeps the three non-ATM sources',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp(trip: trip));
      await tester.pumpAndSettle();

      await openGenericAddCashSheet(tester);

      expect(find.text('Cash I Brought'), findsWidgets);
      expect(find.text('Received or Found Cash'), findsOneWidget);
      expect(find.text('Exchange office'), findsNothing);
    });

    testWidgets('5 — dedicated ATM button still opens the ATM withdrawal sheet',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp(trip: trip));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'ATM Withdrawal'));
      await tester.pumpAndSettle();

      // Fields unique to the dedicated ATM sheet confirm it opened.
      expect(find.text('Cash received'), findsOneWidget);
      expect(find.text('Amount charged to your card'), findsOneWidget);
    });
  });
}

Widget _buildApp({required Trip trip}) {
  return ProviderScope(
    overrides: [
      cashWalletRepositoryProvider.overrideWithValue(
        _EmptyCashWalletRepository(),
      ),
      cardRepositoryProvider.overrideWithValue(_FakeCardRepository(const [])),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripCashWalletScreen(trip: trip),
    ),
  );
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());

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

class _FakeCardRepository extends CardRepository {
  _FakeCardRepository(this._cards) : super(AppDatabase());

  final List<CardProfile> _cards;

  @override
  Future<List<CardProfile>> getAllCards() async => _cards;
}
