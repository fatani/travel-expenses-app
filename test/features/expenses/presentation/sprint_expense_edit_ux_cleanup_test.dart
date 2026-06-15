import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import '../../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/settings/presentation/cards_provider.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/no_fifo_update_cash_expense_use_case.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-edit-ux',
    name: 'Test Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
  );

  final sampleExpense = Expense.create(
    id: 'expense-edit-ux',
    tripId: trip.id,
    title: 'Lunch',
    amount: 25,
    currencyCode: 'CNY',
    transactionAmount: 25,
    transactionCurrency: 'CNY',
    spentAt: DateTime(2026, 5, 16, 12, 30),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
    note: 'Quick bite',
  );

  final visaCard = CardProfile(
    id: 1,
    name: 'Visa',
    cardNetwork: 'Visa',
    last4: '4242',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final mastercard = CardProfile(
    id: 2,
    name: 'Mastercard',
    cardNetwork: 'Mastercard',
    last4: '5555',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final cardExpense = Expense.create(
    id: 'expense-card-edit-ux',
    tripId: trip.id,
    title: 'Hotel',
    amount: 100,
    currencyCode: 'CNY',
    transactionAmount: 100,
    transactionCurrency: 'CNY',
    spentAt: DateTime(2026, 5, 16, 12, 30),
    paymentMethod: 'Credit Card',
    paymentNetwork: 'Visa',
    paymentChannel: 'POS Purchase',
    cardProfileId: 1,
    category: 'Accommodation',
    note: 'Stay',
    totalChargedAmount: 50,
    totalChargedCurrency: 'SAR',
  );

  testWidgets('open expense then back shows no snackbar', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _TrackingExpenseRepository(initialExpenses: [sampleExpense]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsNothing);
    expect(find.text('Saved'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('open expense with no changes closes immediately on back', (
    tester,
  ) async {
    final repository = _TrackingExpenseRepository(
      initialExpenses: [sampleExpense],
    );

    await _openExpenseForm(
      tester,
      trip: trip,
      expense: sampleExpense,
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
      ],
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsNothing);
    expect(repository.updateCalls, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('changing a field then back shows discard dialog', (
    tester,
  ) async {
    await _openExpenseForm(
      tester,
      trip: trip,
      expense: sampleExpense,
      overrides: [
        expenseRepositoryProvider.overrideWithValue(
          _TrackingExpenseRepository(initialExpenses: [sampleExpense]),
        ),
      ],
    );

    await tester.enterText(find.byType(TextFormField).at(1), '30');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('You have unsaved changes.\nDiscard them?'), findsOneWidget);
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
  });

  testWidgets('discard changes returns without save', (tester) async {
    final repository = _TrackingExpenseRepository(
      initialExpenses: [sampleExpense],
    );

    await _openExpenseForm(
      tester,
      trip: trip,
      expense: sampleExpense,
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
      ],
    );

    await tester.enterText(find.byType(TextFormField).at(1), '30');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard Changes'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsNothing);
    expect(repository.updateCalls, 0);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('continue editing keeps user on form', (tester) async {
    await _openExpenseForm(
      tester,
      trip: trip,
      expense: sampleExpense,
      overrides: [
        expenseRepositoryProvider.overrideWithValue(
          _TrackingExpenseRepository(initialExpenses: [sampleExpense]),
        ),
      ],
    );

    await tester.enterText(find.byType(TextFormField).at(1), '30');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue Editing'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('save shows snackbar on trip details', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _TrackingExpenseRepository(
      initialExpenses: [sampleExpense],
    );

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '30');
    await tester.pump();

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  group('dirty-state field coverage', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('category change shows discard dialog on back', (tester) async {
      await _openExpenseForm(
        tester,
        trip: trip,
        expense: sampleExpense,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _TrackingExpenseRepository(initialExpenses: [sampleExpense]),
          ),
        ],
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transport').last);
      await tester.pumpAndSettle();

      await _expectDiscardDialogOnBack(tester);
    });

    testWidgets('note change shows discard dialog on back', (tester) async {
      await _openExpenseForm(
        tester,
        trip: trip,
        expense: sampleExpense,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _TrackingExpenseRepository(initialExpenses: [sampleExpense]),
          ),
        ],
      );

      await tester.enterText(find.byType(TextFormField).last, 'Updated note');
      await tester.pump();

      await _expectDiscardDialogOnBack(tester);
    });

    testWidgets('payment method change shows discard dialog on back', (
      tester,
    ) async {
      await _openExpenseForm(
        tester,
        trip: trip,
        expense: sampleExpense,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _TrackingExpenseRepository(initialExpenses: [sampleExpense]),
          ),
        ],
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      await _expectDiscardDialogOnBack(tester);
    });

    testWidgets('payment channel change shows discard dialog on back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await _openExpenseForm(
        tester,
        trip: trip,
        expense: cardExpense,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _TrackingExpenseRepository(initialExpenses: [cardExpense]),
          ),
          cardsProvider.overrideWith(() => _FakeCardsNotifier([visaCard])),
        ],
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online Purchase').last);
      await tester.pumpAndSettle();

      await _expectDiscardDialogOnBack(tester);
    });

    testWidgets('card change shows discard dialog on back', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await _openExpenseForm(
        tester,
        trip: trip,
        expense: cardExpense,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _TrackingExpenseRepository(initialExpenses: [cardExpense]),
          ),
          cardsProvider.overrideWith(
            () => _FakeCardsNotifier([visaCard, mastercard]),
          ),
        ],
      );

      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('5555').last);
      await tester.pumpAndSettle();

      await _expectDiscardDialogOnBack(tester);
    });

    testWidgets('charged home amount change shows discard dialog on back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await _openExpenseForm(
        tester,
        trip: trip,
        expense: cardExpense,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _TrackingExpenseRepository(initialExpenses: [cardExpense]),
          ),
          cardsProvider.overrideWith(() => _FakeCardsNotifier([visaCard])),
        ],
      );

      await tester.enterText(find.text('50.00'), '60');
      await tester.pump();

      await _expectDiscardDialogOnBack(tester);
    });

    testWidgets('date change shows discard dialog on back', (tester) async {
      await _openExpenseForm(
        tester,
        trip: trip,
        expense: sampleExpense,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _TrackingExpenseRepository(initialExpenses: [sampleExpense]),
          ),
        ],
      );

      await tester.tap(find.byIcon(Icons.calendar_today_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('17').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await _expectDiscardDialogOnBack(tester);
    });

    testWidgets('invalid amount text shows discard dialog on back', (
      tester,
    ) async {
      await _openExpenseForm(
        tester,
        trip: trip,
        expense: sampleExpense,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _TrackingExpenseRepository(initialExpenses: [sampleExpense]),
          ),
        ],
      );

      await tester.enterText(find.byType(TextFormField).at(1), 'not-a-number');
      await tester.pump();

      await _expectDiscardDialogOnBack(tester);
    });
  });
}

