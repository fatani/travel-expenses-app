import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

import '../features/financial_profile/presentation/financial_profile_onboarding_screen.dart';
import '../features/financial_profile/presentation/user_financial_profile_controller.dart';
import '../features/trips/presentation/trips_list_screen.dart';

class HomeEntryScreen extends ConsumerWidget {
  const HomeEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userFinancialProfileControllerProvider);

    return profileState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40),
                const SizedBox(height: 12),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(userFinancialProfileControllerProvider);
                  },
                  child: Text(context.l10n.commonTryAgain),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (profile) {
        if (profile == null || !profile.onboardingCompleted) {
          return const FinancialProfileOnboardingScreen();
        }

        return const TripsListScreen();
      },
    );
  }
}
