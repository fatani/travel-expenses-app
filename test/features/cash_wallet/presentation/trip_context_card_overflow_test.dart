import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  Trip upcomingTrip({required String name, required String destination}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.add(const Duration(days: 2));
    return Trip.create(
      id: 'trip-cash-wallet-overflow',
      name: name,
      destination: destination,
      baseCurrency: 'GBP',
      destinationCurrency: 'GBP',
      startDate: start,
      endDate: start.add(const Duration(days: 10)),
    );
  }

  final longTitleTrip = upcomingTrip(
    name: 'United Kingdom of Great Britain and Northern Ireland Conference',
    destination: 'London, United Kingdom',
  );

  final longArabicTrip = upcomingTrip(
    name: 'رحلة عمل إلى المملكة العربية السعودية للمؤتمر السنوي الدولي',
    destination: 'الرياض، المملكة العربية السعودية',
  );

  Future<void> pumpCashWallet(
    WidgetTester tester, {
    required Trip trip,
    required Locale locale,
    double textScaleFactor = 1.0,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashWalletRepositoryProvider.overrideWithValue(
            _EmptyCashWalletRepository(),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
            child: TripCashWalletScreen(trip: trip),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('trip context header has no overflow on narrow LTR layout',
      (tester) async {
    await pumpCashWallet(
      tester,
      trip: longTitleTrip,
      locale: const Locale('en'),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('cash_wallet_trip_context_card')), findsOneWidget);
    expect(find.textContaining('Starts in'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('cash_wallet_trip_context_card')),
        matching: find.textContaining('United Kingdom of Great Britain'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('trip context header has no overflow on narrow RTL layout',
      (tester) async {
    await pumpCashWallet(
      tester,
      trip: longArabicTrip,
      locale: const Locale('ar'),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('تبدأ بعد'), findsOneWidget);
    expect(find.textContaining('رحلة عمل'), findsOneWidget);
  });

  testWidgets('trip context header survives large text scale without overflow',
      (tester) async {
    await pumpCashWallet(
      tester,
      trip: longTitleTrip,
      locale: const Locale('en'),
      textScaleFactor: 2.0,
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Starts in'), findsOneWidget);
  });
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
