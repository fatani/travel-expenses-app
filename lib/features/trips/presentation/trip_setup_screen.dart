import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/design_system/app_confirmation_dialog.dart';
import '../../../core/design_system/calm_snackbar.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../cash_wallet/domain/cash_transaction.dart';
import '../../financial_profile/presentation/user_financial_profile_controller.dart';
import '../../settings/domain/card_display_helper.dart';
import '../../settings/domain/card_profile.dart';
import '../../settings/presentation/add_card_screen.dart';
import '../../settings/presentation/cards_provider.dart';
import '../domain/country_info.dart';
import '../domain/trip.dart';
import 'trip_controller.dart';
import 'widgets/trip_form_backgrounds.dart';

const List<String> _kSetupSupportedCurrencies = [
  'SAR - Saudi Riyal',
  'USD - US Dollar',
  'EUR - Euro',
  'GBP - British Pound',
  'AED - UAE Dirham',
  'KWD - Kuwaiti Dinar',
  'QAR - Qatari Riyal',
  'BHD - Bahraini Dinar',
  'OMR - Omani Rial',
  'TRY - Turkish Lira',
  'CNY - Chinese Yuan',
  'JPY - Japanese Yen',
  'THB - Thai Baht',
  'VND - Vietnamese Dong',
  'IDR - Indonesian Rupiah',
  'MYR - Malaysian Ringgit',
];

class TripSetupScreen extends ConsumerStatefulWidget {
  const TripSetupScreen({
    super.key,
    required this.selectedDestination,
    this.customTripTitle = '',
  });

  final CountryInfo selectedDestination;
  final String customTripTitle;

  @override
  ConsumerState<TripSetupScreen> createState() => _TripSetupScreenState();
}

class _TripSetupScreenState extends ConsumerState<TripSetupScreen> {
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  final List<_CashEntryRow> _cashRows = [];

  @override
  void initState() {
    super.initState();
    _cashRows.add(
      _CashEntryRow(
        currencyCode: widget.selectedDestination.currencyCode,
      ),
    );
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    for (final row in _cashRows) {
      row.dispose();
    }
    super.dispose();
  }

  bool get _isArabic {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  }

