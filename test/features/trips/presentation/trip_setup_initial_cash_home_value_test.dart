import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/financial_profile/domain/user_financial_profile.dart';
import 'package:travel_expenses/features/financial_profile/presentation/user_financial_profile_controller.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/settings/presentation/cards_provider.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/country_database.dart';
import 'package:travel_expenses/features/trips/domain/country_info.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trip_setup_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CountryInfo thailand;

  setUp(() {
    thailand = CountryDatabase.countries
        .firstWhere((country) => country.countryCode == 'TH');
  });

  group('Sprint UX-1B — initial cash home value', () {
    testWidgets('initial cash row shows optional home-value field', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
        ),
      );
      await tester.pump();

      expect(_cashHomeValueField(), findsOneWidget);
      expect(
        find.text(
          'This helps calculate your trip cost more accurately in your home currency.',
        ),
        findsOneWidget,
      );
      expect(find.text('Example: 1050 SAR'), findsOneWidget);
    });

    testWidgets('dynamic home currency label displays SAR', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
        ),
      );
      await tester.pump();

      expect(find.text('Approximate value in SAR (Recommended)'), findsOneWidget);
    });

    testWidgets('dynamic home currency label displays USD', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'USD',
        ),
      );
      await tester.pump();

      expect(find.text('Approximate value in USD (Recommended)'), findsOneWidget);
    });

    testWidgets('passes home value to addCashTransaction when provided',
        (tester) async {
      final recording = _RecordingCashWalletRepository();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
          cashWallet: recording,
        ),
      );
      await tester.pump();

      await tester.enterText(_cashAmountField(), '10000');
      await tester.enterText(_cashHomeValueField(), '1050');
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.addCalls, 1);
      expect(recording.lastHomeCurrencyAmount, closeTo(1050, 0.000001));
      expect(recording.lastHomeCurrencyCode, 'SAR');
    });

    testWidgets('empty home value passes null basis', (tester) async {
      final recording = _RecordingCashWalletRepository();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
          cashWallet: recording,
        ),
      );
      await tester.pump();

      await tester.enterText(_cashAmountField(), '10000');
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();
      await _confirmMissingHomeValueDialog(tester);

      expect(recording.lastHomeCurrencyAmount, isNull);
      expect(recording.lastHomeCurrencyCode, isNull);
    });

    testWidgets('zero home value passes null basis', (tester) async {
      final recording = _RecordingCashWalletRepository();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
          cashWallet: recording,
        ),
      );
      await tester.pump();

      await tester.enterText(_cashAmountField(), '10000');
      await tester.enterText(_cashHomeValueField(), '0');
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();
      await _confirmMissingHomeValueDialog(tester);

      expect(recording.lastHomeCurrencyAmount, isNull);
      expect(recording.lastHomeCurrencyCode, isNull);
    });

    testWidgets('invalid home value is ignored without blocking create',
        (tester) async {
      final recording = _RecordingCashWalletRepository();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
          cashWallet: recording,
        ),
      );
      await tester.pump();

      await tester.enterText(_cashAmountField(), '10000');
      await tester.enterText(_cashHomeValueField(), 'abc');
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();
      await _confirmMissingHomeValueDialog(tester);

      expect(recording.addCalls, 1);
      expect(recording.lastHomeCurrencyAmount, isNull);
      expect(recording.lastHomeCurrencyCode, isNull);
    });

    testWidgets('multiple cash rows each support separate home values',
        (tester) async {
      final recording = _RecordingCashWalletRepository();

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
          cashWallet: recording,
        ),
      );
      await tester.pump();

      await tester.enterText(_cashAmountField(rowIndex: 0), '10000');
      await tester.enterText(_cashHomeValueField(rowIndex: 0), '1050');
      await tester.pump();
      await tester.ensureVisible(find.text('Add currency'));
      await tester.tap(find.text('Add currency'));
      await tester.pump();
      await tester.enterText(_cashAmountField(rowIndex: 1), '250');
      await tester.enterText(_cashHomeValueField(rowIndex: 1), '62.5');
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.addCallLog, hasLength(2));
      expect(recording.addCallLog[0].homeCurrencyAmount, closeTo(1050, 0.000001));
      expect(recording.addCallLog[0].homeCurrencyCode, 'SAR');
      expect(recording.addCallLog[1].homeCurrencyAmount, closeTo(62.5, 0.000001));
      expect(recording.addCallLog[1].homeCurrencyCode, 'SAR');
    });
  });

  group('Sprint UX-1C — recommend initial cash home value', () {
    testWidgets('recommended label visible', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
        ),
      );
      await tester.pump();

      expect(find.text('Approximate value in SAR (Recommended)'), findsOneWidget);
    });

    testWidgets('recommended helper text visible', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'This helps calculate your trip cost more accurately in your home currency.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('dialog appears when cash amount exists and home value missing',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
        ),
      );
      await tester.pump();

      await tester.enterText(_cashAmountField(), '10000');
      await tester.pump();
      await tester.tap(find.text('Create trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('You did not enter the approximate value of your cash.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'The app will still work normally, but some trip-cost reports in your home currency may be less accurate.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('continue creates trip successfully', (tester) async {
      final recording = _RecordingTripsController(homeCurrencyCode: 'SAR');

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
          tripsController: recording,
        ),
      );
      await tester.pump();

      await tester.enterText(_cashAmountField(), '10000');
      await tester.pump();
      await tester.tap(find.text('Create trip'));
      await tester.pump();
      await _confirmMissingHomeValueDialog(tester);

      expect(recording.createCalls, 1);
    });

    testWidgets('back returns to form without creating trip', (tester) async {
      final recording = _RecordingTripsController(homeCurrencyCode: 'SAR');

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
          tripsController: recording,
        ),
      );
      await tester.pump();

      await tester.enterText(_cashAmountField(), '10000');
      await tester.pump();
      await tester.tap(find.text('Create trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(recording.createCalls, 0);
      expect(find.byType(TripSetupScreen), findsOneWidget);
    });

    testWidgets('no dialog when no cash rows', (tester) async {
      final recording = _RecordingTripsController(homeCurrencyCode: 'SAR');

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
          tripsController: recording,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Create trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('You did not enter the approximate value of your cash.'),
        findsNothing,
      );
      expect(recording.createCalls, 1);
    });

    testWidgets('no dialog when all rows have home values', (tester) async {
      final recording = _RecordingTripsController(homeCurrencyCode: 'SAR');

      await tester.pumpWidget(
        _buildApp(
          home: TripSetupScreen(selectedDestination: thailand),
          homeCurrencyCode: 'SAR',
          tripsController: recording,
        ),
      );
      await tester.pump();

      await tester.enterText(_cashAmountField(), '10000');
      await tester.enterText(_cashHomeValueField(), '1050');
      await tester.pump();
      await tester.tap(find.text('Create trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('You did not enter the approximate value of your cash.'),
        findsNothing,
      );
      expect(recording.createCalls, 1);
    });
  });

  group('Sprint UX-1B — cash lot persistence', () {
    late AppDatabase appDatabase;
    late TripRepository tripRepository;
    late CashWalletRepository cashWalletRepository;

    setUp(() async {
      appDatabase = createIsolatedAppDatabase(prefix: 'ux1b_home_value');
      tripRepository = TripRepository(appDatabase);
      cashWalletRepository = CashWalletRepository(appDatabase);
    });

    tearDown(() async {
      await appDatabase.close();
    });

    Future<List<Map<String, Object?>>> lotRows(String tripId) async {
      final db = await appDatabase.database;
      return db.query(
        AppDatabase.cashLotsTable,
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'created_at ASC',
      );
    }

    test('creating trip with home value populates cash_lot basis fields',
        () async {
      final trip = await tripRepository.createTrip(
        Trip.create(
          id: 'trip-ux1b-basis',
          name: 'Bangkok Trip',
          destination: 'Thailand',
          baseCurrency: 'THB',
          homeCurrencySnapshot: 'SAR',
        ),
      );

      await cashWalletRepository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 10000,
        currencyCode: 'THB',
        homeCurrencyAmount: 1050,
        homeCurrencyCode: trip.homeCurrencySnapshot,
      );

      final lot = CashLot.fromMap((await lotRows(trip.id)).single);
      expect(lot.homeCurrencyAmount, closeTo(1050, 1e-9));
      expect(lot.homeCurrencyCode, 'SAR');
      expect(lot.effectiveRate, closeTo(0.105, 1e-12));
    });

    test('parseOptionalHomeCurrencyAmount normalizes invalid values', () {
      expect(parseOptionalHomeCurrencyAmount(''), isNull);
      expect(parseOptionalHomeCurrencyAmount('   '), isNull);
      expect(parseOptionalHomeCurrencyAmount('0'), isNull);
      expect(parseOptionalHomeCurrencyAmount('-5'), isNull);
      expect(parseOptionalHomeCurrencyAmount('abc'), isNull);
      expect(parseOptionalHomeCurrencyAmount('1050'), closeTo(1050, 0.000001));
    });

    test('empty home value leaves cash_lot basis null', () async {
      final trip = await tripRepository.createTrip(
        Trip.create(
          id: 'trip-ux1b-no-basis',
          name: 'Bangkok Trip',
          destination: 'Thailand',
          baseCurrency: 'THB',
          homeCurrencySnapshot: 'SAR',
        ),
      );

      await cashWalletRepository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 10000,
        currencyCode: 'THB',
      );

      final lot = CashLot.fromMap((await lotRows(trip.id)).single);
      expect(lot.homeCurrencyAmount, isNull);
      expect(lot.homeCurrencyCode, isNull);
      expect(lot.effectiveRate, isNull);
    });
  });
}

