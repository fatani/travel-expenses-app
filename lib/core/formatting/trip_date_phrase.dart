import 'package:travel_expenses/core/formatting/bidi_format.dart';
import 'package:travel_expenses/core/formatting/date_format_cache.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/domain/trip_timeline_status.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

/// Compact, time-aware trip date phrases for list cards and context strips.
class TripDatePhrase {
  const TripDatePhrase._();

  /// Calm wording when start or end date is missing.
  static String missingDates(AppLocalizations l10n) => l10n.tripsDatesNeedAttention;

  /// Short range such as `12–18 May` or `28 Apr – 3 May 2025`.
  static String compactDateRange({
    required DateTime start,
    required DateTime end,
    required String localeName,
    bool wrapForRtl = false,
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final startLocal = start.toLocal();
    final endLocal = end.toLocal();
    final dayFmt = DateFormatCache.get('d', localeName);
    final monthFmt = DateFormatCache.get('MMM', localeName);
    final yearFmt = DateFormatCache.get('yyyy', localeName);

    String range;
    if (startLocal.year == endLocal.year && startLocal.month == endLocal.month) {
      final month = monthFmt.format(startLocal);
      range = '${dayFmt.format(startLocal)}–${dayFmt.format(endLocal)} $month';
      if (startLocal.year != now.year) {
        range = '$range ${yearFmt.format(startLocal)}';
      }
    } else if (startLocal.year == endLocal.year) {
      range =
          '${dayFmt.format(startLocal)} ${monthFmt.format(startLocal)} – '
          '${dayFmt.format(endLocal)} ${monthFmt.format(endLocal)}';
      if (startLocal.year != now.year) {
        range = '$range ${yearFmt.format(startLocal)}';
      }
    } else {
      final fullFmt = DateFormatCache.get('d MMM yyyy', localeName);
      range = '${fullFmt.format(startLocal)} – ${fullFmt.format(endLocal)}';
    }

    return wrapForRtl ? wrapLtrIsolate(range) : range;
  }

  /// Date line for trip list cards.
  static String forTripCard({
    required Trip trip,
    required TripTimelineStatus status,
    required String localeName,
    required AppLocalizations l10n,
    required bool isArabic,
    DateTime? now,
  }) {
    final start = trip.startDate;
    final end = trip.endDate;
    if (start == null || end == null) {
      return missingDates(l10n);
    }

    return _timelinePhrase(
      status: status,
      start: start,
      end: end,
      localeName: localeName,
      isArabic: isArabic,
      now: now,
      includeUpcomingStartDate: false,
      includeActiveEndHint: false,
    );
  }

  /// Date line for trip details context strip (status chip carries state).
  static String forContextStrip({
    required Trip trip,
    required String localeName,
    required AppLocalizations l10n,
    required bool isArabic,
    DateTime? now,
  }) {
    final start = trip.startDate;
    final end = trip.endDate;
    if (start == null || end == null) {
      return missingDates(l10n);
    }

    final status = resolveTripTimelineStatus(trip, now: now);
    return _timelinePhrase(
      status: status,
      start: start,
      end: end,
      localeName: localeName,
      isArabic: isArabic,
      now: now,
      includeUpcomingStartDate: false,
      includeActiveEndHint: false,
    );
  }

  static String _timelinePhrase({
    required TripTimelineStatus status,
    required DateTime start,
    required DateTime end,
    required String localeName,
    required bool isArabic,
    DateTime? now,
    required bool includeUpcomingStartDate,
    required bool includeActiveEndHint,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final shortFmt = DateFormatCache.get('d MMM', localeName);

    switch (status) {
      case TripTimelineStatus.active:
        final dayOfTrip = today.difference(startDay).inDays + 1;
        final totalDays = endDay.difference(startDay).inDays + 1;
        if (isArabic) {
          var phrase =
              'يوم ${wrapLtrIsolate('$dayOfTrip')} من ${wrapLtrIsolate('$totalDays')}';
          if (includeActiveEndHint) {
            final daysLeft = endDay.difference(today).inDays;
            final suffix = daysLeft == 0
                ? 'ينتهي اليوم'
                : embedLtrInRtl('ينتهي ', shortFmt.format(end));
            phrase = '$phrase · $suffix';
          }
          return phrase;
        }
        var phrase = 'Day $dayOfTrip of $totalDays';
        if (includeActiveEndHint) {
          final daysLeft = endDay.difference(today).inDays;
          final suffix =
              daysLeft == 0 ? 'ends today' : 'ends ${shortFmt.format(end)}';
          phrase = '$phrase · $suffix';
        }
        return phrase;

      case TripTimelineStatus.upcoming:
        final daysUntil = startDay.difference(today).inDays;
        if (isArabic) {
          final datePart = wrapLtrIsolate(shortFmt.format(start));
          if (daysUntil == 0) {
            return includeUpcomingStartDate
                ? 'يبدأ اليوم · $datePart'
                : 'يبدأ اليوم';
          }
          if (daysUntil == 1) {
            return includeUpcomingStartDate
                ? 'يبدأ غدًا · $datePart'
                : 'يبدأ غدًا';
          }
          final core = 'يبدأ خلال ${wrapLtrIsolate('$daysUntil')} أيام';
          return includeUpcomingStartDate ? '$core · $datePart' : core;
        }
        if (daysUntil == 0) {
          return includeUpcomingStartDate
              ? 'Starts today · ${shortFmt.format(start)}'
              : 'Starts today';
        }
        if (daysUntil == 1) {
          return includeUpcomingStartDate
              ? 'Starts tomorrow · ${shortFmt.format(start)}'
              : 'Starts tomorrow';
        }
        final core = 'Starts in $daysUntil days';
        return includeUpcomingStartDate
            ? '$core · ${shortFmt.format(start)}'
            : core;

      case TripTimelineStatus.completed:
      case TripTimelineStatus.datesPending:
        return compactDateRange(
          start: start,
          end: end,
          localeName: localeName,
          wrapForRtl: isArabic,
          referenceNow: current,
        );
    }
  }
}