Future<void> _expectDiscardDialogOnBack(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();

  expect(
    find.text('You have unsaved changes.\nDiscard them?'),
    findsOneWidget,
  );
  expect(find.byType(ExpenseFormScreen), findsOneWidget);
}

Future<void> _openExpenseForm(
  WidgetTester tester, {
  required Trip trip,
  required Expense expense,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    _buildApp(
      child: _ExpenseFormLauncher(trip: trip, expense: expense),
      overrides: overrides,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}

class _ExpenseFormLauncher extends StatelessWidget {
  const _ExpenseFormLauncher({
    required this.trip,
    required this.expense,
  });

  final Trip trip;
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ExpenseFormScreen(
                  trip: trip,
                  expense: expense,
                ),
              ),
            );
          },
          child: const Text('Open form'),
        ),
      ),
    );
  }
}

Widget _buildApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      cashWalletRepositoryProvider.overrideWithValue(_EmptyCashWalletRepository()),
      updateCashExpenseUseCaseProvider.overrideWith(
        (ref) => NoFifoUpdateCashExpenseUseCase(
          expenseRepository: ref.watch(expenseRepositoryProvider),
        ),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

class _TrackingExpenseRepository extends TestExpenseRepository {
  _TrackingExpenseRepository({List<Expense>? initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses ?? const <Expense>[]),
        super(AppDatabase());

  final List<Expense> _expenses;
  int updateCalls = 0;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }

  @override
  Future<Expense?> getExpenseById(String id) async {
    for (final expense in _expenses) {
      if (expense.id == id) {
        return expense;
      }
    }
    return null;
  }

  @override
  Future<Expense> updateExpense(Expense expense, {DatabaseExecutor? txn}) async {
    updateCalls++;
    final index = _expenses.indexWhere((item) => item.id == expense.id);
    if (index >= 0) {
      _expenses[index] = expense;
    }
    return expense;
  }
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());
}

class _FakeCardsNotifier extends CardsNotifier {
  _FakeCardsNotifier(this._cards);

  final List<CardProfile> _cards;

  @override
  Future<List<CardProfile>> build() async => _cards;
}
