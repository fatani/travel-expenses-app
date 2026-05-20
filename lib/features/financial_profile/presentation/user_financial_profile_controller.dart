import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../trips/domain/country_info.dart';
import '../domain/user_financial_profile.dart';

final userFinancialProfileControllerProvider =
    AsyncNotifierProvider<UserFinancialProfileController, UserFinancialProfile?>(
      UserFinancialProfileController.new,
    );

class UserFinancialProfileController extends AsyncNotifier<UserFinancialProfile?> {
  @override
  Future<UserFinancialProfile?> build() {
    return ref.read(userFinancialProfileRepositoryProvider).loadProfile();
  }

  Future<void> setHomeCountry(CountryInfo country) async {
    final now = DateTime.now().toUtc();
    final current =
        state.valueOrNull ??
        await ref.read(userFinancialProfileRepositoryProvider).loadProfile();

    final profile = UserFinancialProfile(
      homeCountryCode: country.countryCode,
      homeCountryEnglish: country.englishName,
      homeCountryArabic: country.arabicName,
      homeCurrencyCode: country.currencyCode,
      onboardingCompleted: true,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );

    state = const AsyncLoading();

    try {
      final saved = await ref
          .read(userFinancialProfileRepositoryProvider)
          .saveProfile(profile);
      state = AsyncData(saved);

      final settings = ref.read(settingsControllerProvider).valueOrNull;
      if (settings != null) {
        await ref
            .read(settingsControllerProvider.notifier)
            .updateCurrency(saved.homeCurrencyCode);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
