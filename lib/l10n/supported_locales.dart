/// Supported locale codes in the app.
/// Used throughout the app to avoid hardcoding 'ar' and 'en' strings.
class SupportedLocales {
  const SupportedLocales._();

  /// Arabic locale code
  static const String arabic = 'ar';

  /// English locale code
  static const String english = 'en';

  /// List of all supported locale codes
  static const List<String> values = [arabic, english];
}