  bool get _hasInvalidDateRange {
    return _startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final destination = widget.selectedDestination;
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final cardsAsync = ref.watch(cardsProvider);
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final isCompact = MediaQuery.sizeOf(context).width < 400;
    final horizontalPadding = isCompact ? 16.0 : 20.0;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: SoftGradientBackground()),
              Column(
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      horizontalPadding - 8,
                      4,
                      horizontalPadding - 8,
                      0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Text(
                            l10n.tripSetupTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        horizontalPadding,
                        4,
                        horizontalPadding,
                        16 + viewInsetsBottom,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${destination.flagEmoji} ${destination.getLocalizedName(_isArabic)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.tripSetupSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _SetupSectionCard(
                            title: l10n.tripSetupDatesTitle,
                            hint: l10n.tripSetupDatesHint,
                            child: Column(
                              children: [
                                _DateField(
                                  controller: _startDateController,
                                  label: l10n.tripFormStartDateLabel,
                                  onTap: _isSubmitting
                                      ? null
                                      : () => _selectDate(isStartDate: true),
                                ),
                                const SizedBox(height: 8),
                                _DateField(
                                  controller: _endDateController,
                                  label: l10n.tripFormEndDateLabel,
                                  onTap: _isSubmitting
                                      ? null
                                      : () => _selectDate(isStartDate: false),
                                ),
                                if (_hasInvalidDateRange) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    l10n.tripFormEndDateAfterStart,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SetupSectionCard(
                            title: l10n.tripSetupCashTitle,
                            hint: l10n.tripSetupCashHint,
                            child: Column(
                              children: [
                                for (var i = 0; i < _cashRows.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  _CashRowFields(
                                    row: _cashRows[i],
                                    enabled: !_isSubmitting,
                                    amountLabel: l10n.tripSetupAmountLabel,
                                    onCurrencyTap: () =>
                                        _pickCurrencyForRow(_cashRows[i]),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton.icon(
                                    onPressed: _isSubmitting
                                        ? null
                                        : _addCashRow,
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsetsDirectional.zero,
                                    ),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 20,
                                    ),
                                    label: Text(l10n.tripSetupAddCurrency),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SetupSectionCard(
                            title: l10n.tripSetupCardsTitle,
                            hint: l10n.tripSetupCardsHint,
                            child: cardsAsync.when(
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              error: (error, _) => Text(
                                l10n.tripSetupCardsError,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              data: (cards) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (cards.isEmpty)
                                    Text(
                                      l10n.tripSetupCardsEmpty,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        height: 1.35,
                                      ),
                                    )
                                  else
                                    ...cards.map(
                                      (card) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: _CardSummaryTile(card: card),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _isSubmitting ? null : _openAddCard,
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(
                                      Icons.add_card_rounded,
                                      size: 20,
                                    ),
                                    label: Text(l10n.tripSetupAddCard),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    padding: EdgeInsetsDirectional.fromSTEB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      16 + viewInsetsBottom,
                    ),
                    child: Column(
                      children: [
                        _SetupGradientButton(
                          label: l10n.tripFormSaveCreate,
                          onTap: _isSubmitting || _hasInvalidDateRange
                              ? null
                              : () => _createTrip(skipOptionalData: false),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _createTrip(skipOptionalData: true),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            l10n.tripSetupCreateNow,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        Text(
                          l10n.tripSetupCreateNowHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addCashRow() {
    setState(() {
      _cashRows.add(_CashEntryRow(currencyCode: 'USD'));
    });
  }

  Future<void> _pickCurrencyForRow(_CashEntryRow row) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SetupCurrencyPickerSheet(
        currentValue: row.currencyCode,
        isArabic: _isArabic,
        searchHint: AppLocalizations.of(context)!.tripSetupSearchCurrency,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        row.currencyCode = _extractCurrencyCode(selected);
      });
    }
  }

  Future<void> _openAddCard() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AddCardScreen()),
    );
    if (mounted) {
      ref.invalidate(cardsProvider);
    }
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final initialDate = isStartDate
        ? (_startDate ?? _endDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(initialDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      useRootNavigator: true,
      barrierColor: const Color(0x99000000),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: const Color(0xFF7C3AED),
              onPrimary: Colors.white,
              onSurface: const Color(0xFF0F172A),
              surface: Colors.white,
            ),
            dialogTheme: theme.dialogTheme.copyWith(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            datePickerTheme: theme.datePickerTheme.copyWith(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              headerBackgroundColor: const Color(0xFF7C3AED),
              headerForegroundColor: Colors.white,
            ),
          ),
          child: Directionality(
            textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    final chosenDate = selectedDate;
    setState(() {
      if (isStartDate) {
        _startDate = DateUtils.dateOnly(chosenDate);
      } else {
        _endDate = DateUtils.dateOnly(chosenDate);
      }
      _syncDateFields();
    });
  }

  void _syncDateFields() {
    _startDateController.text =
        _startDate == null ? '' : _formatDate(_startDate!);
    _endDateController.text = _endDate == null ? '' : _formatDate(_endDate!);
  }

  String _formatDate(DateTime date) {
    final localeCode = _isArabic ? 'ar' : 'en';
    final pattern = _isArabic ? 'd MMMM y' : 'd MMM y';
    return DateFormat(pattern, localeCode).format(date);
  }

  String _dateRangeSeparator() {
    return _isArabic ? ' ← ' : ' → ';
  }

  Future<void> _createTrip({required bool skipOptionalData}) async {
    if (_isSubmitting) {
      return;
    }

    if (!skipOptionalData && _hasInvalidDateRange) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final destination = widget.selectedDestination;
      final customTitle = widget.customTripTitle.trim();
      final resolvedName = customTitle.isEmpty
          ? _buildGeneratedTripTitle(destination: destination)
          : customTitle;
      final isCustomTitle = customTitle.isNotEmpty;
      final profile =
          ref.read(userFinancialProfileControllerProvider).valueOrNull;
      final baseCurrency = destination.currencyCode;
      final homeCurrencySnapshot =
          profile?.homeCurrencyCode.trim().toUpperCase().isNotEmpty == true
              ? profile!.homeCurrencyCode.trim().toUpperCase()
              : baseCurrency;

      final startDate = skipOptionalData ? null : _startDate;
      final endDate = skipOptionalData ? null : _endDate;

      if (!skipOptionalData &&
          startDate != null &&
          endDate != null &&
          _startDate!.isAfter(_endDate!)) {
        return;
      }

      final overlaps = await _findDateOverlaps(
        startDate: startDate,
        endDate: endDate,
      );
      if (!mounted) {
        return;
      }

      if (overlaps.isNotEmpty) {
        final shouldContinue = await _showOverlapWarning(overlaps);
        if (!mounted || !shouldContinue) {
          return;
        }
      }

      final createdTrip = await ref.read(tripsControllerProvider.notifier).createTrip(
            name: resolvedName,
            destination: destination.englishName,
            startDate: startDate,
            endDate: endDate,
            baseCurrency: baseCurrency,
            destinationCurrency: baseCurrency,
            homeCurrencySnapshot: homeCurrencySnapshot,
            isCustomTitle: isCustomTitle,
            destinationCountryCode: destination.countryCode,
          );

      final cashEntries = skipOptionalData
          ? const <_ResolvedCashEntry>[]
          : _resolvedCashEntries();
      if (cashEntries.isNotEmpty) {
        final cashWallet = ref.read(cashWalletRepositoryProvider);
        try {
          for (final entry in cashEntries) {
            await cashWallet.addCashTransaction(
              tripId: createdTrip.id,
              type: CashTransactionType.initialCash,
              amount: entry.amount,
              currencyCode: entry.currencyCode,
            );
          }
        } catch (_) {
          try {
            await ref
                .read(tripsControllerProvider.notifier)
                .deleteTrip(createdTrip.id);
          } catch (_) {
            // Best-effort rollback when initial cash insertion fails.
          }
          if (!mounted) {
            return;
          }
          CalmSnackBar.showMessage(
            context,
            message: AppLocalizations.of(context)!.tripSetupCashSaveFailed,
          );
          return;
        }
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(createdTrip);
    } catch (_) {
      if (!mounted) {
        return;
      }
      CalmSnackBar.showMessage(
        context,
        message: AppLocalizations.of(context)!.tripFormSaveFailed,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  List<_ResolvedCashEntry> _resolvedCashEntries() {
    final entries = <_ResolvedCashEntry>[];
    for (final row in _cashRows) {
      final amountText = row.amountController.text.trim();
      if (amountText.isEmpty) {
        continue;
      }
      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        continue;
      }
      final currency = row.currencyCode.trim().toUpperCase();
      if (currency.length != 3) {
        continue;
      }
      entries.add(_ResolvedCashEntry(amount: amount, currencyCode: currency));
    }
    return entries;
  }

  String _buildGeneratedTripTitle({required CountryInfo destination}) {
    final localizedName = destination.getLocalizedName(_isArabic);
    return _isArabic ? 'رحلة $localizedName' : '$localizedName Trip';
  }

  String _extractCurrencyCode(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) {
      return '';
    }
    final parts = normalized.split(RegExp(r'[-\s]+'));
    final candidate = parts.firstWhere(
      (part) => part.length >= 3,
      orElse: () => normalized,
    );
    if (candidate.length < 3) {
      return '';
    }
    return candidate.substring(0, 3);
  }

  Future<List<_TripDateOverlap>> _findDateOverlaps({
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    if (startDate == null || endDate == null) {
      return const [];
    }

    final candidateStart = DateUtils.dateOnly(startDate);
    final candidateEnd = DateUtils.dateOnly(endDate);
    final trips = await ref.read(tripRepositoryProvider).getTrips();
    final overlaps = <_TripDateOverlap>[];

    for (final trip in trips) {
      final tripStart = trip.startDate;
      final tripEnd = trip.endDate;
      if (tripStart == null || tripEnd == null) {
        continue;
      }

      final normalizedTripStart = DateUtils.dateOnly(tripStart);
      final normalizedTripEnd = DateUtils.dateOnly(tripEnd);

      if (!_hasDateOverlap(
        startA: candidateStart,
        endA: candidateEnd,
        startB: normalizedTripStart,
        endB: normalizedTripEnd,
      )) {
        continue;
      }

      overlaps.add(
        _TripDateOverlap(
          trip: trip,
          startDate: normalizedTripStart,
          endDate: normalizedTripEnd,
        ),
      );
    }

    overlaps.sort((a, b) => a.startDate.compareTo(b.startDate));
    return overlaps;
  }

  bool _hasDateOverlap({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    return !startA.isAfter(endB) && !endA.isBefore(startB);
  }

  Future<bool> _showOverlapWarning(List<_TripDateOverlap> overlaps) async {
    final l10n = AppLocalizations.of(context)!;
    final first = overlaps.first;
    final formattedRange =
        '${_formatDate(first.startDate)}${_dateRangeSeparator()}${_formatDate(first.endDate)}';
    final extraTripsText = overlaps.length > 1
        ? '\n${l10n.tripFormOverlapMoreTrips((overlaps.length - 1).toString())}'
        : '';
    final message =
        '${l10n.tripFormOverlapIntro}\n\n${first.trip.name}\n$formattedRange$extraTripsText\n\n${l10n.tripFormOverlapHint}';

    final shouldContinue = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md + bottomInset,
            ),
            child: AppConfirmationDialog(
              icon: Icons.flight_takeoff_rounded,
              title: l10n.tripFormOverlapTitle,
              message: message,
              cancelLabel: l10n.tripFormOverlapEditDates,
              confirmLabel: l10n.tripFormOverlapContinue,
              onCancel: () => Navigator.of(sheetContext).pop(false),
              onConfirm: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
        );
      },
    );

    return shouldContinue == true;
  }
}

class _CashEntryRow {
  _CashEntryRow({required this.currencyCode})
      : amountController = TextEditingController();

  String currencyCode;
  final TextEditingController amountController;

  void dispose() {
    amountController.dispose();
  }
}

class _ResolvedCashEntry {
  const _ResolvedCashEntry({
    required this.amount,
    required this.currencyCode,
  });

  final double amount;
  final String currencyCode;
}

class _TripDateOverlap {
  const _TripDateOverlap({
    required this.trip,
    required this.startDate,
    required this.endDate,
  });

  final Trip trip;
  final DateTime startDate;
  final DateTime endDate;
}

class _SetupSectionCard extends StatelessWidget {
  const _SetupSectionCard({
    required this.title,
    required this.child,
    this.hint,
  });

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hint!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.label,
    required this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _CashRowFields extends StatelessWidget {
  const _CashRowFields({
    required this.row,
    required this.onCurrencyTap,
    required this.enabled,
    required this.amountLabel,
  });

  final _CashEntryRow row;
  final VoidCallback onCurrencyTap;
  final bool enabled;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? onCurrencyTap : null,
              child: Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(12, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.currencyCode,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: row.amountController,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(
              labelText: amountLabel,
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardSummaryTile extends StatelessWidget {
  const _CardSummaryTile({required this.card});

  final CardProfile card;

  @override
  Widget build(BuildContext context) {
    final display = CardDisplayHelper.getDisplayString(context, card);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.credit_card_rounded,
            size: 20,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupGradientButton extends StatelessWidget {
  const _SetupGradientButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: onTap == null
                  ? [
                      const Color(0xFF94A3B8).withValues(alpha: 0.5),
                      const Color(0xFF94A3B8).withValues(alpha: 0.5),
                    ]
                  : const [Color(0xFF2563EB), Color(0xFF7C3AED)],
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupCurrencyPickerSheet extends StatefulWidget {
  const _SetupCurrencyPickerSheet({
    required this.currentValue,
    required this.isArabic,
    required this.searchHint,
  });

  final String currentValue;
  final bool isArabic;
  final String searchHint;

  @override
  State<_SetupCurrencyPickerSheet> createState() =>
      _SetupCurrencyPickerSheetState();
}

class _SetupCurrencyPickerSheetState extends State<_SetupCurrencyPickerSheet> {
  final _searchController = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = _kSetupSupportedCurrencies;
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _kSetupSupportedCurrencies
          : _kSetupSupportedCurrencies
              .where((c) => c.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textDirection =
        widget.isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Container(
        height: mediaQuery.size.height * 0.55 + mediaQuery.viewInsets.bottom,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final currency = _filtered[index];
                  final code = currency.split(' - ').first;
                  return ListTile(
                    title: Text(
                      currency,
                      textDirection: TextDirection.ltr,
                    ),
                    onTap: () => Navigator.of(context).pop(code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
