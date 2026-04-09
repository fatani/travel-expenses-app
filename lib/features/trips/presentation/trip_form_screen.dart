import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(tripsControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditMode ? 'Edit Trip' : 'New Trip')),
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
                          decoration: const InputDecoration(
                            labelText: 'Trip name',
                            hintText: 'Summer Conference',
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _destinationController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Destination',
                            hintText: 'Istanbul, Turkey',
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
                          decoration: const InputDecoration(
                            labelText: 'Base currency',
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
                          decoration: const InputDecoration(
                            labelText: 'Budget (optional)',
                            hintText: '2500',
                          ),
                          validator: _validateBudget,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _startDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Start date',
                            suffixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          onTap: () => _selectDate(isStartDate: true),
                          validator: _validateStartDate,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _endDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'End date',
                            suffixIcon: Icon(Icons.calendar_today_rounded),
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
                      widget.isEditMode ? 'Save Changes' : 'Create Trip',
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
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _validateBudget(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final budget = double.tryParse(value.trim());
    if (budget == null) {
      return 'Enter a valid number.';
    }
    if (budget < 0) {
      return 'Budget must be zero or more.';
    }

    return null;
  }

  String? _validateStartDate(String? value) {
    if (_startDate == null) {
      return 'This field is required.';
    }
    if (_endDate != null && _startDate!.isAfter(_endDate!)) {
      return 'Start date must be on or before the end date.';
    }

    return null;
  }

  String? _validateEndDate(String? value) {
    if (_endDate == null) {
      return 'This field is required.';
    }
    if (_startDate != null && _startDate!.isAfter(_endDate!)) {
      return 'End date must be on or after the start date.';
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
    final controller = ref.read(tripsControllerProvider.notifier);

    try {
      if (widget.trip == null) {
        await controller.createTrip(
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          baseCurrency: _baseCurrencyController.text.trim().toUpperCase(),
          budget: budget,
        );
      } else {
        await controller.updateTrip(
          trip: widget.trip!,
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          baseCurrency: _baseCurrencyController.text.trim().toUpperCase(),
          budget: budget,
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save trip: $error')));
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
