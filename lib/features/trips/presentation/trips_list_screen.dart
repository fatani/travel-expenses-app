import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../expenses/presentation/trip_details_screen.dart';
import '../../global_reports/presentation/global_reports_screen.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/trip.dart';
import 'trip_controller.dart';
import 'trips_empty_state_screen.dart';
import 'trip_form_screen.dart';
import '../../../shared/widgets/language_toggle_button.dart';

class TripsListScreen extends ConsumerWidget {
  const TripsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tripsState = ref.watch(tripsControllerProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final currentLocaleCode = settingsState.valueOrNull?.localeCode ?? 'ar';
    final showOnlyLanguageToggle = tripsState.maybeWhen(
      data: (trips) => trips.isEmpty,
      orElse: () => false,
    );
    final showAddTripFab = tripsState.maybeWhen(
      data: (trips) => trips.isNotEmpty,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripsTitle),
        actions: [
          if (!showOnlyLanguageToggle) ...[
            IconButton(
              tooltip: l10n.globalReportsTooltip,
              onPressed: () => _openGlobalReports(context),
              icon: const Icon(Icons.analytics_outlined),
            ),
            IconButton(
              tooltip: l10n.settingsLanguageTooltip,
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 4),
            LanguageToggleButton(
              currentLocaleCode: currentLocaleCode,
              isLoading: settingsState.isLoading,
              onToggle: () => _toggleLanguage(context, ref, currentLocaleCode),
            ),
            const SizedBox(width: 12),
          ],
          if (showOnlyLanguageToggle) ...[
            TextButton(
              onPressed: settingsState.isLoading
                  ? null
                  : () => _toggleLanguage(context, ref, currentLocaleCode),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('AR | EN'),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: tripsState.when(
        data: (trips) {
          if (trips.isEmpty) {
            final isArabic =
                Localizations.localeOf(context).languageCode.toLowerCase() ==
                'ar';

            return TripsEmptyStateScreen(
              isArabic: isArabic,
              onStartTrip: () => _openTripForm(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(tripsControllerProvider.notifier).reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trip = trips[index];

                return _TripCard(
                  trip: trip,
                  onTap: () => _openTripDetails(context, trip),
                  onEdit: () => _openTripForm(context, trip: trip),
                  onDelete: () => _confirmDelete(context, ref, trip),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    l10n.tripsLoadError,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.read(tripsControllerProvider.notifier).reload(),
                    child: Text(l10n.commonTryAgain),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: showAddTripFab
          ? FloatingActionButton.extended(
              onPressed: () => _openTripForm(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.tripsAddButton),
            )
          : null,
    );
  }

  Future<void> _openTripForm(BuildContext context, {Trip? trip}) async {
    final createdTrip = await Navigator.of(context).push<Trip?>(
      MaterialPageRoute<Trip?>(builder: (_) => TripFormScreen(trip: trip)),
    );

    if (!context.mounted || trip != null || createdTrip == null) {
      return;
    }

    await _openTripDetails(context, createdTrip);
  }

  Future<void> _openTripDetails(BuildContext context, Trip trip) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => TripDetailsScreen(trip: trip)),
    );
  }

  Future<void> _openGlobalReports(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const GlobalReportsScreen()),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _toggleLanguage(
    BuildContext context,
    WidgetRef ref,
    String currentLocaleCode,
  ) async {
    final nextLocaleCode = currentLocaleCode == 'ar' ? 'en' : 'ar';

    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .updateLocale(nextLocaleCode);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.tripsDeleteDialogTitle),
          content: Text(l10n.tripsDeleteDialogMessage(trip.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(tripsControllerProvider.notifier).deleteTrip(trip.id);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.tripsDeleteError('$error'))));
    }
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(trip.name, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip.destination),
              const SizedBox(height: 6),
              Text(_formatDateRange(trip, localeName, l10n)),
              if (trip.budget != null) ...[
                const SizedBox(height: 6),
                Text(l10n.tripsBudgetLabel(_formatBudget(trip))),
              ],
            ],
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: l10n.tripsEditTooltip,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: l10n.tripsDeleteTooltip,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDateRange(Trip trip, String localeName, AppLocalizations l10n) {
    final start = trip.startDate;
    final end = trip.endDate;

    if (start == null || end == null) {
      return l10n.tripsDatesNeedAttention;
    }

    final formatter = DateFormat('dd MMM yyyy', localeName);
    return '${formatter.format(start)} - ${formatter.format(end)}';
  }

  String _formatBudget(Trip trip) {
    final formatter = NumberFormat.currency(
      name: trip.baseCurrency,
      symbol: '${trip.baseCurrency} ',
      decimalDigits: 2,
    );

    return formatter.format(trip.budget);
  }
}
