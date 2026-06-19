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

void main() {
  final trip = Trip.create(
    id: 'trip-cash-source-ux',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  group('Sprint Cash Source UX Cleanup', () {
    testWidgets('Add Cash sheet shows renamed labels and descriptions in English',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildCashWalletApp(trip: trip));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
      await tester.pumpAndSettle();

      expect(find.text('Cash I Brought'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
      await tester.pumpAndSettle();

      expect(find.text('Cash I Brought'), findsWidgets);
      expect(find.text('Received or Found Cash'), findsOneWidget);
      // ATM is recorded only through the dedicated ATM sheet (Sprint ATM-1A),
      // so it must not appear in the generic source selector.
      expect(find.text('ATM withdrawal'), findsNothing);
      expect(find.text('Exchange office'), findsNothing);

      expect(
        find.text('Cash you already had when the trip started.'),
        findsWidgets,
      );
      expect(
        find.text('Cash withdrawn from an ATM using a card.'),
        findsNothing,
      );
      expect(
        find.text('Cash received after exchanging another currency.'),
        findsNothing,
      );
      expect(
        find.text('Cash received from someone or found during the trip.'),
        findsWidgets,
      );
    });

    testWidgets('Add Cash sheet shows renamed labels and descriptions in Arabic',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildCashWalletApp(trip: trip, locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'إضافة كاش'));
      await tester.pumpAndSettle();

      expect(find.text('النقد الذي أحضرته معي'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
      await tester.pumpAndSettle();

      expect(find.text('النقد الذي أحضرته معي'), findsWidgets);
      expect(find.text('نقد استلمته أو وجدته'), findsOneWidget);
      expect(
        find.text('النقد الذي كان معك عند بداية الرحلة.'),
        findsWidgets,
      );
      expect(
        find.text('نقد استلمته من شخص أو وجدته أثناء الرحلة.'),
        findsWidgets,
      );
    });

    testWidgets('Add Cash flow still saves with selected source type', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = _SpyCashWalletRepository();

      await tester.pumpWidget(
        _buildCashWalletApp(trip: trip, repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Received or Found Cash').last);
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '250');

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.addCallCount, 1);
      expect(repository.lastType, CashTransactionType.manualAdjustment);
      expect(repository.lastAmount, 250);
    });
  });
}

Widget _buildCashWalletApp({
  required Trip trip,
  CashWalletRepository? repository,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      cashWalletRepositoryProvider.overrideWithValue(
        repository ?? _EmptyCashWalletRepository(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
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

class _SpyCashWalletRepository extends CashWalletRepository {
  _SpyCashWalletRepository() : super(AppDatabase());

  int addCallCount = 0;
  CashTransactionType? lastType;
  double? lastAmount;

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

  @override
  Future<void> addCashTransaction({
    required String tripId,
    required CashTransactionType type,
    required double amount,
    required String currencyCode,
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    String? note,
    DateTime? createdAt,
  }) async {
    addCallCount += 1;
    lastType = type;
    lastAmount = amount;
  }
}
