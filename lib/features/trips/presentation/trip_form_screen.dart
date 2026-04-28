import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../domain/trip.dart';
import 'trip_controller.dart';

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
  String _baseCurrencyValue = '';
  late final TextEditingController _budgetController;
  late final TextEditingController _budgetCurrencyController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _expandMoreDetails = false;
  bool _canSubmitRequiredFields = false;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;

    _nameController = TextEditingController(text: trip?.name ?? '');
    _destinationController = TextEditingController(
      text: trip?.destination ?? '',
    );
    _baseCurrencyValue = trip?.baseCurrency ?? '';
    _budgetController = TextEditingController(
      text: trip?.budget?.toStringAsFixed(2) ?? '',
    );
    _budgetCurrencyController = TextEditingController(
      text: trip?.budgetCurrency ?? trip?.baseCurrency ?? '',
    );
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();

    _nameController.addListener(_updateSubmitEnabledState);
    _destinationController.addListener(_updateSubmitEnabledState);

    _startDate = trip?.startDate;
    _endDate = trip?.endDate;
    _syncDateFields();

    if (widget.isEditMode) {
      _expandMoreDetails =
          trip?.startDate != null ||
          trip?.endDate != null ||
          trip?.budget != null;
    }

    _updateSubmitEnabledState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _budgetController.dispose();
    _budgetCurrencyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSaving = ref.watch(tripsControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode ? l10n.tripFormEditTitle : l10n.tripFormCreateTitle,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRequiredFields(l10n),
                if (!_canSubmitRequiredFields) ...
                  [
                    const SizedBox(height: 8),
                    Text(
                      l10n.tripFormRequiredFieldsHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                const SizedBox(height: 12),
                _buildMoreDetailsSection(l10n),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        isSaving || !_canSubmitRequiredFields ? null : _submit,
                    child: Text(
                      widget.isEditMode
                          ? l10n.tripFormSaveEdit
                          : l10n.tripFormSaveCreate,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequiredFields(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.tripFormNameLabel,
                hintText: l10n.tripFormNameHint,
              ),
              validator: _validateRequired,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _destinationController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.tripFormDestinationLabel,
                hintText: l10n.tripFormDestinationHint,
              ),
              validator: _validateRequired,
            ),
            const SizedBox(height: 16),
            Autocomplete<_CurrencyOption>(
              initialValue: TextEditingValue(text: _baseCurrencyValue),
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toUpperCase();
                if (query.isEmpty) {
                  return const Iterable<_CurrencyOption>.empty();
                }
                final startsWithMatches = _kCurrencies
                    .where((c) => c.code.startsWith(query))
                    .toList(growable: false);

                // For single-letter queries, strict prefix matching is less noisy.
                if (query.length == 1) {
                  return startsWithMatches;
                }

                final startsWithCodes = startsWithMatches
                    .map((c) => c.code)
                    .toSet();
                final containsMatches = _kCurrencies.where(
                  (c) =>
                      !startsWithCodes.contains(c.code) &&
                      (c.code.contains(query) ||
                          c.name.toUpperCase().contains(query)),
                );

                return [...startsWithMatches, ...containsMatches];
              },
              displayStringForOption: (option) => option.code,
              onSelected: (option) {
                setState(() => _baseCurrencyValue = option.code);
                _updateSubmitEnabledState();
              },
              fieldViewBuilder: (
                context,
                controller,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                    LengthLimitingTextInputFormatter(3),
                    _UpperCaseTextFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.tripFormCurrencyLabel,
                    hintText: 'USD',
                  ),
                  onChanged: (value) {
                    _baseCurrencyValue = value.trim();
                    _updateSubmitEnabledState();
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.commonRequiredField;
                    }
                    return null;
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: AlignmentDirectional.topStart,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final opt = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(opt),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              '${opt.code} — ${opt.name}',
                              textDirection: TextDirection.ltr,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreDetailsSection(AppLocalizations l10n) {
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.35);

    return Card(
      clipBehavior: Clip.hardEdge,
      child: ExpansionTile(
        title: Text(l10n.tripFormMoreDetails),
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: _expandMoreDetails,
        onExpansionChanged: (expanded) =>
            setState(() => _expandMoreDetails = expanded),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
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
                  controller: _budgetCurrencyController,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: _secondaryDetailsDecoration(
                    labelText: l10n.tripFormBudgetCurrencyLabel,
                    hintText: l10n.tripFormBudgetCurrencyHint,
                  ),
                  validator: _validateBudgetCurrency,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  String? _validateBudgetCurrency(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final budgetText = _budgetController.text.trim();
    final currency = value?.trim() ?? '';
    if (budgetText.isEmpty || currency.isEmpty) {
      return null;
    }
    if (currency.length != 3) {
      return l10n.tripFormBudgetCurrencyInvalid;
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
        _destinationController.text.trim().isNotEmpty &&
        _baseCurrencyValue.trim().length == 3;

    if (_canSubmitRequiredFields == canSubmit) {
      return;
    }

    setState(() {
      _canSubmitRequiredFields = canSubmit;
    });
  }
}

class _CurrencyOption {
  const _CurrencyOption(this.code, this.name);
  final String code;
  final String name;
}

const List<_CurrencyOption> _kCurrencies = [
  _CurrencyOption('AED', 'UAE Dirham'),
  _CurrencyOption('AUD', 'Australian Dollar'),
  _CurrencyOption('BHD', 'Bahraini Dinar'),
  _CurrencyOption('CAD', 'Canadian Dollar'),
  _CurrencyOption('CHF', 'Swiss Franc'),
  _CurrencyOption('CNY', 'Chinese Yuan'),
  _CurrencyOption('EGP', 'Egyptian Pound'),
  _CurrencyOption('EUR', 'Euro'),
  _CurrencyOption('GBP', 'British Pound'),
  _CurrencyOption('HKD', 'Hong Kong Dollar'),
  _CurrencyOption('IDR', 'Indonesian Rupiah'),
  _CurrencyOption('INR', 'Indian Rupee'),
  _CurrencyOption('JPY', 'Japanese Yen'),
  _CurrencyOption('KRW', 'South Korean Won'),
  _CurrencyOption('KWD', 'Kuwaiti Dinar'),
  _CurrencyOption('MYR', 'Malaysian Ringgit'),
  _CurrencyOption('OMR', 'Omani Rial'),
  _CurrencyOption('QAR', 'Qatari Riyal'),
  _CurrencyOption('SAR', 'Saudi Riyal'),
  _CurrencyOption('SGD', 'Singapore Dollar'),
  _CurrencyOption('THB', 'Thai Baht'),
  _CurrencyOption('TRY', 'Turkish Lira'),
  _CurrencyOption('USD', 'US Dollar'),
  _CurrencyOption('VND', 'Vietnamese Dong'),
];

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
