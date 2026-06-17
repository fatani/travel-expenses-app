import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_withdrawal_result.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-atm-1',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  CardProfile buildCard(int id, String name) {
    final now = DateTime.utc(2026, 1, 1);
    return CardProfile(
      id: id,
      name: name,
      displayName: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> openAtmSheet(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'ATM Withdrawal'));
    await tester.pumpAndSettle();
  }

  group('Sprint ATM-1 — Dedicated ATM withdrawal', () {
    testWidgets('1 — ATM action visible when wallet has no cash',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp(trip: trip));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'ATM Withdrawal'),
        findsOneWidget,
      );
    });

    testWidgets('2 — ATM tap opens a dedicated ATM sheet with ATM title/fields',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp(trip: trip, cards: [buildCard(1, 'Visa')]));
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      expect(find.text('Cash received'), findsOneWidget);
      expect(find.text('Amount charged to your card'), findsOneWidget);
      expect(find.text('ATM fee'), findsOneWidget);
    });

    testWidgets('3 — ATM sheet does not show the cash source dropdown',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp(trip: trip, cards: [buildCard(1, 'Visa')]));
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      expect(
        find.byType(DropdownButtonFormField<CashTransactionType>),
        findsNothing,
      );
    });

    testWidgets('4 — ATM defaults currency to trip destination currency',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp(trip: trip, cards: [buildCard(1, 'Visa')]));
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      // THB is the destination currency; it must appear in the currency field.
      expect(find.textContaining('THB'), findsWidgets);
    });

    testWidgets('5 + 8 — auto-selects first card and passes its id on save',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final spy = _SpyAtmUseCase();
      await tester.pumpWidget(
        _buildApp(
          trip: trip,
          cards: [buildCard(7, 'First Card'), buildCard(9, 'Second Card')],
          atmUseCase: spy,
        ),
      );
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      // First card is shown selected.
      expect(find.text('First Card'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '10000');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(spy.callCount, 1);
      expect(spy.lastFundingCardId, 7);
      expect(spy.lastReceivedAmount, 10000);
      expect(spy.lastReceivedCurrency, 'THB');
    });

    testWidgets('6 — ATM card selector does not show a "No card" option',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp(trip: trip, cards: [buildCard(1, 'Visa')]));
      await tester.pumpAndSettle();

      await openAtmSheet(tester);
      await tester.tap(find.byKey(const Key('atm_card_selector')));
      await tester.pumpAndSettle();

      expect(find.text('No card'), findsNothing);
    });

    testWidgets('7 — save without a card is blocked when no cards exist',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final spy = _SpyAtmUseCase();
      await tester.pumpWidget(
        _buildApp(trip: trip, cards: const [], atmUseCase: spy),
      );
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      expect(find.text('Add a card to record this ATM withdrawal.'),
          findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '5000');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(spy.callCount, 0);
      expect(find.text('Please select the card used.'), findsOneWidget);
    });

    testWidgets('9 — save with charged amount passes it to the use case',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final spy = _SpyAtmUseCase();
      await tester.pumpWidget(
        _buildApp(trip: trip, cards: [buildCard(1, 'Visa')], atmUseCase: spy),
      );
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), '10000'); // received
      await tester.enterText(find.byType(TextField).at(1), '275'); // charged
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(spy.callCount, 1);
      expect(spy.lastChargedAmount, 275);
      expect(spy.lastChargedCurrency, 'SAR');
    });

    testWidgets('10 — save without charged amount still records the withdrawal',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final spy = _SpyAtmUseCase();
      await tester.pumpWidget(
        _buildApp(trip: trip, cards: [buildCard(1, 'Visa')], atmUseCase: spy),
      );
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), '8000');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(spy.callCount, 1);
      expect(spy.lastChargedAmount, isNull);
      expect(spy.lastReceivedAmount, 8000);
    });

    testWidgets('11 — ATM fee field is optional', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final spy = _SpyAtmUseCase();
      await tester.pumpWidget(
        _buildApp(trip: trip, cards: [buildCard(1, 'Visa')], atmUseCase: spy),
      );
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), '8000');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(spy.callCount, 1);
      expect(spy.lastFeeAmount, isNull);
    });

    testWidgets('12 + 13 — positive fee is forwarded separately from charge',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final spy = _SpyAtmUseCase();
      await tester.pumpWidget(
        _buildApp(trip: trip, cards: [buildCard(1, 'Visa')], atmUseCase: spy),
      );
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), '10000'); // received
      await tester.enterText(find.byType(TextField).at(1), '275'); // charged
      await tester.enterText(find.byType(TextField).at(2), '5'); // fee
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(spy.callCount, 1);
      expect(spy.lastFeeAmount, 5);
      expect(spy.lastFeeCurrency, 'SAR');
      // Fee is passed as a distinct value, not folded into the charged amount.
      expect(spy.lastChargedAmount, 275);
    });

    testWidgets('14 — fee >= charged amount blocks save', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final spy = _SpyAtmUseCase();
      await tester.pumpWidget(
        _buildApp(trip: trip, cards: [buildCard(1, 'Visa')], atmUseCase: spy),
      );
      await tester.pumpAndSettle();

      await openAtmSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), '10000'); // received
      await tester.enterText(find.byType(TextField).at(1), '10'); // charged
      await tester.enterText(find.byType(TextField).at(2), '10'); // fee == charged
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(spy.callCount, 0);
      expect(
        find.text(
            'The ATM fee must be less than the amount charged to your card.'),
        findsOneWidget,
      );
    });
  });
}

