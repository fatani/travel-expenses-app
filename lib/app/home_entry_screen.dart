import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

import '../features/expenses/presentation/trip_details_screen.dart';
import '../features/financial_profile/presentation/financial_profile_onboarding_screen.dart';
import '../features/financial_profile/presentation/user_financial_profile_controller.dart';
import '../features/trips/domain/trip_timeline_status.dart';
import '../features/trips/presentation/trip_controller.dart';
import '../features/trips/presentation/trips_list_screen.dart';
import '../shared/widgets/calm_load_error_panel.dart';

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
        body: CalmLoadErrorPanel(
          title: context.l10n.financialProfileLoadError,
          retryLabel: context.l10n.commonTryAgain,
          onRetry: () {
            ref.invalidate(userFinancialProfileControllerProvider);
          },
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
