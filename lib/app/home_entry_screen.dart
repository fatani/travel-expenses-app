import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

import '../features/expenses/presentation/trip_details_screen.dart';
import '../features/financial_profile/presentation/financial_profile_onboarding_screen.dart';
import '../features/financial_profile/presentation/user_financial_profile_controller.dart';
import '../features/trips/domain/trip_timeline_status.dart';
import '../features/trips/presentation/trip_controller.dart';
import '../features/trips/presentation/trips_list_screen.dart';

class HomeEntryScreen extends ConsumerStatefulWidget {
  const HomeEntryScreen({super.key});

  @override
  ConsumerState<HomeEntryScreen> createState() => _HomeEntryScreenState();
}

class _HomeEntryScreenState extends ConsumerState<HomeEntryScreen> {
  bool _didAutoOpenSingleActiveTrip = false;

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userFinancialProfileControllerProvider);
    final tripsState = ref.watch(tripsControllerProvider);

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

        tripsState.whenData((trips) {
          if (_didAutoOpenSingleActiveTrip || !mounted) {
            return;
          }

          final activeTrips = trips
              .where((trip) => resolveTripTimelineStatus(trip) == TripTimelineStatus.active)
              .toList(growable: false);
          if (activeTrips.length != 1) {
            return;
          }

          _didAutoOpenSingleActiveTrip = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TripDetailsScreen(trip: activeTrips.first),
              ),
            );
          });
        });

        return const TripsListScreen();
      },
    );
  }
}
