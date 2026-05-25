import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travel_expenses/core/formatting/bidi_format.dart';
import 'package:travel_expenses/core/formatting/trip_date_phrase.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/domain/trip_timeline_status.dart';
import 'package:travel_expenses/l10n/app_localizations_en.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  final l10n = AppLocalizationsEn();
  final now = DateTime(2026, 5, 25);

  group('TripDatePhrase.compactDateRange', () {
    test('same month uses day range without year', () {
      expect(
        TripDatePhrase.compactDateRange(
          start: DateTime(2026, 5, 12),
          end: DateTime(2026, 5, 18),
          localeName: 'en',
          referenceNow: now,
        ),
        '12–18 May',
      );
    });

    test('wraps compact range for Arabic RTL', () {
      final result = TripDatePhrase.compactDateRange(
        start: DateTime(2026, 5, 12),
        end: DateTime(2026, 5, 18),
        localeName: 'en',
        wrapForRtl: true,
        referenceNow: now,
      );
      expect(result, wrapLtrIsolate('12–18 May'));
    });
  });

  group('TripDatePhrase.forTripCard', () {
    test('active trip phrase is compact', () {
      final trip = Trip.create(
        id: 't1',
        name: 'Tokyo',
        destination: 'Tokyo',
        baseCurrency: 'JPY',
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 5)),
      );

      final phrase = TripDatePhrase.forTripCard(
        trip: trip,
        status: TripTimelineStatus.active,
        localeName: 'en',
        l10n: l10n,
        isArabic: false,
        now: now,
      );

      expect(phrase, 'Day 3 of 8');
      expect(phrase.contains('ends'), isFalse);
    });

    test('upcoming trip phrase is compact', () {
      final trip = Trip.create(
        id: 't2',
        name: 'Paris',
        destination: 'Paris',
        baseCurrency: 'EUR',
        startDate: now.add(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 12)),
      );

      final phrase = TripDatePhrase.forTripCard(
        trip: trip,
        status: TripTimelineStatus.upcoming,
        localeName: 'en',
        l10n: l10n,
        isArabic: false,
        now: now,
      );

      expect(phrase, 'Starts in 5 days');
    });

    test('missing dates use calm wording', () {
      final trip = Trip.create(
        id: 't3',
        name: 'Rome',
        destination: 'Rome',
        baseCurrency: 'EUR',
      );

      expect(
        TripDatePhrase.forTripCard(
          trip: trip,
          status: TripTimelineStatus.datesPending,
          localeName: 'en',
          l10n: l10n,
          isArabic: false,
        ),
        'Dates incomplete',
      );
    });
  });
}
