import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_controller.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

/// Regression for the "ATM fee invisible on Trip Details" bug.
///
/// `expenseControllerProvider` is a keep-alive family owned by Trip Details.
/// The ATM fee is persisted in its own DB transaction, but the Cash Wallet save
/// path used to refresh only cash-wallet state — so the cached (stale) expense
/// list kept showing "no expenses" until the app restarted.
///
/// This reproduces the exact provider sequence the Cash Wallet screen runs:
/// read (cache empty) → record ATM withdrawal via the real provider → and shows
/// that the list only reflects the fee once the trip expense provider is
/// invalidated (which the screen now does on save).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late ProviderContainer container;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'atm_fee_persist');
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    trip = await TripRepository(db).createTrip(
      Trip.create(
        id: 'trip-atm-persist',
        name: 'Beijing',
        destination: 'Beijing',
        baseCurrency: 'CNY',
        destinationCurrency: 'CNY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  test('ATM fee surfaces in the trip expense provider after save + refresh',
      () async {
    final card = await CardRepository(db).addCard(name: 'Visa');

    // Trip Details has already loaded and cached an empty list.
    final before = await container.read(
      expenseControllerProvider(trip.id).future,
    );
    expect(before, isEmpty);

    // Record the ATM withdrawal exactly as the Cash Wallet screen does.
    await container.read(recordAtmWithdrawalUseCaseProvider).execute(
          tripId: trip.id,
          receivedAmount: 1000,
          receivedCurrency: 'CNY',
          chargedAmount: 520,
          chargedCurrency: 'SAR',
          feeAmount: 10,
          feeCurrency: 'SAR',
          fundingCardId: card.id,
          homeCurrencyCode: 'SAR',
        );

    // Without a refresh the keep-alive provider is still the stale empty cache:
    // this is the bug the manual QA hit.
    final stale = await container.read(
      expenseControllerProvider(trip.id).future,
    );
    expect(stale, isEmpty,
        reason: 'keep-alive provider stays stale until invalidated');

    // The fix: the Cash Wallet save now reloads the trip expense view through
    // the notifier (invalidate would rebuild the controller's late-final trip
    // id and throw).
    await container.read(expenseControllerProvider(trip.id).notifier).reload();

    final after = await container.read(
      expenseControllerProvider(trip.id).future,
    );
    expect(after, hasLength(1));

    final fee = after.single;
    expect(fee.tripId, trip.id);
    expect(fee.transactionAmount, closeTo(10.0, 1e-6));
    expect(fee.transactionCurrency, 'SAR');
    expect(fee.paymentChannel, 'ATM Withdrawal Fee');
    expect(fee.cardProfileId, card.id);
    expect(fee.convertedHomeAmount, closeTo(10.0, 1e-6));
    expect(fee.homeCurrency, 'SAR');
    expect(fee.isReversed, isFalse);
  });

  test('getExpensesByTrip persists the ATM fee from the same providers',
      () async {
    final card = await CardRepository(db).addCard(name: 'Visa');

    await container.read(recordAtmWithdrawalUseCaseProvider).execute(
          tripId: trip.id,
          receivedAmount: 1000,
          receivedCurrency: 'CNY',
          chargedAmount: 520,
          chargedCurrency: 'SAR',
          feeAmount: 10,
          feeCurrency: 'SAR',
          fundingCardId: card.id,
          homeCurrencyCode: 'SAR',
        );

    final expenses =
        await container.read(expenseRepositoryProvider).getExpensesByTrip(trip.id);
    expect(expenses, hasLength(1));
    expect(expenses.single.transactionAmount, closeTo(10.0, 1e-6));
    expect(expenses.single.paymentChannel, 'ATM Withdrawal Fee');
    expect(expenses.single.isReversed, isFalse);
  });
}
