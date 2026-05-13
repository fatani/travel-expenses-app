// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../domain/country_database.dart';
import '../domain/country_info.dart';
import '../domain/trip.dart';
import '../../settings/presentation/settings_controller.dart';
import 'trip_controller.dart';

const List<String> _kSupportedCurrencies = [
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

class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.trip});

  final Trip? trip;

  bool get isEditMode => trip != null;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetFieldKey = GlobalKey();
  final _notesFieldKey = GlobalKey();
  late final TextEditingController _nameController;
  late final TextEditingController _destinationController;
  late final TextEditingController _currencyController;
  late final TextEditingController _budgetController;
  late final TextEditingController _budgetCurrencyController;
  late final TextEditingController _notesController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;

  DateTime? _startDate;
  DateTime? _endDate;
  CountryInfo? _selectedDestination;
  bool _isCustomDestinationFallback = false;
  bool _didInitDependencies = false;
  String? _lastLocaleTag;
  bool _isDatePickerOpen = false;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;

    _nameController = TextEditingController(text: trip?.name ?? '');
    _destinationController = TextEditingController(
      text: trip?.destination ?? '',
    );
    _currencyController = TextEditingController(text: trip?.baseCurrency ?? '');
    _budgetController = TextEditingController(
      text: trip?.budget?.toStringAsFixed(2) ?? '',
    );
    _budgetCurrencyController = TextEditingController(
      text: trip?.budgetCurrency ?? trip?.baseCurrency ?? '',
    );
    _notesController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();

    _startDate = trip?.startDate;
    _endDate = trip?.endDate;
    _selectedDestination = trip == null
      ? null
      : (CountryDatabase.findByName(trip.destination) ??
        CountryDatabase.findByCode(trip.destination));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _currencyController.dispose();
    _budgetController.dispose();
    _budgetCurrencyController.dispose();
    _notesController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    final localeTag = locale.toLanguageTag();

    if (_lastLocaleTag != localeTag) {
      _lastLocaleTag = localeTag;
      _syncDateFields();
      if (!widget.isEditMode && _selectedDestination != null) {
        _destinationController.text =
            _selectedDestination!.getLocalizedName(locale.languageCode.toLowerCase() == 'ar');
      }
    }

    if (_didInitDependencies) {
      return;
    }
    _didInitDependencies = true;

    if (widget.isEditMode) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final isEditMode = widget.isEditMode;

    return Form(
      key: _formKey,
      autovalidateMode:
          isEditMode ? AutovalidateMode.always : AutovalidateMode.disabled,
      child: isEditMode
          ? _buildEditTripScreen(isArabic: isArabic)
          : CreateTripVisualScreen(
              isArabic: isArabic,
              destinationController: _destinationController,
              selectedDestination: _selectedDestination,
              generatedTripTitle: _buildGeneratedTripTitle(
                isArabic: isArabic,
                destination: _selectedDestination,
              ),
              onDestinationSelected: _onDestinationSelected,
              onDestinationCleared: _onDestinationCleared,
              onCustomDestinationSelected: _onCustomDestinationSelected,
              onCreateTrip: (_selectedDestination != null || _isCustomDestinationFallback)
                  ? _submit
                  : null,
              onToggleLanguage: () => _toggleLanguage(isArabic: isArabic),
              onCustomizeTrip: _openCustomizeTripSheet,
              onBack: () => Navigator.of(context).pop(),
            ),
    );
  }

  bool get _hasInvalidDateRange {
    return _startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!);
  }

  Widget _buildEditTripScreen({required bool isArabic}) {
    final l10n = AppLocalizations.of(context)!;
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final canSave = !_hasInvalidDateRange &&
        !_isDatePickerOpen &&
        !ref.watch(tripsControllerProvider).isLoading;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFF8FAFF),
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _SoftBackground()),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _toggleLanguage(isArabic: isArabic),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Text(
                              'AR | EN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey.shade400,
                              ),
                            ),
                          ),
                        ),
                        _BackButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.tripFormEditTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          children: [
                            _buildEditDetailsCard(l10n),
                            if (_hasInvalidDateRange)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Align(
                                  alignment: isArabic
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Text(
                                    _dateRangeErrorText,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 22),
                            _GradientButton(
                              label: l10n.tripFormSaveEdit,
                              onTap: canSave ? _submit : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditDetailsCard(AppLocalizations l10n) {
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.35);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormNameLabel,
              hintText: l10n.tripFormNameHint,
            ),
          ),
          Divider(height: 20, color: dividerColor),
          TextFormField(
            controller: _destinationController,
            textInputAction: TextInputAction.next,
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormDestinationLabel,
              hintText: l10n.tripFormDestinationHint,
            ),
          ),
          Divider(height: 20, color: dividerColor),
          TextFormField(
            controller: _currencyController,
            readOnly: true,
            textDirection: TextDirection.ltr,
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormCurrencyLabel,
              hintText: 'USD - US Dollar',
              suffixIcon: const Icon(Icons.keyboard_arrow_down),
            ),
            onTap: () => _showCurrencyPicker(context),
          ),
          Divider(height: 20, color: dividerColor),
          TextFormField(
            controller: _startDateController,
            readOnly: true,
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormStartDateLabel,
              suffixIcon: const Icon(Icons.calendar_today_rounded),
            ),
            onTap: () => _selectDate(isStartDate: true),
            validator: _validateStartDate,
          ),
          Divider(height: 20, color: dividerColor),
          TextFormField(
            controller: _endDateController,
            readOnly: true,
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormEndDateLabel,
              suffixIcon: const Icon(Icons.calendar_today_rounded),
            ),
            onTap: () => _selectDate(isStartDate: false),
            validator: _validateEndDate,
          ),
          Divider(height: 20, color: dividerColor),
          TextFormField(
            controller: _budgetController,
            textInputAction: TextInputAction.next,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormBudgetLabel,
              hintText: l10n.tripFormBudgetHint,
            ),
            validator: _validateBudget,
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _budgetController,
            builder: (context, value, child) {
              if (value.text.trim().isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                children: [
                  Divider(height: 20, color: dividerColor),
                  TextFormField(
                    controller: _budgetCurrencyController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.characters,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z -]')),
                      LengthLimitingTextInputFormatter(20),
                      _UpperCaseTextFormatter(),
                    ],
                    decoration: _secondaryDetailsDecoration(
                      labelText: l10n.tripFormCurrencyLabel,
                      hintText: 'USD',
                    ),
                  ),
                ],
              );
            },
          ),
          Divider(height: 20, color: dividerColor),
          TextFormField(
            controller: _notesController,
            textInputAction: TextInputAction.done,
            minLines: 3,
            maxLines: 4,
            decoration: _secondaryDetailsDecoration(
              labelText: _notesLabel(),
              hintText: _notesHint(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetails(
    AppLocalizations l10n, {
    required FocusNode budgetFocusNode,
    required FocusNode notesFocusNode,
    Future<void> Function(bool isStartDate)? onPickDate,
  }) {
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.35);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormCustomTripNameLabel,
              hintText: l10n.tripFormCustomTripNameHint,
            ),
          ),
          Divider(height: 20, color: dividerColor),
          TextFormField(
            controller: _currencyController,
            readOnly: true,
            textDirection: TextDirection.ltr,
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormCurrencyLabel,
              hintText: 'USD - US Dollar',
              suffixIcon: const Icon(Icons.keyboard_arrow_down),
            ),
            onTap: () => _showCurrencyPicker(context),
          ),
          Divider(height: 20, color: dividerColor),
          TextFormField(
            controller: _startDateController,
            readOnly: true,
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormStartDateLabel,
              suffixIcon: const Icon(Icons.calendar_today_rounded),
            ),
            onTap: () => onPickDate?.call(true) ?? _selectDate(isStartDate: true),
            validator: _validateStartDate,
          ),
          Divider(height: 20, color: dividerColor),
          TextFormField(
            controller: _endDateController,
            readOnly: true,
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormEndDateLabel,
              suffixIcon: const Icon(Icons.calendar_today_rounded),
            ),
            onTap:
                () => onPickDate?.call(false) ?? _selectDate(isStartDate: false),
            validator: _validateEndDate,
          ),
          Divider(height: 20, color: dividerColor),

          /// Budget Field with GlobalKey
          Container(
            key: _budgetFieldKey,
            child: TextFormField(
              controller: _budgetController,
              focusNode: budgetFocusNode,
              textInputAction: TextInputAction.next,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _secondaryDetailsDecoration(
                labelText: l10n.tripFormBudgetLabel,
                hintText: l10n.tripFormBudgetHint,
              ),
              validator: _validateBudget,
            ),
          ),
          Divider(height: 20, color: dividerColor),

          /// Notes Field with GlobalKey
          Container(
            key: _notesFieldKey,
            child: TextFormField(
              controller: _notesController,
              focusNode: notesFocusNode,
              textInputAction: TextInputAction.done,
              minLines: 3,
              maxLines: 4,
              decoration: _secondaryDetailsDecoration(
                labelText: _notesLabel(),
                hintText: _notesHint(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLanguage({required bool isArabic}) async {
    final next = isArabic ? 'en' : 'ar';

    try {
      await ref.read(settingsControllerProvider.notifier).updateLocale(next);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _openCustomizeTripSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final scrollController = ScrollController();
    final budgetFocusNode = FocusNode();
    final notesFocusNode = FocusNode();

    /// Setup focus listeners for scroll-into-view
    budgetFocusNode.addListener(() {
      if (budgetFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 120), () {
          final fieldContext = _budgetFieldKey.currentContext;
          if (fieldContext != null) {
            Scrollable.ensureVisible(
              fieldContext,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: 0.25,
            );
          }
        });
      }
    });

    notesFocusNode.addListener(() {
      if (notesFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 120), () {
          final fieldContext = _notesFieldKey.currentContext;
          if (fieldContext != null) {
            Scrollable.ensureVisible(
              fieldContext,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: 0.25,
            );
          }
        });
      }
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final mediaQuery = MediaQuery.of(context);
            final sheetHeight = mediaQuery.size.height * 0.72;

            return Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: mediaQuery.size.width,
                height: sheetHeight,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    /// Drag Handle
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),

                    /// Scrollable Content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.only(
                          bottom: mediaQuery.viewInsets.bottom + 120,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: _buildAdditionalDetails(
                            l10n,
                            budgetFocusNode: budgetFocusNode,
                            notesFocusNode: notesFocusNode,
                            onPickDate: (isStartDate) async {
                              await _selectDate(
                                isStartDate: isStartDate,
                                onUiRefresh: () {
                                  setModalState(() {});
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    if (_hasInvalidDateRange)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Align(
                          alignment: _isCurrentLocaleArabic
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            _dateRangeErrorText,
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                    /// Save Button (Fixed at bottom)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        20 + mediaQuery.padding.bottom,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A)
                                .withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: Opacity(
                          opacity:
                              (_hasInvalidDateRange || _isDatePickerOpen)
                              ? 0.55
                              : 1,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: (_hasInvalidDateRange || _isDatePickerOpen)
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: (_hasInvalidDateRange ||
                                        _isDatePickerOpen)
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF94A3B8),
                                          Color(0xFF64748B),
                                        ],
                                      )
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xFF2563EB),
                                          Color(0xFF7C3AED),
                                        ],
                                      ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                l10n.tripFormSaveDetails,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      budgetFocusNode.dispose();
      notesFocusNode.dispose();
      scrollController.dispose();
    });
  }

  String _notesLabel() {
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    return isArabic ? 'ملاحظات' : 'Notes';
  }

  String _notesHint() {
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    return isArabic ? 'اكتب ملاحظة اختيارية' : 'Add an optional note';
  }

  InputDecoration _secondaryDetailsDecoration({
    required String labelText,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    );
  }

  String? _validateBudget(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final budget = double.tryParse(value.trim());
    if (budget == null) {
      return l10n.commonEnterValidNumber;
    }
    if (budget < 0) {
      return l10n.tripFormBudgetNonNegative;
    }
    return null;
  }

  String? _validateStartDate(String? value) {
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      return _dateRangeErrorText;
    }
    return null;
  }

  String? _validateEndDate(String? value) {
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      return _dateRangeErrorText;
    }
    return null;
  }

  Future<void> _showCurrencyPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrencyPickerSheet(
        currentValue: _currencyController.text,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _currencyController.text = selected;
      });
    }
  }

  Future<void> _selectDate({
    required bool isStartDate,
    VoidCallback? onUiRefresh,
  }) async {
    final initialDate = isStartDate
        ? (_startDate ?? _endDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final isArabic = _isCurrentLocaleArabic;

    setState(() {
      _isDatePickerOpen = true;
    });
    onUiRefresh?.call();

    DateTime? selectedDate;
    try {
      selectedDate = await showDatePicker(
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
                confirmButtonStyle: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                cancelButtonStyle: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            child: Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDatePickerOpen = false;
        });
        onUiRefresh?.call();
      }
    }

    if (selectedDate == null) {
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
    onUiRefresh?.call();

    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (ref.read(tripsControllerProvider).isLoading) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode.toLowerCase() == 'ar';
    final isCreateMode = widget.trip == null;
    final selectedDestination = _selectedDestination;
    final customDestination = _destinationController.text.trim();

    if (isCreateMode && selectedDestination == null && customDestination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tripFormDestinationRequired,
          ),
        ),
      );
      return;
    }

    final resolvedName = _nameController.text.trim().isEmpty
        ? _buildGeneratedTripTitle(
            isArabic: isArabic,
            destination: selectedDestination,
            customDestination: customDestination,
          )
        : _nameController.text.trim();
    final isCustomTitle = _nameController.text.trim().isNotEmpty;
    final destinationCountryCode = isCreateMode
        ? selectedDestination?.countryCode
        : widget.trip!.destinationCountryCode;
    final typedCurrency = _extractCurrencyCode(_currencyController.text);
    final baseCurrency = typedCurrency.isNotEmpty
        ? typedCurrency
        : (selectedDestination?.currencyCode ??
            _resolveDefaultCurrency(isArabic: isArabic, locale: locale));
    _currencyController.text = baseCurrency;

    final resolvedDestination = isCreateMode
      ? (selectedDestination?.englishName ?? customDestination)
        : _destinationController.text.trim();

    final budgetText = _budgetController.text.trim();
    final budget = budgetText.isEmpty ? null : double.parse(budgetText);
    final budgetCurrencyText =
        _budgetCurrencyController.text.trim().toUpperCase();
    final budgetCurrency = budget == null
        ? null
        : (budgetCurrencyText.isEmpty ? baseCurrency : budgetCurrencyText);
    final controller = ref.read(tripsControllerProvider.notifier);

    try {
      if (isCreateMode) {
        final createdTrip = await controller.createTrip(
          name: resolvedName,
          destination: resolvedDestination,
          startDate: _startDate,
          endDate: _endDate,
          baseCurrency: baseCurrency,
          budget: budget,
          budgetCurrency: budgetCurrency,
          isCustomTitle: isCustomTitle,
          destinationCountryCode: destinationCountryCode,
        );

        if (!mounted) {
          return;
        }

        Navigator.of(context).pop(createdTrip);
      } else {
        await controller.updateTrip(
          trip: widget.trip!,
          name: resolvedName,
          destination: resolvedDestination,
          startDate: _startDate,
          endDate: _endDate,
          baseCurrency: baseCurrency,
          budget: budget,
          budgetCurrency: budgetCurrency,
          isCustomTitle: isCustomTitle,
          destinationCountryCode: destinationCountryCode,
        );
      }

      if (!mounted) {
        return;
      }

      if (widget.trip != null) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tripFormSaveError('$error'),
          ),
        ),
      );
    }
  }

  void _onDestinationSelected(CountryInfo country) {
    setState(() {
      _selectedDestination = country;
      _isCustomDestinationFallback = false;
      _destinationController.text = country.getLocalizedName(_isCurrentLocaleArabic);
      _currencyController.text = country.currencyCode;
      if (_budgetCurrencyController.text.trim().isEmpty) {
        _budgetCurrencyController.text = country.currencyCode;
      }
    });
  }

  void _onDestinationCleared() {
    if (_selectedDestination == null && !_isCustomDestinationFallback) {
      return;
    }
    setState(() {
      _selectedDestination = null;
      _isCustomDestinationFallback = false;
    });
  }

  void _onCustomDestinationSelected(String destination) {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) {
      return;
    }
    setState(() {
      _selectedDestination = null;
      _isCustomDestinationFallback = true;
      _destinationController.text = trimmed;
      if (_currencyController.text.trim().isEmpty) {
        final locale = Localizations.localeOf(context);
        final isArabic = locale.languageCode.toLowerCase() == 'ar';
        _currencyController.text = _resolveDefaultCurrency(
          isArabic: isArabic,
          locale: locale,
        );
      }
    });
  }

  String _buildGeneratedTripTitle({
    required bool isArabic,
    required CountryInfo? destination,
    String? customDestination,
  }) {
    if (destination == null) {
      final fallbackName = customDestination?.trim() ?? '';
      if (fallbackName.isEmpty) {
        return '';
      }
      return isArabic ? 'رحلة $fallbackName' : '$fallbackName Trip';
    }
    final localizedName = destination.getLocalizedName(isArabic);
    return isArabic ? 'رحلة $localizedName' : '$localizedName Trip';
  }

  void _syncDateFields() {
    _startDateController.text =
        _startDate == null ? '' : _formatDate(_startDate!);
    _endDateController.text = _endDate == null ? '' : _formatDate(_endDate!);
  }

  bool get _isCurrentLocaleArabic {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  }

  String get _dateRangeErrorText {
    return _isCurrentLocaleArabic
        ? 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية'
        : 'End date must be after start date';
  }

  String _formatDate(DateTime date) {
    final localeCode = _isCurrentLocaleArabic ? 'ar' : 'en';
    final pattern = _isCurrentLocaleArabic ? 'd MMMM y' : 'd MMM y';
    return DateFormat(pattern, localeCode).format(date);
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

  String _resolveDefaultCurrency({
    required bool isArabic,
    required Locale locale,
  }) {
    final typedCurrency = _extractCurrencyCode(_currencyController.text);
    if (typedCurrency.isNotEmpty) {
      return typedCurrency;
    }

    final trips = ref.read(tripsControllerProvider).valueOrNull ?? const [];
    final sortedTrips = [...trips]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    for (final trip in sortedTrips) {
      final candidate = _extractCurrencyCode(trip.baseCurrency);
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }

    final isSaudiLocale = locale.countryCode?.toUpperCase() == 'SA';
    if (isArabic || isSaudiLocale) {
      return 'SAR';
    }

    return 'USD';
  }
}

