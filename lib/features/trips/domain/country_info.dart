/// Country information for destination selection in trip creation.
class CountryInfo {
  const CountryInfo({
    required this.countryCode,
    required this.englishName,
    required this.arabicName,
    required this.currencyCode,
    required this.currencyName,
    required this.flagEmoji,
    this.searchTerms = const <String>[],
    this.timezoneId,
  });

  /// ISO 3166-1 alpha-2 country code (e.g., "US", "SA")
  final String countryCode;

  /// English country name (e.g., "Thailand")
  final String englishName;

  /// Arabic country name (e.g., "تايلند")
  final String arabicName;

  /// ISO 4217 currency code (e.g., "THB", "SAR")
  final String currencyCode;

  /// Currency display name in English.
  final String currencyName;

  /// Flag emoji for visual representation
  final String flagEmoji;

  /// Extra aliases and search tokens (Arabic/English abbreviations and variants).
  final List<String> searchTerms;

  /// Foundation field for future phases (rates, wallets, analytics), not used yet.
  final String? timezoneId;

  /// Returns the appropriate name based on language
  String getLocalizedName(bool isArabic) => isArabic ? arabicName : englishName;

  /// Check if this country matches a search query
  bool matchesSearch(String query) {
    if (query.isEmpty) {
      return true;
    }

    final lowerQuery = query.toLowerCase();
    return englishName.toLowerCase().contains(lowerQuery) ||
        arabicName.contains(query) ||
        countryCode.toLowerCase().contains(lowerQuery) ||
        currencyCode.toLowerCase().contains(lowerQuery) ||
        currencyName.toLowerCase().contains(lowerQuery) ||
        searchTerms.any((term) => term.toLowerCase().contains(lowerQuery));
  }

  @override
  String toString() => '$englishName ($countryCode)';
}
