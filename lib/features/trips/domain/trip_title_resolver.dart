import 'country_database.dart';
import 'trip.dart';

/// Resolves the display title for a [Trip] based on the current locale.
///
/// If [Trip.isCustomTitle] is true the stored [Trip.name] is returned as-is.
/// Otherwise the title is generated dynamically from the stored
/// [Trip.destinationCountryCode] so it always reflects the active language.
class TripTitleResolver {
  TripTitleResolver._();

  /// Returns the display title for [trip] in the given locale.
  ///
  /// Arabic:  "رحلة {arabicCountryName}"
  /// English: "{englishCountryName} Trip"
  static String resolve(Trip trip, bool isArabic) {
    if (trip.isCustomTitle) {
      return trip.name;
    }

    final code = trip.destinationCountryCode;
    if (code != null && code.isNotEmpty) {
      final country = CountryDatabase.findByCode(code);
      if (country != null) {
        final localizedName = country.getLocalizedName(isArabic);
        return isArabic ? 'رحلة $localizedName' : '$localizedName Trip';
      }
    }

    // Fallback for legacy trips or custom-destination trips.
    return trip.name;
  }
}
