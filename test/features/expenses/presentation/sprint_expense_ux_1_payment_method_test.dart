import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/expense_payment.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_option_labels.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/settings/presentation/cards_provider.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/no_fifo_record_cash_expense_use_case.dart';
import '../../../support/test_expense_repository.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-ux1',
    name: 'Tokyo',
    destination: 'Tokyo',
    baseCurrency: 'JPY',
    homeCurrencySnapshot: 'SAR',
  );

  final testCard = CardProfile(
    id: 1,
    name: 'Visa',
    cardNetwork: 'Visa',
    last4: '4242',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('Sprint Expense UX-1 — payment method redesign', () {
    testWidgets('cash payment saves correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = _RecordingExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          trip: trip,
        ),
      );
      await tester.pumpAndSettle();

      await _fillMinimalExpenseForm(tester, primaryPayment: 'Cash');
      await tester.ensureVisible(find.text('Add expense'));
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();

      expect(repository.createdExpenses, hasLength(1));
      final saved = repository.createdExpenses.single;
      expect(saved.paymentMethod, 'Cash');
      expect(saved.paymentChannel, 'Cash');
      expect(saved.cardProfileId, isNull);
    });

    testWidgets('card payment requires card selection', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = _RecordingExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          trip: trip,
          cards: [testCard],
        ),
      );
      await tester.pumpAndSettle();

      await _fillMinimalExpenseForm(tester, primaryPayment: 'Card');
      await tester.pumpAndSettle();

      // Clear auto-selected card to simulate missing selection.
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No card').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add expense'));
      await tester.tap(find.text('Add expense'));
      await tester.pump();

      expect(find.text('Please select the card used.'), findsOneWidget);
      expect(repository.createdExpenses, isEmpty);
    });

    testWidgets('POS card payment saves correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = _RecordingExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          trip: trip,
          cards: [testCard],
        ),
      );
      await tester.pumpAndSettle();

      await _fillMinimalExpenseForm(
        tester,
        primaryPayment: 'Card',
        purchaseChannel: 'POS Purchase',
      );
      await tester.ensureVisible(find.text('Add expense'));
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();

      expect(repository.createdExpenses, hasLength(1));
      final saved = repository.createdExpenses.single;
      expect(saved.paymentMethod, 'Credit Card');
      expect(saved.paymentChannel, 'POS Purchase');
      expect(saved.paymentNetwork, 'Visa');
      expect(saved.cardProfileId, 1);
      expect(saved.paymentChannel, isNot('Cash'));
    });

    testWidgets('online card payment saves correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = _RecordingExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          trip: trip,
          cards: [testCard],
        ),
      );
      await tester.pumpAndSettle();

      await _fillMinimalExpenseForm(
        tester,
        primaryPayment: 'Card',
        purchaseChannel: 'Online Purchase',
      );
      await tester.ensureVisible(find.text('Add expense'));
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();

      expect(repository.createdExpenses, hasLength(1));
      final saved = repository.createdExpenses.single;
      expect(saved.paymentMethod, 'Credit Card');
      expect(saved.paymentChannel, 'Online Purchase');
      expect(saved.cardProfileId, 1);
    });

    test('card payment never stores paymentChannel = Cash', () {
      final normalized = normalizeExpensePaymentMetadata(
        paymentMethod: 'Credit Card',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
        cardProfileId: 1,
      );

      expect(normalized.paymentChannel, 'POS Purchase');
      expect(normalized.paymentChannel, isNot('Cash'));
    });

    test('refund routing still works for cash expenses', () {
      expect(
        isCashExpensePayment(paymentMethod: 'Cash', paymentChannel: 'Cash'),
        isTrue,
      );
      expect(RefundDestination.cash, RefundDestination.cash);
    });

    test('refund routing still works for card expenses', () {
      expect(
        isCashExpensePayment(
          paymentMethod: 'Credit Card',
          paymentChannel: 'POS Purchase',
        ),
        isFalse,
      );
      expect(RefundDestination.card, RefundDestination.card);
    });

    test('payment source summary counts Credit Card as card', () {
      final expenses = [
        _expense(paymentMethod: 'Credit Card', currency: 'SAR', amount: 100),
      ];
      final result = const TripReportCalculator().calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: expenses,
      );

      expect(
        result.paymentSourceSummary.single.paymentType,
        'card',
      );
    });

    test('payment source summary counts Debit Card as card', () {
      final expenses = [
        _expense(paymentMethod: 'Debit Card', currency: 'SAR', amount: 50),
      ];
      final result = const TripReportCalculator().calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: expenses,
      );

      expect(
        result.paymentSourceSummary.single.paymentType,
        'card',
      );
    });

    test('primary payment methods match Quick Add chips', () {
      expect(
        ExpenseOptionLabels.primaryPaymentMethods,
        ['Cash', 'Card', 'Other'],
      );
    });

    testWidgets('form shows Cash Card Other as primary payment choices',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildApp(
          repository: _RecordingExpenseRepository(),
          trip: trip,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Card'), findsWidgets);
      expect(find.text('Other'), findsWidgets);
      expect(find.text('POS Purchase'), findsNothing);
      expect(find.text('Online Purchase'), findsNothing);
    });
  });
}

Expense _expense({
  required String paymentMethod,
  required String currency,
  required double amount,
}) {
  final now = DateTime.now();
  return Expense(
    id: 'exp-${now.microsecondsSinceEpoch}',
    tripId: 'trip-ux1',
    title: 'test',
    amount: amount,
    currencyCode: currency,
    transactionAmount: amount,
    transactionCurrency: currency,
    originalAmount: amount,
    originalCurrency: currency,
    convertedHomeAmount: amount,
    homeCurrency: 'SAR',
    isInternational: false,
    spentAt: now,
    paymentMethod: paymentMethod,
    source: 'manual',
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _fillMinimalExpenseForm(
  WidgetTester tester, {
  String primaryPayment = 'Cash',
  String? purchaseChannel,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Lunch');
  await tester.enterText(find.byType(TextFormField).at(1), '25');
  await tester.enterText(find.byType(TextFormField).at(2), 'JPY');

  await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Food').last);
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text(primaryPayment).last);
  await tester.pumpAndSettle();

  if (primaryPayment == 'Card' && purchaseChannel != null) {
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text(purchaseChannel).last);
    await tester.pumpAndSettle();
  }
}

Widget _buildApp({
  required _RecordingExpenseRepository repository,
  required Trip trip,
  List<CardProfile> cards = const [],
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repository),
      cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
      recordCashExpenseUseCaseProvider.overrideWith(
        (ref) => NoFifoRecordCashExpenseUseCase(
          expenseRepository: ref.watch(expenseRepositoryProvider),
          cashWalletRepository: ref.watch(cashWalletRepositoryProvider),
        ),
      ),
      cardsProvider.overrideWith(() => _FakeCardsNotifier(cards)),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ExpenseFormScreen(trip: trip),
    ),
  );
}

class _RecordingExpenseRepository extends TestExpenseRepository {
  _RecordingExpenseRepository() : super(AppDatabase());

  final List<Expense> createdExpenses = <Expense>[];

  @override
  Future<Expense> createExpense(Expense expense, {DatabaseExecutor? txn}) async {
    createdExpenses.add(expense);
    return expense;
  }
}

class _FakeCardsNotifier extends CardsNotifier {
  _FakeCardsNotifier(this._cards);

  final List<CardProfile> _cards;

  @override
  Future<List<CardProfile>> build() async => _cards;
}

class _NoOpCashWalletRepository extends CashWalletRepository {
  _NoOpCashWalletRepository() : super(AppDatabase());
}
