import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  late final TextEditingController _baseCurrencyController;
  late final TextEditingController _budgetController;
  late final TextEditingController _budgetCurrencyController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;

    _nameController = TextEditingController(text: trip?.name ?? '');
    _destinationController = TextEditingController(
      text: trip?.destination ?? '',
    );
    _baseCurrencyController = TextEditingController(
      text: trip?.baseCurrency ?? '',
    );
    _budgetController = TextEditingController(
      text: trip?.budget?.toStringAsFixed(2) ?? '',
    );
    _budgetCurrencyController = TextEditingController(
      text: trip?.budgetCurrency ?? trip?.baseCurrency ?? '',
    );
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _startDate = trip?.startDate;
    _endDate = trip?.endDate;
    _syncDateFields();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _baseCurrencyController.dispose();
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
                Card(
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
                        TextFormField(
                          controller: _baseCurrencyController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[a-zA-Z]'),
                            ),
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.tripFormCurrencyLabel,
                            hintText: 'USD',
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _budgetController,
                          textInputAction: TextInputAction.done,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.tripFormBudgetLabel,
                            hintText: l10n.tripFormBudgetHint,
                          ),
                          validator: _validateBudget,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _budgetCurrencyController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[a-zA-Z]'),
                            ),
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.tripFormBudgetCurrencyLabel,
                            hintText: l10n.tripFormBudgetCurrencyHint,
                          ),
                          validator: _validateBudgetCurrency,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _startDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: l10n.tripFormStartDateLabel,
                            suffixIcon: const Icon(
                              Icons.calendar_today_rounded,
                            ),
                          ),
                          onTap: () => _selectDate(isStartDate: true),
                          validator: _validateStartDate,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _endDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: l10n.tripFormEndDateLabel,
                            suffixIcon: const Icon(
                              Icons.calendar_today_rounded,
                            ),
                          ),
                          onTap: () => _selectDate(isStartDate: false),
                          validator: _validateEndDate,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSaving ? null : _submit,
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

    if (budgetText.isEmpty) {
      return null;
    }
    if (currency.isEmpty) {
      return null;
    }
    if (currency.length != 3) {
      return l10n.tripFormBudgetCurrencyInvalid;
    }

    return null;
  }

  String? _validateStartDate(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (_startDate == null) {
      return l10n.commonRequiredField;
    }
    if (_endDate != null && _startDate!.isAfter(_endDate!)) {
      return l10n.tripFormStartDateBeforeEnd;
    }

    return null;
  }

  String? _validateEndDate(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (_endDate == null) {
      return l10n.commonRequiredField;
    }
    if (_startDate != null && _startDate!.isAfter(_endDate!)) {
      return l10n.tripFormEndDateAfterStart;
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
    final baseCurrency = _baseCurrencyController.text.trim().toUpperCase();
    final budgetCurrencyText = _budgetCurrencyController.text.trim().toUpperCase();
    final budgetCurrency = budget == null
      ? null
      : (budgetCurrencyText.isEmpty ? baseCurrency : budgetCurrencyText);
    final controller = ref.read(tripsControllerProvider.notifier);

    try {
      if (widget.trip == null) {
        await controller.createTrip(
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          baseCurrency: baseCurrency,
          budget: budget,
          budgetCurrency: budgetCurrency,
        );
      } else {
        await controller.updateTrip(
          trip: widget.trip!,
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
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
    final formatter = DateFormat('dd MMM yyyy');
    _startDateController.text = _startDate == null
        ? ''
        : formatter.format(_startDate!);
    _endDateController.text = _endDate == null
        ? ''
        : formatter.format(_endDate!);
  }
}
