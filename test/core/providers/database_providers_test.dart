import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/settings/data/settings_repository.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';

void main() {
  test('database-related providers are wired', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appDatabaseProvider), isA<AppDatabase>());
    expect(container.read(tripRepositoryProvider), isA<TripRepository>());
    expect(container.read(expenseRepositoryProvider), isA<ExpenseRepository>());
    expect(
      container.read(settingsRepositoryProvider),
      isA<SettingsRepository>(),
    );
  });
}