Widget _buildApp({
  required Trip trip,
  List<CardProfile> cards = const [],
  RecordAtmWithdrawalUseCase? atmUseCase,
}) {
  return ProviderScope(
    overrides: [
      cashWalletRepositoryProvider.overrideWithValue(
        _EmptyCashWalletRepository(),
      ),
      cardRepositoryProvider.overrideWithValue(_FakeCardRepository(cards)),
      if (atmUseCase != null)
        recordAtmWithdrawalUseCaseProvider.overrideWithValue(atmUseCase),
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

class _SpyAtmUseCase extends RecordAtmWithdrawalUseCase {
  _SpyAtmUseCase()
      : super(
          appDatabase: AppDatabase(),
          cashWalletRepository: CashWalletRepository(AppDatabase()),
          lotRepository: CashLotRepository(AppDatabase()),
          expenseRepository: ExpenseRepository(AppDatabase()),
        );

  int callCount = 0;
  double? lastReceivedAmount;
  String? lastReceivedCurrency;
  double? lastChargedAmount;
  String? lastChargedCurrency;
  double? lastFeeAmount;
  String? lastFeeCurrency;
  int? lastFundingCardId;

  @override
  Future<AtmWithdrawalResult> execute({
    required String tripId,
    required double receivedAmount,
    required String receivedCurrency,
    double? chargedAmount,
    String? chargedCurrency,
    double? feeAmount,
    String? feeCurrency,
    String? feeNote,
    int? fundingCardId,
    String? note,
    DateTime? createdAt,
  }) async {
    callCount += 1;
    lastReceivedAmount = receivedAmount;
    lastReceivedCurrency = receivedCurrency;
    lastChargedAmount = chargedAmount;
    lastChargedCurrency = chargedCurrency;
    lastFeeAmount = feeAmount;
    lastFeeCurrency = feeCurrency;
    lastFundingCardId = fundingCardId;

    return AtmWithdrawalResult(
      cashLot: CashLot.create(
        id: 'lot-spy',
        tripId: tripId,
        sourceType: 'atm_withdrawal',
        sourceRefType: 'cash_transaction',
        sourceRefId: 'tx-spy',
        currencyCode: receivedCurrency,
        originalAmount: receivedAmount,
        homeCurrencyAmount: chargedAmount,
        homeCurrencyCode: chargedCurrency,
      ),
      cashTransaction: CashTransaction.create(
        id: 'tx-spy',
        tripId: tripId,
        type: CashTransactionType.atmWithdrawal,
        amount: receivedAmount,
        currencyCode: receivedCurrency,
        lotId: 'lot-spy',
      ),
    );
  }
}
