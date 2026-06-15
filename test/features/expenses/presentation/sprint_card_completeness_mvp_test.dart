import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_currency_summary.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/card_expense_completeness.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/reports/presentation/trip_reports_screen.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/settings/presentation/cards_provider.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/no_fifo_update_cash_expense_use_case.dart';
import '../../../support/test_expense_repository.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-card-complete',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
  );

  final visaCard = CardProfile(
    id: 1,
    name: 'Visa',
    cardNetwork: 'Visa',
    last4: '4242',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final pendingCardExpense = Expense.create(
    id: 'pending-card',
    tripId: trip.id,
    title: 'Hotel',
    amount: 500,
    currencyCode: 'CNY',
    transactionAmount: 500,
    transactionCurrency: 'CNY',
    spentAt: DateTime(2026, 6, 1),
    paymentMethod: 'Credit Card',
    paymentNetwork: 'Visa',
    paymentChannel: 'POS Purchase',
    cardProfileId: 1,
    category: 'Accommodation',
  );

  final completedCardExpense = Expense.create(
    id: 'completed-card',
    tripId: trip.id,
    title: 'Dinner',
    amount: 200,
    currencyCode: 'CNY',
    transactionAmount: 200,
    transactionCurrency: 'CNY',
    convertedHomeAmount: 104,
    homeCurrency: 'SAR',
    spentAt: DateTime(2026, 6, 2),
    paymentMethod: 'Credit Card',
    paymentNetwork: 'Visa',
    paymentChannel: 'POS Purchase',
    cardProfileId: 1,
    category: 'Food',
    totalChargedAmount: 104,
    totalChargedCurrency: 'SAR',
  );

  final cashExpense = Expense.create(
    id: 'cash-expense',
    tripId: trip.id,
    title: 'Snack',
    amount: 20,
    currencyCode: 'CNY',
    transactionAmount: 20,
    transactionCurrency: 'CNY',
    spentAt: DateTime(2026, 6, 3),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
  );

  final sameCurrencyCardExpense = Expense.create(
    id: 'same-currency-card',
    tripId: trip.id,
    title: 'Local card',
    amount: 75,
    currencyCode: 'SAR',
    transactionAmount: 75,
    transactionCurrency: 'SAR',
    spentAt: DateTime(2026, 6, 4),
    paymentMethod: 'Credit Card',
    paymentNetwork: 'Visa',
    paymentChannel: 'POS Purchase',
    cardProfileId: 1,
    category: 'Shopping',
  );

  group('card expense completeness helper', () {
    test('pending cross-currency card without charged amount is pending', () {
      expect(
        isPendingCardExpense(
          expense: pendingCardExpense,
          tripHomeCurrency: trip.homeCurrencySnapshot,
        ),
        isTrue,
      );
    });

    test('completed card with charged amount is not pending', () {
      expect(
        isPendingCardExpense(
          expense: completedCardExpense,
          tripHomeCurrency: trip.homeCurrencySnapshot,
        ),
        isFalse,
      );
    });

    test('cash expense is not pending', () {
      expect(
        isPendingCardExpense(
          expense: cashExpense,
          tripHomeCurrency: trip.homeCurrencySnapshot,
        ),
        isFalse,
      );
    });

    test('same-currency card expense is not pending', () {
      expect(
        isPendingCardExpense(
          expense: sameCurrencyCardExpense,
          tripHomeCurrency: trip.homeCurrencySnapshot,
        ),
        isFalse,
      );
    });

    test('pending count matches expected expenses', () {
      const calculator = TripReportCalculator();
      final summary = calculator.calculate(
        tripId: trip.id,
        tripName: trip.name,
        tripHomeCurrency: trip.homeCurrencySnapshot,
        expenses: [
          pendingCardExpense,
          completedCardExpense,
          cashExpense,
          sameCurrencyCardExpense,
        ],
      );

      expect(summary.pendingCardExpenseCount, 1);
    });
  });

  group('trip details expense card placeholder', () {
    Future<void> pumpTripDetails(
      WidgetTester tester,
      List<Expense> expenses,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(
              _FakeExpenseRepository(expenses),
            ),
            cashWalletRepositoryProvider.overrideWithValue(
              _FakeCashWalletRepository(),
            ),
            updateCashExpenseUseCaseProvider.overrideWith(
              (ref) => NoFifoUpdateCashExpenseUseCase(
                expenseRepository: ref.watch(expenseRepositoryProvider),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailsScreen(trip: trip),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pending card expense shows placeholder label', (tester) async {
      await pumpTripDetails(tester, [pendingCardExpense]);

      expect(find.text('Awaiting charged amount'), findsOneWidget);
    });

    testWidgets('completed card expense hides placeholder', (tester) async {
      await pumpTripDetails(tester, [completedCardExpense]);

      expect(find.text('Awaiting charged amount'), findsNothing);
      expect(find.textContaining('≈'), findsOneWidget);
    });

    testWidgets('cash expense does not show placeholder', (tester) async {
      await pumpTripDetails(tester, [cashExpense]);

      expect(find.text('Awaiting charged amount'), findsNothing);
    });

    testWidgets('same-currency card expense does not show placeholder', (
      tester,
    ) async {
      await pumpTripDetails(tester, [sameCurrencyCardExpense]);

      expect(find.text('Awaiting charged amount'), findsNothing);
    });
  });

  group('trip reports estimated notice', () {
    final reportExpenses = [
      completedCardExpense,
      pendingCardExpense,
      Expense.create(
        id: 'completed-card-2',
        tripId: trip.id,
        title: 'Taxi',
        amount: 50,
        currencyCode: 'CNY',
        transactionAmount: 50,
        transactionCurrency: 'CNY',
        convertedHomeAmount: 26,
        homeCurrency: 'SAR',
        spentAt: DateTime(2026, 6, 5),
        paymentMethod: 'Credit Card',
        paymentNetwork: 'Visa',
        paymentChannel: 'Online Purchase',
        cardProfileId: 1,
        category: 'Transport',
        totalChargedAmount: 26,
        totalChargedCurrency: 'SAR',
      ),
      Expense.create(
        id: 'completed-card-3',
        tripId: trip.id,
        title: 'Museum',
        amount: 80,
        currencyCode: 'CNY',
        transactionAmount: 80,
        transactionCurrency: 'CNY',
        convertedHomeAmount: 41.6,
        homeCurrency: 'SAR',
        spentAt: DateTime(2026, 6, 6),
        paymentMethod: 'Credit Card',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
        cardProfileId: 1,
        category: 'Entertainment',
        totalChargedAmount: 41.6,
        totalChargedCurrency: 'SAR',
      ),
    ];

    testWidgets('report warning appears when pending count > 0', (tester) async {
      await _pumpReport(tester, trip: trip, expenses: reportExpenses);

      expect(find.textContaining('Estimated report'), findsOneWidget);
      expect(
        find.textContaining(
          'Excludes 1 card expense(s) awaiting charged amount.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('report warning hidden when count == 0', (tester) async {
      await _pumpReport(
        tester,
        trip: trip,
        expenses: reportExpenses.where((e) => e.id != 'pending-card').toList(),
      );

      expect(find.textContaining('Estimated report'), findsNothing);
    });
  });

  testWidgets('opening pending expense focuses charged-home field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _FakeExpenseRepository([pendingCardExpense]),
          ),
          cashWalletRepositoryProvider.overrideWithValue(
            _FakeCashWalletRepository(),
          ),
          updateCashExpenseUseCaseProvider.overrideWith(
            (ref) => NoFifoUpdateCashExpenseUseCase(
              expenseRepository: ref.watch(expenseRepositoryProvider),
            ),
          ),
          cardsProvider.overrideWith(() => _FakeCardsNotifier([visaCard])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExpenseFormScreen(
            trip: trip,
            expense: pendingCardExpense,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chargedField = find.byType(TextFormField).at(3);
    final editable = tester.widget<EditableText>(
      find.descendant(of: chargedField, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });
}

Future<void> _pumpReport(
  WidgetTester tester, {
  required Trip trip,
  required List<Expense> expenses,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(
          _FakeExpenseRepository(expenses),
        ),
        tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
        expenseRefundRepositoryProvider.overrideWithValue(
          _FakeRefundRepository(),
        ),
        cashLotRepositoryProvider.overrideWithValue(_FakeCashLotRepository()),
        cashWalletRepositoryProvider.overrideWithValue(
          _FakeCashWalletRepository(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripReportsScreen(trip: trip),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository(this._expenses) : super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }
}

class _FakeTripRepository extends TripRepository {
  _FakeTripRepository(this._trip) : super(AppDatabase());

  final Trip _trip;

  @override
  Future<Trip?> getTripById(String id) async {
    return id == _trip.id ? _trip : null;
  }
}

class _FakeRefundRepository extends ExpenseRefundRepository {
  _FakeRefundRepository() : super(AppDatabase());

  @override
  Future<List<ExpenseRefund>> getActiveRefundsByTrip(String tripId) async =>
      const [];
}

class _FakeCashLotRepository extends CashLotRepository {
  _FakeCashLotRepository() : super(AppDatabase());

  @override
  Future<List<CashLotCurrencySummary>> computeLotCurrencySummaries({
    required String tripId,
    required String homeCurrencyCode,
  }) async =>
      const [];

  @override
  Future<List<CashLot>> getActiveLotsForTrip(String tripId) async => const [];
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository() : super(AppDatabase());

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async =>
      const [];
}

class _FakeCardsNotifier extends CardsNotifier {
  _FakeCardsNotifier(this._cards);

  final List<CardProfile> _cards;

  @override
  Future<List<CardProfile>> build() async => _cards;
}
