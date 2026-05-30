import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/settings/presentation/add_card_screen.dart';
import 'package:travel_expenses/features/settings/presentation/cards_provider.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/country_database.dart';
import 'package:travel_expenses/features/trips/domain/country_info.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trip_form_screen.dart';
import 'package:travel_expenses/features/trips/presentation/trip_setup_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CountryInfo thailand;

  setUp(() {
    thailand = CountryDatabase.countries
        .firstWhere((country) => country.countryCode == 'TH');
  });

  group('Trip creation', () {
    testWidgets('creates trip with no setup data via Skip setup', (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
            cashWalletRepositoryProvider.overrideWithValue(
              recording.cashWallet,
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Skip setup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(recording.createCalls.length, 1);
      expect(recording.createCalls.first.startDate, isNull);
      expect(recording.createCalls.first.endDate, isNull);
      expect(recording.cashWallet.addCalls, 0);
    });

    testWidgets('creates trip with dates only', (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      await _pickDate(tester, fieldIndex: 0, dayText: '10');
      await _pickDate(tester, fieldIndex: 1, dayText: '20');

      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.createCalls.length, 1);
      expect(recording.createCalls.first.startDate?.day, 10);
      expect(recording.createCalls.first.endDate?.day, 20);
      expect(recording.cashWallet.addCalls, 0);
    });

    testWidgets('creates trip with one cash currency', (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
            cashWalletRepositoryProvider.overrideWithValue(
              recording.cashWallet,
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).last, '1500');
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.createCalls.length, 1);
      expect(recording.cashWallet.addCalls, 1);
      expect(recording.cashWallet.lastCurrency, 'THB');
      expect(recording.cashWallet.lastAmount, 1500);
    });

    testWidgets('creates trip with multiple currencies', (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
            cashWalletRepositoryProvider.overrideWithValue(
              recording.cashWallet,
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(2), '1000');
      await tester.pump();
      await tester.ensureVisible(find.text('Add another currency'));
      await tester.tap(find.text('Add another currency'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).last, '250');
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.cashWallet.addCalls, 2);
      expect(recording.cashWallet.currencies, ['THB', 'USD']);
    });

    testWidgets('creates fully configured trip', (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
            cashWalletRepositoryProvider.overrideWithValue(
              recording.cashWallet,
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      await _pickDate(tester, fieldIndex: 0, dayText: '5');
      await _pickDate(tester, fieldIndex: 1, dayText: '12');
      await tester.enterText(find.byType(TextField).at(2), '800');
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.createCalls.first.startDate, isNotNull);
      expect(recording.createCalls.first.endDate, isNotNull);
      expect(recording.cashWallet.addCalls, 1);
    });
  });

  group('Cards', () {
    testWidgets('displays existing global cards', (tester) async {
      final card = CardProfile(
        id: 7,
        name: 'Test Visa',
        bankName: 'visa',
        cardNetwork: 'visa',
        cardTier: 'classic',
        last4: '4242',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          cards: [card],
          overrides: [
            tripsControllerProvider.overrideWith(_RecordingTripsController.new),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.textContaining('4242'), findsOneWidget);
      expect(find.text('No cards yet. Add one now or skip.'), findsNothing);
    });

    test('card profiles have no trip relationship field', () {
      final map = CardProfile(
        id: 1,
        name: 'Card',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ).toMap();

      expect(map.containsKey('trip_id'), isFalse);
    });

    testWidgets('opens Add Card screen from setup', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(_RecordingTripsController.new),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Add card'));
      await tester.tap(find.text('Add card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AddCardScreen), findsOneWidget);
    });

    testWidgets('newly added card appears among global cards', (tester) async {
      final card = CardProfile(
        id: 2,
        name: 'Global Visa',
        bankName: 'visa',
        cardNetwork: 'visa',
        cardTier: 'classic',
        last4: '9999',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          cards: [card],
          overrides: [
            tripsControllerProvider.overrideWith(_RecordingTripsController.new),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.textContaining('9999'), findsOneWidget);
    });
  });

  group('Navigation', () {
    testWidgets('created trip returns through TripFormScreen bridge', (tester) async {
      Trip? parentResult;

      await tester.pumpWidget(
        _buildApp(
          home: _PopResultHost(
            onResult: (trip) => parentResult = trip,
            child: const _TripFormPopBridge(),
          ),
          overrides: [
            tripsControllerProvider.overrideWith(_RecordingTripsController.new),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Launch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Open setup flow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text('Skip setup'));
      await tester.tap(find.text('Skip setup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(parentResult, isNotNull);
      expect(parentResult!.id, 'created-trip');
    });
  });

  group('Regression', () {
    testWidgets('TripFormScreen edit mode is unaffected', (tester) async {
      final trip = Trip.create(
        id: 'trip-edit',
        name: 'Paris Trip',
        destination: 'France',
        baseCurrency: 'EUR',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 10),
      );

      await tester.pumpWidget(
        _buildApp(
          home: TripFormScreen(trip: trip),
          overrides: [
            tripsControllerProvider.overrideWith(
              () => _RecordingTripsController(existing: [trip]),
            ),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Save changes'), findsOneWidget);
      expect(find.byType(TripSetupScreen), findsNothing);
      expect(find.text('Skip setup'), findsNothing);
    });
  });

  group('Error handling', () {
    testWidgets('initial cash failure rolls back trip and keeps setup open',
        (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
            cashWalletRepositoryProvider.overrideWithValue(
              _FailingCashWalletRepository(),
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).last, '500');
      await tester.pump();
      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.createCalls.length, 1);
      expect(recording.deleteCalls.length, 1);
      expect(recording.deleteCalls.first, 'created-trip');
      expect(find.byType(TripSetupScreen), findsOneWidget);
      expect(
        find.textContaining("Couldn't save starting cash"),
        findsOneWidget,
      );
    });

    testWidgets('partial cash failure rolls back trip after first currency',
        (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
            cashWalletRepositoryProvider.overrideWithValue(
              _FailOnSecondCashWalletRepository(),
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(2), '1000');
      await tester.pump();
      await tester.ensureVisible(find.text('Add another currency'));
      await tester.tap(find.text('Add another currency'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '250');
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.createCalls.length, 1);
      expect(recording.deleteCalls.length, 1);
      expect(recording.deleteCalls.first, 'created-trip');
      expect(find.byType(TripSetupScreen), findsOneWidget);
    });
  });

  group('Small screen usability', () {
    testWidgets('short viewport keeps actions reachable with multiple cash rows',
        (tester) async {
      tester.view.physicalSize = const Size(360, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(_RecordingTripsController.new),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Add another currency'));
      await tester.tap(find.text('Add another currency'));
      await tester.pump();
      await tester.tap(find.text('Add another currency'));
      await tester.pump();

      await tester.ensureVisible(find.text('Create trip'));
      await tester.ensureVisible(find.text('Skip setup'));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('short arabic viewport stays scrollable with multiple cash rows',
        (tester) async {
      tester.view.physicalSize = const Size(360, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          locale: const Locale('ar'),
          overrides: [
            tripsControllerProvider.overrideWith(_RecordingTripsController.new),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('إضافة عملة أخرى'));
      await tester.tap(find.text('إضافة عملة أخرى'));
      await tester.pump();
      await tester.tap(find.text('إضافة عملة أخرى'));
      await tester.pump();

      await tester.ensureVisible(find.text('إنشاء الرحلة'));
      await tester.ensureVisible(find.text('تخطي الإعداد'));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard inset keeps amount field reachable on short viewport',
        (tester) async {
      tester.view.physicalSize = const Size(360, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          overrides: [
            tripsControllerProvider.overrideWith(_RecordingTripsController.new),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
        ),
      );
      await tester.pump();

      final amountField = find.byType(TextField).last;
      await tester.ensureVisible(amountField);
      await tester.tap(amountField);
      await tester.pump();

      await tester.showKeyboard(amountField);
      await tester.pump();

      await tester.ensureVisible(find.text('Create trip'));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

}

Future<void> _pickDate(
  WidgetTester tester, {
  required int fieldIndex,
  required String dayText,
}) async {
  await tester.tap(find.byType(TextField).at(fieldIndex));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(dayText));
  await tester.pump();
  await tester.tap(find.text('OK'));
  await tester.pump();
}

Widget _buildApp({
  required Widget home,
  List<Override> overrides = const [],
  List<CardProfile> cards = const [],
  Locale? locale,
}) {
  return ProviderScope(
    overrides: [
      cardsProvider.overrideWith(() => _FakeCardsNotifier(cards)),
      ...overrides,
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class _PopResultHost extends StatelessWidget {
  const _PopResultHost({
    required this.child,
    required this.onResult,
  });

  final Widget child;
  final ValueChanged<Trip?> onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final trip = await Navigator.of(context).push<Trip>(
              MaterialPageRoute<Trip>(builder: (_) => child),
            );
            onResult(trip);
          },
          child: const Text('Launch'),
        ),
      ),
    );
  }
}

class _TripFormPopBridge extends StatelessWidget {
  const _TripFormPopBridge();

  @override
  Widget build(BuildContext context) {
    final thailand = CountryDatabase.countries
        .firstWhere((country) => country.countryCode == 'TH');

    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final createdTrip = await Navigator.of(context).push<Trip>(
              MaterialPageRoute<Trip>(
                builder: (_) => TripSetupScreen(selectedDestination: thailand),
              ),
            );
            if (createdTrip != null && context.mounted) {
              Navigator.of(context).pop(createdTrip);
            }
          },
          child: const Text('Open setup flow'),
        ),
      ),
    );
  }
}

class _RecordingTripsController extends TripsController {
  _RecordingTripsController({List<Trip> existing = const []})
      : _existing = existing,
        cashWallet = _RecordingCashWalletRepository();

  final List<Trip> _existing;
  final List<_CreateCall> createCalls = [];
  final List<String> deleteCalls = [];
  final _RecordingCashWalletRepository cashWallet;

  final Trip tripToReturn = Trip.create(
    id: 'created-trip',
    name: 'Thailand Trip',
    destination: 'Thailand',
    baseCurrency: 'THB',
  );

  @override
  Future<List<Trip>> build() async => _existing;

  @override
  Future<Trip> createTrip({
    required String name,
    required String destination,
    DateTime? startDate,
    DateTime? endDate,
    required String baseCurrency,
    required String destinationCurrency,
    required String homeCurrencySnapshot,
    double? budget,
    String? budgetCurrency,
    bool isCustomTitle = false,
    String? destinationCountryCode,
  }) async {
    createCalls.add(
      _CreateCall(startDate: startDate, endDate: endDate),
    );
    return tripToReturn;
  }

  @override
  Future<void> deleteTrip(String id) async {
    deleteCalls.add(id);
  }
}

class _CreateCall {
  _CreateCall({this.startDate, this.endDate});

  final DateTime? startDate;
  final DateTime? endDate;
}

class _RecordingCashWalletRepository extends CashWalletRepository {
  _RecordingCashWalletRepository() : super(AppDatabase());

  int addCalls = 0;
  String? lastCurrency;
  double? lastAmount;
  final List<String> currencies = [];

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
    addCalls++;
    lastCurrency = currencyCode;
    lastAmount = amount;
    currencies.add(currencyCode);
  }
}

class _FailingCashWalletRepository extends CashWalletRepository {
  _FailingCashWalletRepository() : super(AppDatabase());

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
    throw StateError('cash save failed');
  }
}

class _FailOnSecondCashWalletRepository extends CashWalletRepository {
  _FailOnSecondCashWalletRepository() : super(AppDatabase());

  int _calls = 0;

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
    _calls++;
    if (_calls >= 2) {
      throw StateError('cash save failed on second currency');
    }
  }
}

class _EmptyTripRepository extends TripRepository {
  _EmptyTripRepository() : super(AppDatabase());

  @override
  Future<List<Trip>> getTrips() async => const [];
}

class _FakeCardsNotifier extends CardsNotifier {
  _FakeCardsNotifier(this._cards);

  final List<CardProfile> _cards;

  @override
  Future<List<CardProfile>> build() async => _cards;
}