// ---------------------------------------------------------------------------
// Currency Picker Sheet
// ---------------------------------------------------------------------------

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({required this.currentValue});

  final String currentValue;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _searchController = TextEditingController();
  List<String> _filtered = _kSupportedCurrencies;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _kSupportedCurrencies
          : _kSupportedCurrencies
              .where((c) => c.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  bool _isCurrentlySelected(String currency) {
    final code = currency.split(' - ').first;
    final value = widget.currentValue.trim().toUpperCase();
    return value == currency.toUpperCase() || value == code;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.65 + mediaQuery.viewInsets.bottom,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'Search currency...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            // Currency list
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final currency = _filtered[index];
                  final parts = currency.split(' - ');
                  final code = parts.first;
                  final name = parts.length > 1 ? parts.last : currency;
                  final selected = _isCurrentlySelected(currency);

                  return ListTile(
                    leading: Container(
                      width: 48,
                      alignment: Alignment.center,
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(name),
                    trailing: selected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    selected: selected,
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    onTap: () => Navigator.of(context).pop(currency),
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

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class CreateTripVisualScreen extends StatelessWidget {
  final bool isArabic;
  final TextEditingController destinationController;
  final CountryInfo? selectedDestination;
  final String generatedTripTitle;
  final ValueChanged<CountryInfo> onDestinationSelected;
  final VoidCallback onDestinationCleared;
  final ValueChanged<String> onCustomDestinationSelected;
  final VoidCallback? onCreateTrip;
  final VoidCallback onToggleLanguage;
  final VoidCallback onCustomizeTrip;
  final VoidCallback onBack;

  const CreateTripVisualScreen({
    super.key,
    required this.isArabic,
    required this.destinationController,
    required this.selectedDestination,
    required this.generatedTripTitle,
    required this.onDestinationSelected,
    required this.onDestinationCleared,
    required this.onCustomDestinationSelected,
    required this.onCreateTrip,
    required this.onToggleLanguage,
    required this.onCustomizeTrip,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = viewInsetsBottom > 0;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _SoftBackground()),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      28 + viewInsetsBottom,
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: onToggleLanguage,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      'AR | EN',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                                _BackButton(onTap: onBack),
                              ],
                            ),
                            const SizedBox(height: 30),
                            Image.asset(
                              'assets/travel.png',
                              height: 150,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.flight_takeoff,
                                size: 92,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              l10n.createTripHeading,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.createTripSubheading,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.blueGrey.shade300,
                              ),
                            ),
                            const SizedBox(height: 34),
                            _DestinationCard(
                              isArabic: isArabic,
                              controller: destinationController,
                              selectedDestination: selectedDestination,
                              onCountrySelected: onDestinationSelected,
                              onSelectionCleared: onDestinationCleared,
                              onCustomDestinationSelected:
                                  onCustomDestinationSelected,
                            ),
                            if (generatedTripTitle.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                l10n.tripFormCreateWithoutCustomTitle(generatedTripTitle),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade400,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            _GradientButton(
                              label: l10n.tripFormSaveCreate,
                              onTap: onCreateTrip,
                            ),
                            if (!keyboardOpen) ...[
                              const SizedBox(height: 30),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Divider(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      isArabic ? 'أو' : 'or',
                                      style: TextStyle(
                                        color: Colors.blueGrey.shade300,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    child: Divider(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: onCustomizeTrip,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.settings_outlined,
                                        color: Color(0xFF7C3AED),
                                        size: 26,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        isArabic
                                            ? 'تخصيص الرحلة (اختياري)'
                                            : 'Customize trip (optional)',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 70),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final bool isArabic;
  final TextEditingController controller;
  final CountryInfo? selectedDestination;
  final ValueChanged<CountryInfo> onCountrySelected;
  final VoidCallback onSelectionCleared;
  final ValueChanged<String> onCustomDestinationSelected;

  const _DestinationCard({
    required this.isArabic,
    required this.controller,
    required this.selectedDestination,
    required this.onCountrySelected,
    required this.onSelectionCleared,
    required this.onCustomDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isArabic ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              const Icon(
                Icons.public_rounded,
                color: Color(0xFF7C3AED),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.createTripHeading,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Autocomplete<CountryInfo>(
            optionsBuilder: (textEditingValue) {
              return CountryDatabase.search(textEditingValue.text.trim());
            },
            displayStringForOption: (option) => option.getLocalizedName(isArabic),
            onSelected: onCountrySelected,
            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
              if (textController.text != controller.text) {
                textController.text = controller.text;
                textController.selection = TextSelection.collapsed(
                  offset: textController.text.length,
                );
              }

              return TextField(
                controller: textController,
                focusNode: focusNode,
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                onChanged: (value) {
                  controller.text = value;
                  final selected = selectedDestination;
                  if (selected == null) {
                    return;
                  }
                  final selectedLabels = <String>{
                    selected.englishName.toLowerCase(),
                    selected.arabicName,
                    selected.countryCode.toLowerCase(),
                    selected.currencyCode.toLowerCase(),
                  };
                  if (!selectedLabels.contains(value.trim().toLowerCase())) {
                    onSelectionCleared();
                  }
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  hintText: l10n.tripFormDestinationSearchLabel,
                  hintStyle: TextStyle(
                    color: Colors.blueGrey.shade200,
                    fontWeight: FontWeight.w700,
                  ),
                  prefixIcon: isArabic
                      ? null
                      : const Icon(Icons.search_rounded, color: Color(0xFF7C3AED)),
                  suffixIcon: isArabic
                      ? const Icon(Icons.search_rounded, color: Color(0xFF7C3AED))
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFF7C3AED),
                      width: 1.4,
                    ),
                  ),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              final visibleOptions = options.take(8).toList(growable: false);
              final query = controller.text.trim();
              final mediaQuery = MediaQuery.of(context);
              final availableHeight =
                  (mediaQuery.size.height - mediaQuery.viewInsets.bottom) * 0.42;
              final dropdownMaxHeight = availableHeight.clamp(140.0, 300.0);
              return Align(
                alignment: isArabic ? Alignment.topRight : Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 48,
                    constraints: BoxConstraints(maxHeight: dropdownMaxHeight),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD6CCFA)),
                    ),
                    child: visibleOptions.isEmpty
                        ? InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              onCustomDestinationSelected(query);
                              FocusScope.of(context).unfocus();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDE8FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.add_location_alt_outlined,
                                      size: 18,
                                      color: Color(0xFF6D49D8),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l10n.tripFormCustomDestinationFallback,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2F244F),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          physics: const ClampingScrollPhysics(),
                          primary: false,
                            shrinkWrap: true,
                            itemCount: visibleOptions.length,
                            itemBuilder: (context, index) {
                              final country = visibleOptions[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                leading: Text(
                                  country.flagEmoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                title: Text(
                                  country.getLocalizedName(isArabic),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${country.currencyCode} • ${country.currencyName}',
                                  textDirection: TextDirection.ltr,
                                ),
                                trailing: Text(
                                  country.countryCode,
                                  style: const TextStyle(
                                    color: Color(0xFF7A6AAE),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onTap: () => onSelected(country),
                              );
                            },
                          ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          Text(
            selectedDestination == null
                ? l10n.tripFormDestinationRequired
                : l10n.tripFormCurrencyAutoSelected(selectedDestination!.currencyCode),
            style: TextStyle(
              fontSize: 15,
              color: Colors.blueGrey.shade300,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          height: 64,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: onTap == null
                  ? const [
                      Color(0xFF94A3B8),
                      Color(0xFF94A3B8),
                    ]
                  : const [
                      Color(0xFF2563EB),
                      Color(0xFF7C3AED),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: (onTap == null
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF7C3AED))
                    .withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: IconButton(
            onPressed: onTap,
            icon: const Directionality(
              textDirection: TextDirection.ltr,
              child: Icon(
                Icons.arrow_back,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftBackground extends StatelessWidget {
  const _SoftBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -60,
          right: -60,
          child: Container(
            height: 330,
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
        Positioned(
          bottom: -80,
          left: -30,
          right: -30,
          child: Opacity(
            opacity: 0.08,
            child: SizedBox(
              height: 140,
              child: CustomPaint(
                painter: _SkylinePainter(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.08, size.height * 0.55)
      ..lineTo(size.width * 0.16, size.height)
      ..lineTo(size.width * 0.28, size.height * 0.72)
      ..lineTo(size.width * 0.33, size.height)
      ..lineTo(size.width * 0.48, size.height * 0.42)
      ..lineTo(size.width * 0.53, size.height)
      ..lineTo(size.width * 0.68, size.height * 0.68)
      ..lineTo(size.width * 0.78, size.height)
      ..lineTo(size.width * 0.92, size.height * 0.50)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
