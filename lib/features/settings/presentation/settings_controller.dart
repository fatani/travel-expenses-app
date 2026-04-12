import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../domain/app_settings.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.read(settingsRepositoryProvider).loadSettings();
  }

  Future<void> updateLocale(String localeCode) async {
    await _save((current) => current.copyWith(localeCode: localeCode));
  }

  Future<void> _save(
    AppSettings Function(AppSettings current) transform,
  ) async {
    final current =
        state.valueOrNull ??
        await ref.read(settingsRepositoryProvider).loadSettings();

    state = const AsyncLoading();

    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .saveSettings(transform(current));
      state = AsyncData(saved);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
