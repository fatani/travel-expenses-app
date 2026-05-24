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
    id: 'trip-add-cash-validation',
    name: 'Validation Trip',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  testWidgets('rejects invalid non-empty home value without saving', (tester) async {
    final repository = _SpyCashWalletRepository();

    await tester.pumpWidget(_buildCashWalletApp(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('How much cash are you carrying?'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '100');
    await tester.enterText(fields.at(1), '.');

    await tester.tap(find.text('Add Cash').last);
    await tester.pump();

    expect(find.text('Enter a valid number.'), findsOneWidget);
    expect(repository.addCallCount, 0);
  });

  testWidgets('allows empty home value and saves null home currency amount',
      (tester) async {
    final repository = _SpyCashWalletRepository();

    await tester.pumpWidget(_buildCashWalletApp(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '100');

    await tester.tap(find.text('Add Cash').last);
    await tester.pumpAndSettle();

    expect(repository.addCallCount, 1);
    expect(repository.lastHomeCurrencyAmount, isNull);
  });
}

Widget _buildCashWalletApp({
  required Trip trip,
  required CashWalletRepository repository,
}) {
  return ProviderScope(
    overrides: [
      cashWalletRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripCashWalletScreen(trip: trip),
    ),
  );
}

class _SpyCashWalletRepository extends CashWalletRepository {
  _SpyCashWalletRepository() : super(AppDatabase());

  int addCallCount = 0;
  double? lastHomeCurrencyAmount;

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
    lastHomeCurrencyAmount = homeCurrencyAmount;
  }
}
