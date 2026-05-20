import 'trip.dart';

enum TripTimelineStatus { datesPending, upcoming, active, completed }

TripTimelineStatus resolveTripTimelineStatus(Trip trip, {DateTime? now}) {
  final startDate = trip.startDate;
  final endDate = trip.endDate;
  if (startDate == null || endDate == null) {
    return TripTimelineStatus.datesPending;
  }

  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final start = DateTime(
    startDate.toLocal().year,
    startDate.toLocal().month,
    startDate.toLocal().day,
  );
  final end = DateTime(
    endDate.toLocal().year,
    endDate.toLocal().month,
    endDate.toLocal().day,
  );

  if (today.isBefore(start)) {
    return TripTimelineStatus.upcoming;
  }
  if (today.isAfter(end)) {
    return TripTimelineStatus.completed;
  }
  return TripTimelineStatus.active;
}
