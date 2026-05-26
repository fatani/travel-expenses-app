import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/design_system/calm_snackbar.dart';
import '../../../shared/widgets/calm_load_error_panel.dart';
import '../../../core/extensions/rtl_extension.dart';
import '../../../core/formatting/bidi_format.dart';
import '../../../core/formatting/trip_date_phrase.dart';
import '../../../core/theme/rtl_typography.dart';
import '../../expenses/presentation/trip_details_screen.dart';
import '../../global_reports/presentation/global_reports_screen.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/trip.dart';
import '../domain/trip_timeline_status.dart';
import '../domain/trip_title_resolver.dart';
import 'trip_controller.dart';
import 'trips_empty_state_screen.dart';
import 'trip_form_screen.dart';

class TripsListScreen extends ConsumerStatefulWidget {
  const TripsListScreen({super.key});

  @override
  ConsumerState<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends ConsumerState<TripsListScreen> {
  static const String _hasEverHadTripsPrefKey =
      'trips_has_ever_had_at_least_one_trip';

  bool? _hasEverHadTrips;
  final Set<String> _deletingTripIds = <String>{};
  bool _isOpeningTripForm = false;
  final Set<String> _openingTripDetailIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadTripsHistoryFlag();
  }

  Future<void> _loadTripsHistoryFlag() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    setState(() {
      _hasEverHadTrips = prefs.getBool(_hasEverHadTripsPrefKey) ?? false;
    });
  }

  Future<void> _markHasEverHadTrips() async {
    if (_hasEverHadTrips == true) {
      return;
    }

    setState(() {
      _hasEverHadTrips = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasEverHadTripsPrefKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tripsState = ref.watch(tripsControllerProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final currentLocaleCode = settingsState.valueOrNull?.localeCode ?? 'ar';
    final isArabic = context.isRTL;
    final showOnlyLanguageToggle = tripsState.maybeWhen(
      data: (trips) => trips.isEmpty,
      orElse: () => false,
    );
    final showAddTripFab = tripsState.maybeWhen(
      data: (trips) => trips.isNotEmpty,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: showOnlyLanguageToggle
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: null,
              actions: [
                _SubtleLanguageToggle(
                  isLoading: settingsState.isLoading,
                  onTap: () => _toggleLanguage(context, ref, currentLocaleCode),
                ),
                const SizedBox(width: 12),
              ],
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                l10n.tripsMyTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: RtlTypography.titleWeight(isArabic),
                  color: const Color(0xFF0F172A),
                  height: RtlTypography.titleLineHeight(isArabic),
                ),
              ),
              actions: [
                Tooltip(
                  message: l10n.settingsTitle,
                  child: IconButton(
                    tooltip: l10n.settingsTitle,
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ),
                _TripsListOverflowMenu(
                  isLoading: settingsState.isLoading,
                  onOpenGlobalReports: () => _openGlobalReports(context),
                  onToggleLanguage: () =>
                      _toggleLanguage(context, ref, currentLocaleCode),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: tripsState.when(
        data: (trips) {
          if (trips.isNotEmpty && _hasEverHadTrips != true) {
            unawaited(_markHasEverHadTrips());
          }

          if (trips.isEmpty) {
            if (_hasEverHadTrips == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final isArabic =
                Localizations.localeOf(context).languageCode.toLowerCase() ==
                'ar';

            return TripsEmptyStateScreen(
              isArabic: isArabic,
              isFirstTime: !_hasEverHadTrips!,
              onStartTrip: () => _openTripForm(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(tripsControllerProvider.notifier).reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
              itemCount: trips.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
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
          final staleTrips = tripsState.valueOrNull;
          if (staleTrips != null && staleTrips.isNotEmpty) {
            return Column(
              children: [
                StaleLoadErrorBanner(
                  message: l10n.tripsLoadError,
                  retryLabel: l10n.commonTryAgain,
                  onRetry: () =>
                      ref.read(tripsControllerProvider.notifier).reload(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        ref.read(tripsControllerProvider.notifier).reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                      itemCount: staleTrips.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final trip = staleTrips[index];
                        return _TripCard(
                          trip: trip,
                          onTap: () => _openTripDetails(context, trip),
                          onEdit: () => _openTripForm(context, trip: trip),
                          onDelete: () => _confirmDelete(context, ref, trip),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          }

          return CalmLoadErrorPanel(
            title: l10n.tripsLoadError,
            retryLabel: l10n.commonTryAgain,
            onRetry: () =>
                ref.read(tripsControllerProvider.notifier).reload(),
          );
        },
      ),
      floatingActionButton: showAddTripFab
          ? _GradientAddTripButton(
              isArabic: isArabic,
              onTap: () => _openTripForm(context),
            )
          : null,
    );
  }

  Future<void> _openTripForm(BuildContext context, {Trip? trip}) async {
    if (_isOpeningTripForm) {
      return;
    }
    _isOpeningTripForm = true;

    try {
      final createdTrip = await Navigator.of(context).push<Trip?>(
        MaterialPageRoute<Trip?>(builder: (_) => TripFormScreen(trip: trip)),
      );

      if (!context.mounted || trip != null || createdTrip == null) {
        return;
      }

      await _openTripDetails(context, createdTrip);
    } finally {
      _isOpeningTripForm = false;
    }
  }

  Future<void> _openTripDetails(BuildContext context, Trip trip) async {
    if (_openingTripDetailIds.contains(trip.id)) {
      return;
    }
    _openingTripDetailIds.add(trip.id);

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => TripDetailsScreen(trip: trip)),
      );
    } finally {
      _openingTripDetailIds.remove(trip.id);
    }
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

      CalmSnackBar.showMessage(
        context,
        message: AppLocalizations.of(context)!.settingsLanguageSaveError,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    if (_deletingTripIds.contains(trip.id)) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final tripName = TripTitleResolver.resolve(trip, isArabic);
    var confirmTapped = false;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        final dialogIsArabic =
            Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
        final title = dialogL10n.tripsDeleteDialogTitle;
        final message = dialogL10n.tripsDeleteDialogMessage(tripName);
        final cancelLabel = dialogL10n.commonCancel;
        final deleteLabel = dialogL10n.tripsDeleteTripAction;

        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFBE5561),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: RtlTypography.titleWeight(dialogIsArabic),
                      height: RtlTypography.titleLineHeight(dialogIsArabic),
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment:
                        isArabic ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      dialogL10n.tripsDeleteTripToBeDeleted,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      TripTitleResolver.resolve(trip, isArabic),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        if (confirmTapped) {
                          return;
                        }
                        confirmTapped = true;
                        Navigator.of(context).pop(true);
                      },
                      child: Ink(
                        height: 52,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD8868D), Color(0xFFC36D77)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC36D77).withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            deleteLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight:
                                  RtlTypography.sectionWeight(dialogIsArabic),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    if (_deletingTripIds.contains(trip.id)) {
      return;
    }

    _deletingTripIds.add(trip.id);
    try {
      await ref.read(tripsControllerProvider.notifier).deleteTrip(trip.id);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      CalmSnackBar.showMessage(
        context,
        message: l10n.tripsDeleteError,
      );
    } finally {
      _deletingTripIds.remove(trip.id);
    }
  }
}

enum _TripCardAction { edit, delete }

enum _TripsListOverflowAction { globalReports, language }

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
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final status = resolveTripTimelineStatus(trip);
    final hasDates = status != TripTimelineStatus.datesPending;
    final hasCurrency = trip.baseCurrency.trim().isNotEmpty;
    final title = TripTitleResolver.resolve(trip, isArabic);

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 4, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: RtlTypography.titleWeight(isArabic),
                                color: const Color(0xFF0F172A),
                                height: RtlTypography.titleLineHeight(isArabic),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            isArabic: isArabic,
                            status: status,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TripDatePhrase.forTripCard(
                          trip: trip,
                          status: status,
                          localeName: localeName,
                          l10n: l10n,
                          isArabic: isArabic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: RtlTypography.bodyLineHeight(isArabic),
                          color: hasDates
                              ? const Color(0xFF64748B)
                              : const Color(0xFFB45309),
                          fontWeight: hasDates
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                      if (hasCurrency) ...[
                        const SizedBox(height: 2),
                        LtrText(
                          data: trip.baseCurrency.trim().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_TripCardAction>(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: const Color(0xFF64748B).withValues(alpha: 0.55),
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _TripCardAction.edit:
                        onEdit();
                      case _TripCardAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _TripCardAction.edit,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 10),
                          Text(l10n.tripsEditTooltip),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _TripCardAction.delete,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.error.withValues(
                                  alpha: 0.85,
                                ),
                          ),
                          const SizedBox(width: 10),
                          Text(l10n.tripsDeleteTooltip),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isArabic, required this.status});

  final bool isArabic;
  final TripTimelineStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusUi = switch (status) {
      TripTimelineStatus.datesPending => (
        label: l10n.tripTimelineNoDates,
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFFB45309),
        fontWeight: FontWeight.w600,
      ),
      TripTimelineStatus.upcoming => (
        label: l10n.tripTimelineUpcoming,
        background: const Color(0xFFDBEAFE),
        foreground: const Color(0xFF1D4ED8),
        fontWeight: FontWeight.w600,
      ),
      TripTimelineStatus.active => (
        label: l10n.tripTimelineTraveling,
        background: const Color(0xFFDCFCE7),
        foreground: const Color(0xFF166534),
        fontWeight: FontWeight.w600,
      ),
      TripTimelineStatus.completed => (
        label: l10n.tripTimelineCompleted,
        background: const Color(0xFFF1F5F9),
        foreground: const Color(0xFF94A3B8),
        fontWeight: FontWeight.w500,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isArabic ? 9 : 8,
        vertical: isArabic ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: statusUi.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusUi.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: statusUi.fontWeight,
          color: statusUi.foreground,
          height: RtlTypography.chipLineHeight(isArabic),
        ),
      ),
    );
  }
}

class _TripsListOverflowMenu extends StatelessWidget {
  const _TripsListOverflowMenu({
    required this.isLoading,
    required this.onOpenGlobalReports,
    required this.onToggleLanguage,
  });

  final bool isLoading;
  final VoidCallback onOpenGlobalReports;
  final VoidCallback onToggleLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<_TripsListOverflowAction>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) {
        switch (action) {
          case _TripsListOverflowAction.globalReports:
            onOpenGlobalReports();
          case _TripsListOverflowAction.language:
            if (!isLoading) {
              onToggleLanguage();
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _TripsListOverflowAction.globalReports,
          child: Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 18,
                color: Color(0xFF475569),
              ),
              const SizedBox(width: 10),
              Text(l10n.globalReportsTooltip),
            ],
          ),
        ),
        PopupMenuItem(
          value: _TripsListOverflowAction.language,
          enabled: !isLoading,
          child: Row(
            children: [
              const Icon(
                Icons.translate_rounded,
                size: 18,
                color: Color(0xFF475569),
              ),
              const SizedBox(width: 10),
              Text(l10n.settingsToggleLanguageTooltip),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientAddTripButton extends StatelessWidget {
  const _GradientAddTripButton({required this.isArabic, required this.onTap});

  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.tripsNewTrip,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtleLanguageToggle extends StatelessWidget {
  const _SubtleLanguageToggle({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isLoading ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF64748B),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('AR | EN'),
    );
  }
}
