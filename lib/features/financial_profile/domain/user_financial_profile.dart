class UserFinancialProfile {
  const UserFinancialProfile({
    required this.homeCountryCode,
    required this.homeCountryEnglish,
    required this.homeCountryArabic,
    required this.homeCurrencyCode,
    required this.onboardingCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int singletonId = 1;

  factory UserFinancialProfile.fromMap(Map<String, Object?> map) {
    return UserFinancialProfile(
      homeCountryCode: (map['home_country_code'] as String).trim().toUpperCase(),
      homeCountryEnglish: (map['home_country_english'] as String).trim(),
      homeCountryArabic: (map['home_country_arabic'] as String).trim(),
      homeCurrencyCode: (map['home_currency_code'] as String).trim().toUpperCase(),
      onboardingCompleted: ((map['onboarding_completed'] as num?)?.toInt() ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  final String homeCountryCode;
  final String homeCountryEnglish;
  final String homeCountryArabic;
  final String homeCurrencyCode;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserFinancialProfile copyWith({
    String? homeCountryCode,
    String? homeCountryEnglish,
    String? homeCountryArabic,
    String? homeCurrencyCode,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserFinancialProfile(
      homeCountryCode: homeCountryCode ?? this.homeCountryCode,
      homeCountryEnglish: homeCountryEnglish ?? this.homeCountryEnglish,
      homeCountryArabic: homeCountryArabic ?? this.homeCountryArabic,
      homeCurrencyCode: homeCurrencyCode ?? this.homeCurrencyCode,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': singletonId,
      'home_country_code': homeCountryCode,
      'home_country_english': homeCountryEnglish,
      'home_country_arabic': homeCountryArabic,
      'home_currency_code': homeCurrencyCode,
      'onboarding_completed': onboardingCompleted ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
