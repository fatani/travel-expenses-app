import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/financial_profile/domain/user_financial_profile.dart';
import 'package:travel_expenses/features/financial_profile/presentation/user_financial_profile_controller.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trip_form_screen.dart';
import 'package:travel_expenses/features/trips/presentation/trip_setup_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Screen 1 — trip creation', () {
    testWidgets('primary CTA says Continue not Create trip', (tester) async {
      await tester.pumpWidget(_buildCreateTripApp());
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Create trip'), findsNothing);
    });

    testWidgets('Continue opens Trip Setup when destination selected',
        (tester) async {
      await tester.pumpWidget(_buildCreateTripApp());
      await tester.pump();

      await _selectCountry(tester, countryName: 'Thailand');

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TripSetupScreen), findsOneWidget);
      expect(find.text('Before you go'), findsOneWidget);
    });

    testWidgets('custom trip name field is shown after destination selected',
        (tester) async {
      await tester.pumpWidget(_buildCreateTripApp());
      await tester.pump();

      await _selectCountry(tester, countryName: 'Thailand');

      expect(find.text('Trip name (optional)'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('custom trip name is passed to Trip Setup', (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildCreateTripApp(
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
          ],
        ),
      );
      await tester.pump();

      await _selectCountry(tester, countryName: 'Thailand');
      await tester.enterText(find.byType(TextField).at(1), 'Dream Vacation');
      await tester.pump();

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Create trip'));
      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.createCalls.length, 1);
      expect(recording.createCalls.first.name, 'Dream Vacation');
      expect(recording.createCalls.first.isCustomTitle, isTrue);
    });

    testWidgets('empty trip name falls back to auto-generated name', (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildCreateTripApp(
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
          ],
        ),
      );
      await tester.pump();

      await _selectCountry(tester, countryName: 'Thailand');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Create trip'));
      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.createCalls.length, 1);
      expect(recording.createCalls.first.name, 'Thailand Trip');
      expect(recording.createCalls.first.isCustomTitle, isFalse);
    });

    testWidgets('description field accepts input on screen 1', (tester) async {
      await tester.pumpWidget(_buildCreateTripApp());
      await tester.pump();

      await _selectCountry(tester, countryName: 'Thailand');
      await tester.enterText(find.byType(TextField).last, 'Honeymoon trip');
      await tester.pump();

      expect(find.text('Honeymoon trip'), findsOneWidget);
    });

    testWidgets('description is passed through setup and persisted on create',
        (tester) async {
      final recording = _RecordingTripsController();

      await tester.pumpWidget(
        _buildCreateTripApp(
          overrides: [
            tripsControllerProvider.overrideWith(() => recording),
          ],
        ),
      );
      await tester.pump();

      await _selectCountry(tester, countryName: 'Thailand');
      await tester.enterText(find.byType(TextField).last, 'Honeymoon trip');
      await tester.pump();

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Create trip'));
      await tester.tap(find.text('Create trip'));
      await tester.pump();

      expect(recording.createCalls.length, 1);
      expect(recording.createCalls.first.description, 'Honeymoon trip');
    });

    testWidgets('edit mode loads existing description', (tester) async {
      final trip = Trip.create(
        id: 'trip-edit-description',
        name: 'Paris Trip',
        destination: 'France',
        baseCurrency: 'EUR',
        description: 'Anniversary notes',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userFinancialProfileControllerProvider.overrideWith(
              _FakeFinancialProfileController.new,
            ),
            settingsControllerProvider.overrideWith(_FakeSettingsController.new),
            tripsControllerProvider.overrideWith(
              () => _RecordingTripsController(existing: [trip]),
            ),
            cashWalletRepositoryProvider.overrideWithValue(
              _RecordingCashWalletRepository(),
            ),
            tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripFormScreen(trip: trip),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Anniversary notes'), findsOneWidget);
    });
  });
}

Future<void> _selectCountry(
  WidgetTester tester, {
  required String countryName,
}) async {
  await tester.enterText(find.byType(TextField).first, countryName);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text(countryName).last);
  await tester.pump();
}

Widget _buildCreateTripApp({List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      userFinancialProfileControllerProvider.overrideWith(
        _FakeFinancialProfileController.new,
      ),
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
      tripsControllerProvider.overrideWith(_RecordingTripsController.new),
      cashWalletRepositoryProvider.overrideWithValue(
        _RecordingCashWalletRepository(),
      ),
      tripRepositoryProvider.overrideWithValue(_EmptyTripRepository()),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TripFormScreen(),
    ),
  );
}

class _FakeFinancialProfileController extends UserFinancialProfileController {
  @override
  Future<UserFinancialProfile?> build() async => null;
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults();

  @override
  Future<void> updateLocale(String locale) async {}
}

class _RecordingTripsController extends TripsController {
  _RecordingTripsController({List<Trip> existing = const []}) : _existing = existing;

  final List<Trip> _existing;
  final List<_CreateCall> createCalls = [];

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
    String? description,
  }) async {
    createCalls.add(
      _CreateCall(
        name: name,
        isCustomTitle: isCustomTitle,
        description: description,
      ),
    );
    return tripToReturn;
  }
}

class _CreateCall {
  _CreateCall({
    required this.name,
    required this.isCustomTitle,
    this.description,
  });

  final String name;
  final bool isCustomTitle;
  final String? description;
}

class _RecordingCashWalletRepository extends CashWalletRepository {
  _RecordingCashWalletRepository() : super(AppDatabase());
}

class _EmptyTripRepository extends TripRepository {
  _EmptyTripRepository() : super(AppDatabase());

  @override
  Future<List<Trip>> getTrips() async => const [];
}