Finder _cashAmountField({int rowIndex = 0}) {
  return find.byElementPredicate((element) {
    final widget = element.widget;
    if (widget is! TextField) {
      return false;
    }
    final decoration = widget.decoration;
    if (decoration is! InputDecoration) {
      return false;
    }
    return decoration.labelText == 'Amount';
  }).at(rowIndex);
}

Finder _cashHomeValueField({int rowIndex = 0}) {
  return find.byElementPredicate((element) {
    final widget = element.widget;
    if (widget is! TextField) {
      return false;
    }
    final decoration = widget.decoration;
    if (decoration is! InputDecoration) {
      return false;
    }
    final label = decoration.labelText;
    return label != null &&
        (label.contains('(Recommended)') || label.contains('(موصى بها)'));
  }).at(rowIndex);
}

Future<void> _confirmMissingHomeValueDialog(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  final continueButton = find.text('Continue');
  if (continueButton.evaluate().isNotEmpty) {
    await tester.tap(continueButton);
    await tester.pump();
  }
}

Widget _buildApp({
  required Widget home,
  required String homeCurrencyCode,
  CashWalletRepository? cashWallet,
  _RecordingTripsController? tripsController,
}) {
  final wallet = cashWallet ?? _RecordingCashWalletRepository();
  final trips = tripsController ?? _RecordingTripsController(
    homeCurrencyCode: homeCurrencyCode,
  );

  return ProviderScope(
    overrides: [
      cardsProvider.overrideWith(() => _FakeCardsNotifier(const [])),
      userFinancialProfileControllerProvider.overrideWith(
        () => _FakeFinancialProfileController(homeCurrencyCode),
      ),
      tripsControllerProvider.overrideWith(() => trips),
      cashWalletRepositoryProvider.overrideWithValue(wallet),
      tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class _FakeFinancialProfileController extends UserFinancialProfileController {
  _FakeFinancialProfileController(this.homeCurrencyCode);

  final String homeCurrencyCode;

  @override
  Future<UserFinancialProfile?> build() async {
    final now = DateTime.utc(2026, 1, 1);
    return UserFinancialProfile(
      homeCountryCode: homeCurrencyCode == 'USD' ? 'US' : 'SA',
      homeCountryEnglish: homeCurrencyCode == 'USD' ? 'United States' : 'Saudi Arabia',
      homeCountryArabic: homeCurrencyCode == 'USD' ? 'الولايات المتحدة' : 'السعودية',
      homeCurrencyCode: homeCurrencyCode,
      onboardingCompleted: true,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _RecordingTripsController extends TripsController {
  _RecordingTripsController({required this.homeCurrencyCode});

  final String homeCurrencyCode;
  int createCalls = 0;

  @override
  Future<List<Trip>> build() async => const [];

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
    String? description,
  }) async {
    createCalls++;
    return Trip.create(
      id: 'created-trip',
      name: name,
      destination: destination,
      baseCurrency: baseCurrency,
      destinationCurrency: destinationCurrency,
      homeCurrencySnapshot: homeCurrencySnapshot,
      isCustomTitle: isCustomTitle,
      destinationCountryCode: destinationCountryCode,
      description: description,
    );
  }
}

class _RecordingCashWalletRepository extends CashWalletRepository {
  _RecordingCashWalletRepository() : super(AppDatabase());

  int addCalls = 0;
  double? lastHomeCurrencyAmount;
  String? lastHomeCurrencyCode;
  final List<_CashAddCall> addCallLog = [];

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
    lastHomeCurrencyAmount = homeCurrencyAmount;
    lastHomeCurrencyCode = homeCurrencyCode;
    addCallLog.add(
      _CashAddCall(
        amount: amount,
        currencyCode: currencyCode,
        homeCurrencyAmount: homeCurrencyAmount,
        homeCurrencyCode: homeCurrencyCode,
      ),
    );
  }
}

class _CashAddCall {
  const _CashAddCall({
    required this.amount,
    required this.currencyCode,
    this.homeCurrencyAmount,
    this.homeCurrencyCode,
  });

  final double amount;
  final String currencyCode;
  final double? homeCurrencyAmount;
  final String? homeCurrencyCode;
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
