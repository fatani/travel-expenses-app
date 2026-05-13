import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:travel_expenses/app/app.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/financial_profile/domain/user_financial_profile.dart';
import 'package:travel_expenses/features/financial_profile/presentation/financial_profile_onboarding_screen.dart';
import 'package:travel_expenses/features/financial_profile/presentation/user_financial_profile_controller.dart';
import 'package:travel_expenses/features/settings/data/settings_repository.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

void main() {
  testWidgets('app initializes with financial onboarding on first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(_FakeTripRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          userFinancialProfileControllerProvider.overrideWith(
            _FakeUserFinancialProfileController.new,
          ),
        ],
        child: const TravelExpensesApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(FinancialProfileOnboardingScreen), findsOneWidget);
  });
}

class _FakeTripRepository extends TripRepository {
  _FakeTripRepository() : super(AppDatabase());

  @override
  Future<Trip> createTrip(Trip trip) async => trip;

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<Trip?> getTripById(String id) async => null;

  @override
  Future<List<Trip>> getTrips() async => const <Trip>[];

  @override
  Future<Trip> updateTrip(Trip trip) async => trip;
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository() : super(AppDatabase());

  @override
  Future<void> initializeDefaults() async {}

  @override
  Future<AppSettings> loadSettings() async {
    final now = DateTime.now().toUtc();
    return AppSettings(
      id: AppSettings.singletonId,
      currencyCode: 'USD',
      localeCode: 'ar',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<AppSettings> saveSettings(AppSettings settings) async => settings;
}

class _FakeUserFinancialProfileController extends UserFinancialProfileController {
  @override
  Future<UserFinancialProfile?> build() async => null;
}
