import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../domain/trip.dart';
import '../../settings/presentation/settings_controller.dart';
import 'trip_controller.dart';

String getDefaultTripName(bool isArabic) {
  return isArabic ? 'رحلتي الجديدة' : 'My new trip';
}

class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.trip});

  final Trip? trip;

  bool get isEditMode => trip != null;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _destinationController;
  late final TextEditingController _currencyController;
  String _baseCurrencyValue = '';
  late final TextEditingController _budgetController;
  late final TextEditingController _budgetCurrencyController;
  late final TextEditingController _notesController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _canSubmitRequiredFields = false;
  bool _didSeedDefaults = false;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;

    _nameController = TextEditingController(text: trip?.name ?? '');
    _destinationController = TextEditingController(
      text: trip?.destination ?? '',
    );
    _baseCurrencyValue = trip?.baseCurrency ?? '';
    _currencyController = TextEditingController(text: _baseCurrencyValue);
    _budgetController = TextEditingController(
      text: trip?.budget?.toStringAsFixed(2) ?? '',
    );
    _budgetCurrencyController = TextEditingController(
      text: trip?.budgetCurrency ?? trip?.baseCurrency ?? '',
    );
    _notesController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();

    _nameController.addListener(_updateSubmitEnabledState);
    _currencyController.addListener(_syncCurrencyFromText);

    _startDate = trip?.startDate;
    _endDate = trip?.endDate;
    _syncDateFields();

    _updateSubmitEnabledState();
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
    if (_didSeedDefaults || widget.isEditMode) {
      return;
    }

    _didSeedDefaults = true;
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    if (_baseCurrencyValue.trim().isEmpty) {
      _baseCurrencyValue = isArabic ? 'SAR' : 'USD';
      _currencyController.text = _baseCurrencyValue;
    }
    final defaultName = getDefaultTripName(isArabic);
    if (_nameController.text.trim().isEmpty ||
        _nameController.text == 'رحلتي الجديدة' ||
        _nameController.text == 'My new trip') {
      _nameController.text = defaultName;
    }

    _updateSubmitEnabledState();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(tripsControllerProvider).isLoading;
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final canCreate = !isSaving && _canSubmitRequiredFields;

    return Form(
      key: _formKey,
      child: CreateTripVisualScreen(
        isArabic: isArabic,
        tripNameController: _nameController,
        onCreateTrip: canCreate ? _submit : () {},
        onToggleLanguage: () => _toggleLanguage(isArabic: isArabic),
        onCustomizeTrip: _openCustomizeTripSheet,
        onBack: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildAdditionalDetails(AppLocalizations l10n) {
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
              hintText: 'USD - US Dollar',
              suffixIcon: const Icon(Icons.keyboard_arrow_down),
            ),
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
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: _secondaryDetailsDecoration(
              labelText: l10n.tripFormBudgetLabel,
              hintText: l10n.tripFormBudgetHint,
            ),
            validator: _validateBudget,
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

  Future<void> _toggleLanguage({required bool isArabic}) async {
    final next = isArabic ? 'en' : 'ar';
    final nextIsArabic = next == 'ar';

    final defaultName = getDefaultTripName(nextIsArabic);
    if (_nameController.text.trim().isEmpty ||
        _nameController.text == 'رحلتي الجديدة' ||
        _nameController.text == 'My new trip') {
      _nameController.text = defaultName;
    }

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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
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
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: _buildAdditionalDetails(l10n),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

  String? _validateRequired(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l10n.commonRequiredField;
    }
    return null;
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
      return AppLocalizations.of(context)!.tripFormStartDateBeforeEnd;
    }
    return null;
  }

  String? _validateEndDate(String? value) {
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      return AppLocalizations.of(context)!.tripFormEndDateAfterStart;
    }
    return null;
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
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      if (isStartDate) {
        _startDate = DateUtils.dateOnly(selectedDate);
      } else {
        _endDate = DateUtils.dateOnly(selectedDate);
      }
      _syncDateFields();
    });

    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    final requiredName = _validateRequired(_nameController.text);
    if (requiredName != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(requiredName)));
      return;
    }

    final currencyCode = _extractCurrencyCode(_currencyController.text);
    if (currencyCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_validateRequired('')!)));
      return;
    }

    _baseCurrencyValue = currencyCode;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final budgetText = _budgetController.text.trim();
    final budget = budgetText.isEmpty ? null : double.parse(budgetText);
    final baseCurrency = _baseCurrencyValue.trim().toUpperCase();
    final budgetCurrencyText =
        _budgetCurrencyController.text.trim().toUpperCase();
    final budgetCurrency = budget == null
        ? null
        : (budgetCurrencyText.isEmpty ? baseCurrency : budgetCurrencyText);
    final controller = ref.read(tripsControllerProvider.notifier);

    try {
      if (widget.trip == null) {
        await controller.createTrip(
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          baseCurrency: baseCurrency,
          budget: budget,
          budgetCurrency: budgetCurrency,
        );
      } else {
        await controller.updateTrip(
          trip: widget.trip!,
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          baseCurrency: baseCurrency,
          budget: budget,
          budgetCurrency: budgetCurrency,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
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

  void _syncDateFields() {
    final formatter = DateFormat('dd MMM yyyy', 'en');
    _startDateController.text =
        _startDate == null ? '' : formatter.format(_startDate!);
    _endDateController.text =
        _endDate == null ? '' : formatter.format(_endDate!);
  }

  void _updateSubmitEnabledState() {
    final canSubmit = _nameController.text.trim().isNotEmpty &&
        _baseCurrencyValue.trim().length == 3;

    if (_canSubmitRequiredFields == canSubmit) {
      return;
    }

    setState(() {
      _canSubmitRequiredFields = canSubmit;
    });
  }

  void _syncCurrencyFromText() {
    final parsed = _extractCurrencyCode(_currencyController.text);
    if (_baseCurrencyValue == parsed) {
      return;
    }
    _baseCurrencyValue = parsed;
    _updateSubmitEnabledState();
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
  final TextEditingController tripNameController;
  final VoidCallback onCreateTrip;
  final VoidCallback onToggleLanguage;
  final VoidCallback onCustomizeTrip;
  final VoidCallback onBack;

  const CreateTripVisualScreen({
    super.key,
    required this.isArabic,
    required this.tripNameController,
    required this.onCreateTrip,
    required this.onToggleLanguage,
    required this.onCustomizeTrip,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _SoftBackground()),

              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  children: [
                    Row(
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
                        const Spacer(),
                        _BackButton(onTap: onBack),
                      ],
                    ),

                    const SizedBox(height: 30),

                    Image.asset(
                      'assets/travel.png',
                      height: 150,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.flight_takeoff,
                        size: 92,
                        color: Color(0xFF7C3AED),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Text(
                      isArabic ? 'ابدأ رحلتك ✈️' : 'Start your trip ✈️',
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
                      isArabic
                          ? 'أنشئ رحلتك وابدأ تتبع مصاريفك بسهولة'
                          : 'Create your trip and start tracking expenses easily',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey.shade300,
                      ),
                    ),

                    const SizedBox(height: 34),

                    _TripNameCard(
                      isArabic: isArabic,
                      controller: tripNameController,
                    ),

                    const SizedBox(height: 24),

                    _GradientButton(
                      label: isArabic ? 'إنشاء الرحلة' : 'Create Trip',
                      onTap: onCreateTrip,
                    ),

                    const SizedBox(height: 30),

                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            isArabic ? 'أو' : 'or',
                            style: TextStyle(
                              color: Colors.blueGrey.shade300,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripNameCard extends StatelessWidget {
  final bool isArabic;
  final TextEditingController controller;

  const _TripNameCard({
    required this.isArabic,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final defaultName = getDefaultTripName(isArabic);

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
                Icons.card_travel_outlined,
                color: Color(0xFF7C3AED),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'اسم الرحلة' : 'Trip name',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          TextField(
            controller: controller,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              hintText: defaultName,
              hintStyle: TextStyle(
                color: Colors.blueGrey.shade200,
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: isArabic
                  ? null
                  : const Icon(Icons.star_border, color: Color(0xFF7C3AED)),
              suffixIcon: isArabic
                  ? const Icon(Icons.star_border, color: Color(0xFF7C3AED))
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
          ),

          const SizedBox(height: 12),

          Text(
            isArabic ? 'يمكنك تغييره لاحقًا' : 'You can change it later',
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
  final VoidCallback onTap;

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
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2563EB),
                Color(0xFF7C3AED),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
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
