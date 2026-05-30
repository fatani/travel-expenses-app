import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/app/home_entry_screen.dart';
import 'package:travel_expenses/features/financial_profile/domain/user_financial_profile.dart';
import 'package:travel_expenses/features/financial_profile/presentation/financial_profile_onboarding_screen.dart';
import 'package:travel_expenses/features/financial_profile/presentation/user_financial_profile_controller.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/domain/country_info.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trip_form_screen.dart';
import 'package:travel_expenses/features/trips/presentation/trips_list_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': false,
    });
  });

  testWidgets('onboarding shows English explanatory copy', (tester) async {
    await tester.pumpWidget(_buildOnboardingApp());
    await tester.pumpAndSettle();

    expect(find.byType(FinancialProfileOnboardingScreen), findsOneWidget);
    expect(find.text("What's your home country?"), findsOneWidget);
    expect(
      find.text(
        'We use this for your home currency in reports and to compare spending while you travel.',
      ),
      findsOneWidget,
    );
    expect(find.text('Where do you live?'), findsNothing);
  });

  testWidgets('onboarding shows natural Arabic explanatory copy', (tester) async {
    await tester.pumpWidget(_buildOnboardingApp(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('ما هو بلدك الأساسي؟'), findsOneWidget);
    expect(
      find.text(
        'نستخدم هذا لتحديد عملتك الأساسية في التقارير وعرض مصاريف السفر بعملتك.',
      ),
      findsOneWidget,
    );
    expect(find.text('أين تقيم؟'), findsNothing);
  });

  testWidgets('completing onboarding continues to trips empty state',
      (tester) async {
    await tester.pumpWidget(_buildHomeEntryApp());
    await tester.pumpAndSettle();

    expect(find.byType(FinancialProfileOnboardingScreen), findsOneWidget);

    await tester.tap(find.text('Saudi Arabia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(FinancialProfileOnboardingScreen), findsNothing);
    expect(find.byType(TripsListScreen), findsOneWidget);
    expect(find.text('Track spending while you travel'), findsOneWidget);
    expect(find.text('Add trip'), findsOneWidget);
  });

  testWidgets('trips empty state add trip CTA still opens trip setup after onboarding',
      (tester) async {
    await tester.pumpWidget(_buildHomeEntryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saudi Arabia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add trip'));
    await tester.pumpAndSettle();

    expect(find.byType(TripFormScreen), findsOneWidget);
    expect(find.text('Where are you going?'), findsOneWidget);
  });
}

Widget _buildOnboardingApp({Locale locale = const Locale('en')}) {
  return ProviderScope(
    overrides: [
      userFinancialProfileControllerProvider.overrideWith(
        _EmptyFinancialProfileController.new,
      ),
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const FinancialProfileOnboardingScreen(),
    ),
  );
}

Widget _buildHomeEntryApp({Locale locale = const Locale('en')}) {
  return ProviderScope(
    overrides: [
      userFinancialProfileControllerProvider.overrideWith(
        _FlowFinancialProfileController.new,
      ),
      tripsControllerProvider.overrideWith(() => _EmptyTripsController()),
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeEntryScreen(),
    ),
  );
}

class _EmptyFinancialProfileController extends UserFinancialProfileController {
  @override
  Future<UserFinancialProfile?> build() async => null;
}

class _FlowFinancialProfileController extends UserFinancialProfileController {
  @override
  Future<UserFinancialProfile?> build() async => state.valueOrNull;

  @override
  Future<void> setHomeCountry(CountryInfo country) async {
    final now = DateTime.now().toUtc();
    state = AsyncData(
      UserFinancialProfile(
        homeCountryCode: country.countryCode,
        homeCountryEnglish: country.englishName,
        homeCountryArabic: country.arabicName,
        homeCurrencyCode: country.currencyCode,
        onboardingCompleted: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class _EmptyTripsController extends TripsController {
  @override
  Future<List<Trip>> build() async => const [];
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults();
}
