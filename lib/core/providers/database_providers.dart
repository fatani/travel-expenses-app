import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/expenses/data/expense_repository.dart';
import '../../features/financial_profile/data/user_financial_profile_repository.dart';
import '../../features/settings/data/card_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/trips/data/trip_repository.dart';
import '../database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final appDatabase = AppDatabase();
  ref.onDispose(appDatabase.close);
  return appDatabase;
});

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(appDatabaseProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(ref.watch(appDatabaseProvider));
});

final userFinancialProfileRepositoryProvider =
    Provider<UserFinancialProfileRepository>((ref) {
      return UserFinancialProfileRepository(ref.watch(appDatabaseProvider));
    });
