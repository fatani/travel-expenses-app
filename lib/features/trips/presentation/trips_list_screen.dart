import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../expenses/presentation/trip_details_screen.dart';
import '../../global_reports/presentation/global_reports_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/trip.dart';
import 'trip_controller.dart';
import 'trip_form_screen.dart';

class TripsListScreen extends ConsumerWidget {
  const TripsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tripsState = ref.watch(tripsControllerProvider);
    final showAddTripFab = tripsState.maybeWhen(
      data: (trips) => trips.isNotEmpty,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripsTitle),
        actions: [
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
        ],
      ),
      body: tripsState.when(
        data: (trips) {
          if (trips.isEmpty) {
            return _EmptyTripsState(onAddTrip: () => _openTripForm(context));
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => TripFormScreen(trip: trip)),
    );
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

class _EmptyTripsState extends StatelessWidget {
  const _EmptyTripsState({required this.onAddTrip});

  final VoidCallback onAddTrip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.luggage_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.tripsEmptyTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tripsEmptyMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAddTrip,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.tripsAddButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
