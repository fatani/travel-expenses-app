import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/extensions/rtl_extension.dart';
import '../../expenses/presentation/trip_details_screen.dart';
import '../../global_reports/presentation/global_reports_screen.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/trip.dart';
import '../domain/trip_title_resolver.dart';
import 'trip_controller.dart';
import 'trips_empty_state_screen.dart';
import 'trip_form_screen.dart';

class TripsListScreen extends ConsumerWidget {
  const TripsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                isArabic ? 'رحلاتي' : 'Trips',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
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
                const SizedBox(width: 4),
                _SubtleLanguageToggle(
                  isLoading: settingsState.isLoading,
                  onTap: () => _toggleLanguage(context, ref, currentLocaleCode),
                ),
                const SizedBox(width: 12),
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

          return Stack(
            children: [
              const Positioned.fill(child: _TripsSoftBackground()),
              RefreshIndicator(
                onRefresh: () =>
                    ref.read(tripsControllerProvider.notifier).reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                  itemCount: trips.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
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
              ),
            ],
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
          ? _GradientAddTripButton(
              isArabic: isArabic,
              onTap: () => _openTripForm(context),
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
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        final title = isArabic ? 'حذف الرحلة؟' : 'Delete trip?';
        final message = isArabic
            ? 'سيتم حذف الرحلة وكل مصاريفها المرتبطة نهائيًا.'
            : 'This will permanently remove the trip and its linked expenses.';
        final cancelLabel = isArabic ? 'إلغاء' : 'Cancel';
        final deleteLabel = isArabic ? 'حذف الرحلة' : 'Delete trip';

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
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      TripTitleResolver.resolve(trip, isArabic),
                      textAlign: TextAlign.center,
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
                      onTap: () => Navigator.of(context).pop(true),
                      child: Ink(
                        height: 52,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(
                                alpha: 0.26,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            deleteLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final hasDates = trip.startDate != null && trip.endDate != null;
    final hasCurrency = trip.baseCurrency.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFFE8ECF5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        color: const Color(0xFFF6F8FF),
                        width: 56,
                        height: 56,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/travel.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.flight_takeoff_rounded,
                              color: Color(0xFF5B7CFF),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TripTitleResolver.resolve(trip, isArabic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (trip.destination.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              trip.destination,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _StatusChip(
                      isArabic: isArabic,
                      hasDates: hasDates,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.event_note_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatDateRange(trip, localeName, l10n, isArabic),
                        style: TextStyle(
                          color: hasDates
                              ? const Color(0xFF334155)
                              : const Color(0xFFB45309),
                          fontWeight: hasDates
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasCurrency) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.currency_exchange_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trip.baseCurrency,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (trip.budget != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment:
                        isArabic ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      l10n.tripsBudgetLabel(_formatBudget(trip)),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionIconButton(
                      tooltip: l10n.tripsEditTooltip,
                      icon: Icons.edit_outlined,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 8),
                    _ActionIconButton(
                      tooltip: l10n.tripsDeleteTooltip,
                      icon: Icons.delete_outline_rounded,
                      onTap: onDelete,
                      isDanger: true,
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

  String _formatDateRange(
    Trip trip,
    String localeName,
    AppLocalizations l10n,
    bool isArabic,
  ) {
    final start = trip.startDate;
    final end = trip.endDate;

    if (start == null || end == null) {
      return isArabic ? 'التواريخ تحتاج تحديد' : 'Dates need attention';
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isArabic, required this.hasDates});

  final bool isArabic;
  final bool hasDates;

  @override
  Widget build(BuildContext context) {
    final bgColor = hasDates
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEF3C7);
    final fgColor = hasDates
        ? const Color(0xFF166534)
        : const Color(0xFFB45309);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hasDates ? (isArabic ? 'جاهزة' : 'Ready') : (isArabic ? 'ناقص' : 'Needs Date'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fgColor,
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final base = isDanger ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: base.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: base),
          ),
        ),
      ),
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
                color: const Color(0xFF7C3AED).withValues(alpha: 0.26),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'رحلة جديدة' : 'New Trip',
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

class _TripsSoftBackground extends StatelessWidget {
  const _TripsSoftBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -40,
          right: -40,
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
