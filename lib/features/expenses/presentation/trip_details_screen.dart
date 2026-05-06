import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

import '../../../core/providers/database_providers.dart';
import '../../export/presentation/export_menu.dart';
import '../../sms_parser/presentation/sms_expense_screen.dart';
import '../../reports/presentation/trip_reports_screen.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/trip_form_screen.dart';
import '../domain/expense.dart';
import 'expense_controller.dart';
import 'expense_form_screen.dart';
import 'expense_option_labels.dart';

String _formatAmountCurrency(double amount, String currencyCode) {
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  final formatter = NumberFormat('#,##0.##', 'en');
  return '${formatter.format(amount)} $normalizedCurrency';
}

String _formatAmountCurrencyLtr(double amount, String currencyCode) {
  // LTR isolate keeps number+currency order stable in RTL locales.
  return '\u2066${_formatAmountCurrency(amount, currencyCode)}\u2069';
}

class TripDetailsScreen extends ConsumerStatefulWidget {
  const TripDetailsScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends ConsumerState<TripDetailsScreen> {
  late Trip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final expensesState = ref.watch(expenseControllerProvider(_trip.id));
    final hasExpenses = expensesState.valueOrNull?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_trip.name),
        actions: [
          ExportMenu(trip: _trip, enabled: hasExpenses),
          IconButton(
            tooltip: context.l10n.tripDetailsReportTooltip,
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TripReportsScreen(trip: _trip),
              ),
            ),
            icon: const Icon(Icons.bar_chart_outlined),
          ),
          IconButton(
            tooltip: l10n.tripDetailsEditTripTooltip,
            onPressed: _openTripEditor,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: expensesState.when(
        data: (expenses) => _TripDetailsContent(
          trip: _trip,
          expenses: expenses,
          onAddExpense: () => _openQuickAddSheet(expenses),
          onAddViaSms: _openSmsExpenseScreen,
          onFixDates: _openTripEditor,
          onEditExpense: (expense) => _openExpenseForm(expense: expense),
          onDeleteExpense: (expense) => _confirmDelete(expense),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40),
                const SizedBox(height: 12),
                Text(
                  l10n.tripDetailsLoadError,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref
                      .read(expenseControllerProvider(_trip.id).notifier)
                      .reload(),
                  child: Text(l10n.commonTryAgain),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: hasExpenses
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _openQuickAddSheet(expensesState.valueOrNull ?? const []),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.tripDetailsAddExpense),
            )
          : null,
    );
  }

  Future<void> _openTripEditor() async {
    await Navigator.of(context).push<Trip?>(
      MaterialPageRoute<Trip?>(builder: (_) => TripFormScreen(trip: _trip)),
    );

    final refreshedTrip = await ref.read(tripRepositoryProvider).getTripById(
      _trip.id,
    );
    if (!mounted || refreshedTrip == null) {
      return;
    }

    setState(() {
      _trip = refreshedTrip;
    });
  }

  Future<void> _openExpenseForm({
    Expense? expense,
    String? initialAmount,
    String? initialCategory,
    String? initialPaymentMethod,
    String? initialCurrency,
    DateTime? initialSpentAt,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseFormScreen(
          trip: _trip,
          expense: expense,
          initialAmount: initialAmount,
          initialCategory: initialCategory,
          initialPaymentMethod: initialPaymentMethod,
          initialCurrency: initialCurrency,
          initialSpentAt: initialSpentAt,
        ),
      ),
    );
  }

  Future<void> _openQuickAddSheet(List<Expense> expenses) async {
    final result = await showModalBottomSheet<_QuickAddSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: QuickAddExpenseSheet(
            trip: _trip,
            expenses: expenses,
          ),
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.openMoreDetails) {
      final draft = result.draft;
      await _openExpenseForm(
        initialAmount: draft?.amountText,
        initialCategory: draft?.category,
        initialPaymentMethod: draft?.paymentMethod,
        initialCurrency: draft?.currencyCode,
        initialSpentAt: draft?.spentAt,
      );
      return;
    }

    final payload = result.payload;
    if (payload == null) {
      return;
    }

    unawaited(_createQuickExpense(payload));

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.tripDetailsQuickAddExpenseAdded),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createQuickExpense(_QuickAddSubmitPayload payload) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref
          .read(expenseControllerProvider(_trip.id).notifier)
          .createExpense(
            title: payload.title,
            amount: payload.amount,
            currencyCode: payload.currencyCode,
            category: payload.category,
            spentAt: payload.spentAt,
            paymentMethod: payload.payment.method,
            paymentNetwork: payload.payment.network,
            paymentChannel: payload.payment.channel,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.expenseFormSaveError('$error'))),
      );
    }
  }

  Future<void> _openSmsExpenseScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SmsExpenseScreen(trip: _trip)),
    );
  }

  Future<void> _confirmDelete(Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.tripDetailsDeleteExpenseTitle),
          content: Text(l10n.tripDetailsDeleteExpenseMessage(expense.title)),
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

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(expenseControllerProvider(_trip.id).notifier)
          .deleteExpense(expense.id);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tripDetailsDeleteExpenseError('$error'))),
      );
    }
  }
}

class _TripDetailsContent extends StatefulWidget {
  const _TripDetailsContent({
    required this.trip,
    required this.expenses,
    required this.onAddExpense,
    required this.onAddViaSms,
    this.onFixDates,
    required this.onEditExpense,
    required this.onDeleteExpense,
  });

  final Trip trip;
  final List<Expense> expenses;
  final VoidCallback onAddExpense;
  final VoidCallback onAddViaSms;
  final VoidCallback? onFixDates;
  final ValueChanged<Expense> onEditExpense;
  final ValueChanged<Expense> onDeleteExpense;

  @override
  State<_TripDetailsContent> createState() => _TripDetailsContentState();
}

class _TripDetailsContentState extends State<_TripDetailsContent> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  _ExpenseSort _selectedSort = _ExpenseSort.newestFirst;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasExpenses = widget.expenses.isNotEmpty;
    final totalableExpenses = _totalableExpenses(widget.expenses);
    final total = totalableExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.transactionAmount,
    );
    final topCategory = _topCategory(widget.expenses);
    final filteredExpenses = _filteredAndSortedExpenses();
    final hasExcludedCurrencies =
        totalableExpenses.length != widget.expenses.length;
    final hasExpensesOutsideBaseCurrency =
      total == 0 && hasExcludedCurrencies && widget.expenses.isNotEmpty;
    final totalDisplayValue = hasExpensesOutsideBaseCurrency
      ? l10n.tripDetailsNoExpensesInBaseCurrency
      : _formatCurrency(total, widget.trip.baseCurrency);

    // SAR total: sum totalChargedAmount (fallback billedAmount) for international expenses
    final sarTotal = widget.expenses
        .where((e) => e.isInternational)
        .fold<double>(0, (sum, e) {
          final charged = e.totalChargedAmount ?? e.billedAmount;
          return sum + (charged ?? 0);
        });
    final hasSarTotal = sarTotal > 0;
    final listBottomPadding = MediaQuery.of(context).padding.bottom + 128;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final datesMissing = widget.trip.startDate == null || widget.trip.endDate == null;
    final dateRangeText = datesMissing ? null : _formatDateRangeText(widget.trip);

    if (!hasExpenses) {
      return NoExpensesPremiumState(
        isArabic: isArabic,
        tripName: widget.trip.name,
        baseCurrency: widget.trip.baseCurrency,
        datesMissing: datesMissing,
        dateRangeText: dateRangeText,
        onAddExpense: widget.onAddExpense,
        onAddViaSms: widget.onAddViaSms,
        onFixDates: widget.onFixDates,
        onDismissTip: null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ProviderScope.containerOf(
        context,
      ).read(expenseControllerProvider(widget.trip.id).notifier).reload(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, listBottomPadding),
        children: [
          _TripSummaryCard(trip: widget.trip),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l10n.tripDetailsTotalExpenses,
                  value: totalDisplayValue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: l10n.tripDetailsExpenseCount,
                  value: widget.expenses.length.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            label: l10n.tripDetailsTopCategory,
            value: topCategory == null
                ? l10n.tripDetailsTopCategoryNone
                : ExpenseOptionLabels.category(l10n, topCategory),
          ),
          if (hasSarTotal) ...[
            const SizedBox(height: 12),
            _StatCard(
              label: l10n.tripDetailsActuallyCharged,
              value: _formatCurrency(sarTotal, 'SAR'),
            ),
          ],
          if (hasExcludedCurrencies) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.tripDetailsExcludedCurrenciesWarning,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onAddViaSms,
                icon: const Icon(Icons.sms_rounded),
                label: Text(l10n.tripDetailsAddViaSms),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: l10n.tripDetailsSearchLabel,
                    hintText: l10n.tripDetailsSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _activeFilterCount > 0,
                label: Text('$_activeFilterCount'),
                child: IconButton.outlined(
                  tooltip: l10n.tripDetailsFiltersAndSort,
                  onPressed: () => _showFiltersBottomSheet(context),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l10n.tripDetailsExpensesSection,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (filteredExpenses.isEmpty)
            _EmptyFilteredState(
              message: l10n.tripDetailsNoMatchingExpenses,
              clearLabel: l10n.tripDetailsClearFilters,
              onClear: _clearFilters,
            )
          else
            ...filteredExpenses.map(
              (expense) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExpenseCard(
                  expense: expense,
                  onEdit: () => widget.onEditExpense(expense),
                  onDelete: () => widget.onDeleteExpense(expense),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount, String currencyCode) {
    return _formatAmountCurrencyLtr(amount, currencyCode);
  }

  String _formatDateRangeText(Trip trip) {
    final formatter = DateFormat('dd MMM yyyy', 'en');
    return '${formatter.format(trip.startDate!)} - ${formatter.format(trip.endDate!)}';
  }

  List<Expense> _totalableExpenses(List<Expense> expenses) {
    final baseCurrency = widget.trip.baseCurrency.trim().toUpperCase();
    final isDomesticTrip = baseCurrency == 'SAR';

    if (isDomesticTrip) {
      return expenses
          .where(
            (expense) =>
                expense.transactionCurrency.trim().toUpperCase() == 'SAR',
          )
          .toList();
    }

    // For international trips, avoid mixing currencies into one aggregate.
    return expenses
        .where(
          (expense) =>
              expense.transactionCurrency.trim().toUpperCase() == baseCurrency,
        )
        .toList();
  }

  List<Expense> _filteredAndSortedExpenses() {
    final filtered = widget.expenses.where((expense) {
      if (_selectedCategory != null && expense.category != _selectedCategory) {
        return false;
      }
      if (_selectedPaymentMethod != null &&
          expense.paymentMethod != _selectedPaymentMethod) {
        return false;
      }
      if (_searchQuery.isEmpty) {
        return true;
      }

      final haystack =
          '${expense.title} ${expense.note ?? ''} ${expense.rawSmsText ?? ''}'
              .toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();

    filtered.sort((a, b) {
      switch (_selectedSort) {
        case _ExpenseSort.newestFirst:
          return b.spentAt.compareTo(a.spentAt);
        case _ExpenseSort.oldestFirst:
          return a.spentAt.compareTo(b.spentAt);
        case _ExpenseSort.highestAmount:
          return b.transactionAmount.compareTo(a.transactionAmount);
        case _ExpenseSort.lowestAmount:
          return a.transactionAmount.compareTo(b.transactionAmount);
      }
    });

    return filtered;
  }

  String? _topCategory(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return null;
    }

    final totals = <String, double>{};
    for (final expense in expenses) {
      final category = expense.category ?? 'Other';
      totals.update(
        category,
        (value) => value + expense.transactionAmount,
        ifAbsent: () => expense.transactionAmount,
      );
    }

    var winner = totals.entries.first;
    for (final entry in totals.entries.skip(1)) {
      if (entry.value > winner.value) {
        winner = entry;
      }
    }

    return winner.key;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = null;
      _selectedPaymentMethod = null;
      _selectedSort = _ExpenseSort.newestFirst;
    });
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_selectedPaymentMethod != null) count++;
    if (_selectedSort != _ExpenseSort.newestFirst) count++;
    return count;
  }

  void _showFiltersBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    var localCategory = _selectedCategory;
    var localPaymentMethod = _selectedPaymentMethod;
    var localSort = _selectedSort;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    l10n.tripDetailsFiltersAndSort,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String?>(
                    initialValue: localCategory,
                    decoration: InputDecoration(
                      labelText: l10n.tripDetailsFilterCategory,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.tripDetailsAllCategories),
                      ),
                      ...ExpenseOptionLabels.categories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category,
                          child: Text(
                            ExpenseOptionLabels.category(l10n, category),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        localCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: localPaymentMethod,
                    decoration: InputDecoration(
                      labelText: l10n.tripDetailsFilterPaymentMethod,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.tripDetailsAllPaymentMethods),
                      ),
                      ...ExpenseOptionLabels.paymentMethods.map(
                        (pm) => DropdownMenuItem<String?>(
                          value: pm,
                          child: Text(
                            ExpenseOptionLabels.paymentMethod(l10n, pm),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        localPaymentMethod = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<_ExpenseSort>(
                    initialValue: localSort,
                    decoration: InputDecoration(
                      labelText: l10n.tripDetailsSortBy,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _ExpenseSort.newestFirst,
                        child: Text(l10n.tripDetailsSortNewest),
                      ),
                      DropdownMenuItem(
                        value: _ExpenseSort.oldestFirst,
                        child: Text(l10n.tripDetailsSortOldest),
                      ),
                      DropdownMenuItem(
                        value: _ExpenseSort.highestAmount,
                        child: Text(l10n.tripDetailsSortHighestAmount),
                      ),
                      DropdownMenuItem(
                        value: _ExpenseSort.lowestAmount,
                        child: Text(l10n.tripDetailsSortLowestAmount),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() {
                          localSort = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _clearFilters();
                            Navigator.of(sheetContext).pop();
                          },
                          child: Text(l10n.tripDetailsClearFilters),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = localCategory;
                              _selectedPaymentMethod = localPaymentMethod;
                              _selectedSort = localSort;
                            });
                            Navigator.of(sheetContext).pop();
                          },
                          child: Text(l10n.tripDetailsApplyFilters),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

enum _ExpenseSort { newestFirst, oldestFirst, highestAmount, lowestAmount }

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(trip.destination),
            const SizedBox(height: 8),
            Text(l10n.tripDetailsBaseCurrency(trip.baseCurrency)),
            const SizedBox(height: 8),
            Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Text(_formatDateRange(context, trip)),
            ),
            if (trip.budget != null && (trip.budget ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Text(l10n.tripDetailsBudget(_formatBudget(trip))),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateRange(BuildContext context, Trip trip) {
    final l10n = AppLocalizations.of(context)!;
    if (trip.startDate == null || trip.endDate == null) {
      return l10n.tripsDatesNeedAttention;
    }

    final formatter = DateFormat('dd MMM yyyy', 'en');
    return '${formatter.format(trip.startDate!)} - ${formatter.format(trip.endDate!)}';
  }

  String _formatBudget(Trip trip) {
    final budgetCurrency = trip.budgetCurrency ?? trip.baseCurrency;
    return _formatAmountCurrencyLtr(trip.budget ?? 0, budgetCurrency);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              value,
              textDirection: ui.TextDirection.ltr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Determine primary display amount: totalCharged > billed > transaction
    final bool useCharged = expense.totalChargedAmount != null;
    final bool useBilled =
        !useCharged && expense.billedAmount != null;
    final double primaryAmount = useCharged
        ? expense.totalChargedAmount!
        : useBilled
        ? expense.billedAmount!
        : expense.transactionAmount;
    final String primaryCurrency = useCharged
        ? (expense.totalChargedCurrency ?? expense.transactionCurrency)
        : useBilled
        ? (expense.billedCurrency ?? expense.transactionCurrency)
        : expense.transactionCurrency;
    final bool showSecondary =
        (useCharged || useBilled) &&
        expense.transactionCurrency.toUpperCase() !=
            primaryCurrency.toUpperCase();

    final dateFormatter = DateFormat(
      expense.spentAt.hour != 0 || expense.spentAt.minute != 0
          ? 'dd MMM yyyy • HH:mm'
          : 'dd MMM yyyy',
      Localizations.localeOf(context).toLanguageTag(),
    );

    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${ExpenseOptionLabels.category(l10n, expense.category ?? 'Other')} • ${ExpenseOptionLabels.paymentSummary(
                          l10n,
                          paymentMethodValue: expense.paymentMethod,
                          paymentNetworkValue: expense.paymentNetwork,
                          paymentChannelValue: expense.paymentChannel,
                        )}',
                      ),
                      const SizedBox(height: 6),
                      Text(dateFormatter.format(expense.spentAt)),
                      if (expense.note != null && expense.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          expense.note!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatAmountCurrencyLtr(primaryAmount, primaryCurrency),
                      textAlign: TextAlign.end,
                      textDirection: ui.TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (showSecondary) ...[
                      const SizedBox(height: 2),
                      Text(
                        '≈ ${_formatAmountCurrencyLtr(expense.transactionAmount, expense.transactionCurrency)}',
                        textAlign: TextAlign.end,
                        textDirection: ui.TextDirection.ltr,
                        style: mutedStyle,
                      ),
                    ],
                    if (expense.feesAmount != null &&
                        (expense.feesCurrency ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.intlFees}: ${_formatAmountCurrencyLtr(expense.feesAmount!, expense.feesCurrency ?? '')}',
                        textAlign: TextAlign.end,
                        textDirection: ui.TextDirection.ltr,
                        style: mutedStyle,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n.tripsEditTooltip,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: l10n.commonDelete,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NoExpensesPremiumState extends StatelessWidget {
  final bool isArabic;
  final String tripName;
  final String baseCurrency;
  final bool datesMissing;
  final String? dateRangeText;
  final VoidCallback onAddExpense;
  final VoidCallback onAddViaSms;
  final VoidCallback? onFixDates;
  final VoidCallback? onDismissTip;

  const NoExpensesPremiumState({
    super.key,
    required this.isArabic,
    required this.tripName,
    required this.baseCurrency,
    required this.datesMissing,
    required this.dateRangeText,
    required this.onAddExpense,
    required this.onAddViaSms,
    this.onFixDates,
    this.onDismissTip,
  });

  @override
  Widget build(BuildContext context) {
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          children: [
            _NoExpensesTripSummaryCard(
              isArabic: isArabic,
              tripName: tripName,
              baseCurrency: baseCurrency,
              datesMissing: datesMissing,
              dateRangeText: dateRangeText,
              onFixDates: onFixDates,
            ),
            const SizedBox(height: 22),
            _NoExpensesCard(
              isArabic: isArabic,
              onAddExpense: onAddExpense,
              onAddViaSms: onAddViaSms,
              onDismissTip: onDismissTip,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoExpensesTripSummaryCard extends StatelessWidget {
  final bool isArabic;
  final String tripName;
  final String baseCurrency;
  final bool datesMissing;
  final String? dateRangeText;
  final VoidCallback? onFixDates;

  const _NoExpensesTripSummaryCard({
    required this.isArabic,
    required this.tripName,
    required this.baseCurrency,
    required this.datesMissing,
    required this.dateRangeText,
    this.onFixDates,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/travel.png',
            width: 124,
            height: 124,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.flight_takeoff,
              size: 72,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      tripName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        isArabic ? 'نشطة' : 'Active',
                        style: const TextStyle(
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _NoExpensesInfoLine(
                  isArabic: isArabic,
                  icon: Icons.monetization_on_outlined,
                  label: isArabic ? 'العملة الأساسية' : 'Base currency',
                  trailing: baseCurrency,
                  trailingColor: const Color(0xFF00897B),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onFixDates,
                  child: _NoExpensesInfoLine(
                    isArabic: isArabic,
                    icon: Icons.calendar_month_outlined,
                    label: datesMissing
                        ? (isArabic
                            ? 'التواريخ تحتاج تحديد'
                            : 'Dates need attention')
                        : (dateRangeText ?? ''),
                    subtitle: datesMissing
                        ? (isArabic
                            ? 'حدد تاريخ البداية والنهاية'
                            : 'Set start and end dates')
                        : null,
                    trailingIcon: Icons.chevron_right,
                    labelColor: datesMissing
                        ? const Color(0xFFF97316)
                        : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoExpensesInfoLine extends StatelessWidget {
  final bool isArabic;
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? trailing;
  final IconData? trailingIcon;
  final Color? labelColor;
  final Color? trailingColor;

  const _NoExpensesInfoLine({
    required this.isArabic,
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.trailingIcon,
    this.labelColor,
    this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    final content = Expanded(
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: labelColor ?? const Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blueGrey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    return Row(
      children: isArabic
          ? [
              if (trailingIcon != null)
                Icon(trailingIcon, color: Colors.grey.shade400),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: trailingColor ?? const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              const SizedBox(width: 10),
              content,
              const SizedBox(width: 10),
              Icon(icon, size: 22, color: Colors.grey.shade700),
            ]
          : [
              Icon(icon, size: 22, color: Colors.grey.shade700),
              const SizedBox(width: 10),
              content,
              const SizedBox(width: 10),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: trailingColor ?? const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              if (trailingIcon != null)
                Icon(trailingIcon, color: Colors.grey.shade400),
            ],
    );
  }
}

class _NoExpensesCard extends StatefulWidget {
  final bool isArabic;
  final VoidCallback onAddExpense;
  final VoidCallback onAddViaSms;
  final VoidCallback? onDismissTip;

  const _NoExpensesCard({
    required this.isArabic,
    required this.onAddExpense,
    required this.onAddViaSms,
    this.onDismissTip,
  });

  @override
  State<_NoExpensesCard> createState() => _NoExpensesCardState();
}

class _NoExpensesCardState extends State<_NoExpensesCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeScale;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeScale = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.055),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          FadeTransition(
            opacity: _fadeScale,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(_fadeScale),
              child: Image.asset(
                'assets/FirstExpense.png',
                height: 170,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.noExpensesHeadline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              height: 1.25,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.noExpensesSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          _AnimatedCta(
            animController: _animController,
            child: _GradientActionButton(
              label: l.noExpensesAddFirst,
              icon: Icons.auto_awesome,
              onTap: widget.onAddExpense,
            ),
          ),
          const SizedBox(height: 20),
          _AnimatedCta(
            animController: _animController,
            child: _OutlineActionButton(
              label: l.noExpensesAddViaSms,
              icon: Icons.sms_outlined,
              onTap: widget.onAddViaSms,
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: isArabic
                  ? [
                      if (widget.onDismissTip != null)
                        GestureDetector(
                          onTap: widget.onDismissTip,
                          child: Icon(Icons.close, color: Colors.grey.shade400, size: 16),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              l.noExpensesTipLabel,
                              style: const TextStyle(
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l.noExpensesTipBody,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.blueGrey.shade500,
                                fontWeight: FontWeight.w500,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.lightbulb_outline,
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.7),
                        size: 18,
                      ),
                    ]
                  : [
                      Icon(
                        Icons.lightbulb_outline,
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.noExpensesTipLabel,
                              style: const TextStyle(
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l.noExpensesTipBody,
                              style: TextStyle(
                                color: Colors.blueGrey.shade500,
                                fontWeight: FontWeight.w500,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onDismissTip != null)
                        GestureDetector(
                          onTap: widget.onDismissTip,
                          child: Icon(Icons.close, color: Colors.grey.shade400, size: 16),
                        ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedCta extends StatelessWidget {
  final AnimationController animController;
  final Widget child;

  const _AnimatedCta({required this.animController, required this.child});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.98, end: 1.0).animate(
        CurvedAnimation(parent: animController, curve: Curves.easeOutCubic),
      ),
      child: child,
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.label,
    required this.icon,
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
          height: 58,
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
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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

class _OutlineActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xFF7C3AED)),
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF7C3AED),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: Color(0xFF7C3AED), width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFFF7F2FF),
      ),
    );
  }
}

class _EmptyFilteredState extends StatelessWidget {
  const _EmptyFilteredState({
    required this.message,
    required this.clearLabel,
    required this.onClear,
  });

  final String message;
  final String clearLabel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.filter_alt_off_rounded, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(clearLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddSheetResult {
  const _QuickAddSheetResult.moreDetails(_QuickAddDraftPayload value)
    : openMoreDetails = true,
      payload = null,
      draft = value;

  const _QuickAddSheetResult.submit(_QuickAddSubmitPayload value)
    : openMoreDetails = false,
      payload = value,
      draft = null;

  final bool openMoreDetails;
  final _QuickAddSubmitPayload? payload;
  final _QuickAddDraftPayload? draft;
}

class QuickAddExpenseSheet extends ConsumerStatefulWidget {
  const QuickAddExpenseSheet({super.key, required this.trip, required this.expenses});

  final Trip trip;
  final List<Expense> expenses;

  @override
  ConsumerState<QuickAddExpenseSheet> createState() =>
      _QuickAddExpenseSheetState();
}

class _QuickAddExpenseSheetState extends ConsumerState<QuickAddExpenseSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextInputFormatter _amountFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    final candidate = newValue.text;
    if (candidate.isEmpty) {
      return newValue;
    }

    final isValid = RegExp(r'^\d*\.?\d*$').hasMatch(candidate);
    return isValid ? newValue : oldValue;
  });

  String _selectedCategory = 'Other';
  String? _animatingCategory;
  bool _showValidationError = false;
  bool _userSelectedCategory = false;
  bool _isPrefilledFromMemory = false;
  Map<String, String> _amountCategoryMemory = {};

  static const String _prefsLastAmountKey = 'last_amount';
  static const String _prefsLastCategoryKey = 'last_category';
  static const String _prefsAmountMemoryKey = 'amount_memory';

  static const List<String> _quickCategories = <String>[
    'Food',
    'Transport',
    'Accommodation',
    'Shopping',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _userSelectedCategory = false;
    _loadPreferences();
  }

  String _amountRangeKey(double amount) {
    if (amount < 20) return '0-20';
    if (amount < 80) return '20-80';
    if (amount < 300) return '80-300';
    return '300+';
  }

  void _applyCategorySuggestion(double amount) {
    if (_userSelectedCategory) return;

    // Priority 2: learned memory
    final range = _amountRangeKey(amount);
    if (_applyAdaptiveMemorySuggestion(range)) {
      return;
    }

    // Priority 3: static fallback heuristic
    _applyHeuristicSuggestion(amount);
  }

  bool _applyAdaptiveMemorySuggestion(String rangeKey) {
    final rememberedCategory = _amountCategoryMemory[rangeKey];
    if (rememberedCategory == null) {
      return false;
    }
    _selectedCategory = rememberedCategory;
    return true;
  }

  void _applyHeuristicSuggestion(double amount) {
    if (amount < 20) {
      _selectedCategory = 'Food';
      return;
    }
    if (amount < 80) {
      _selectedCategory = 'Transport';
      return;
    }
    if (amount < 300) {
      _selectedCategory = 'Shopping';
      return;
    }
    _selectedCategory = 'Accommodation';
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAmount = prefs.getDouble(_prefsLastAmountKey);
    final lastCategory = prefs.getString(_prefsLastCategoryKey);
    final memoryData = prefs.getString(_prefsAmountMemoryKey);
    if (mounted) {
      setState(() {
        if (lastAmount != null) {
          _amountController.text = lastAmount.toStringAsFixed(2);
          _selectedCategory = lastCategory ?? 'Other';
          _isPrefilledFromMemory = true;
        } else {
          _selectedCategory = lastCategory ?? 'Other';
          _isPrefilledFromMemory = false;
        }
        if (memoryData != null) {
          _amountCategoryMemory = Map<String, String>.from(
            jsonDecode(memoryData) as Map,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.42;
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    final canSave = amount != null && amount > 0;

    final amountError = _showValidationError ? _validateAmount(l10n) : null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetHeight,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              cursorColor: const Color(0xFF0F172A),
              textInputAction: TextInputAction.done,
              inputFormatters: [_amountFormatter],
              onSubmitted: (_) => _save(),
              onChanged: (value) {
                setState(() {
                  _isPrefilledFromMemory = false;
                  final amount = double.tryParse(value);
                  if (amount != null) {
                    _applyCategorySuggestion(amount);
                  }
                });
              },
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: _isPrefilledFromMemory
                    ? const Color(0xFF64748B)
                    : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: _amountController.text.isEmpty ? '0.00' : '',
                hintStyle: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey.shade200,
                ),
                errorText: amountError,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _quickCategories.map((category) {
                final isSelected = _selectedCategory == category;
                final isAnimating = _animatingCategory == category;
                final selectedColor = _isPrefilledFromMemory && !_userSelectedCategory
                    ? const Color(0xFFA78BFA)
                    : const Color(0xFF7C3AED);
                return AnimatedScale(
                  scale: isAnimating ? 0.95 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPrefilledFromMemory = false;
                        _userSelectedCategory = true;
                        _selectedCategory = category;
                        _animatingCategory = category;
                      });
                      Future<void>.delayed(const Duration(milliseconds: 120), () {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          if (_animatingCategory == category) {
                            _animatingCategory = null;
                          }
                        });
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? selectedColor
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: selectedColor.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : const [],
                      ),
                      child: Text(
                        ExpenseOptionLabels.category(l10n, category),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Opacity(
                opacity: canSave ? 1.0 : 0.65,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: canSave ? _save : null,
                    child: Ink(
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 19),
                            const SizedBox(width: 8),
                            Text(
                              l10n.tripDetailsQuickAddSave,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // Save category memory for next time
                _savePreferences();

                Navigator.of(context).pop(
                  _QuickAddSheetResult.moreDetails(
                    _QuickAddDraftPayload(
                      amountText: _amountController.text,
                      category: _selectedCategory,
                      paymentMethod: _defaultQuickPayment.method,
                      currencyCode: widget.trip.baseCurrency.trim().toUpperCase(),
                      spentAt: DateTime.now(),
                    ),
                  ),
                );
              },
              child: Text(l10n.tripDetailsQuickAddMoreDetails),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateAmount(AppLocalizations l10n) {
    final value = _amountController.text.trim();
    if (value.isEmpty) {
      return l10n.commonRequiredField;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return l10n.commonEnterValidNumber;
    }
    if (parsed <= 0) {
      return l10n.expenseFormAmountPositive;
    }
    return null;
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _showValidationError = true;
    });

    final amountError = _validateAmount(l10n);
    if (amountError != null) {
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final now = DateTime.now();

    // Save category memory for next time
    _savePreferences(amount);

    Navigator.of(context).pop(
      _QuickAddSheetResult.submit(
        _QuickAddSubmitPayload(
          title: _selectedCategory,
          amount: amount,
          currencyCode: widget.trip.baseCurrency.trim().toUpperCase(),
          category: _selectedCategory,
          spentAt: now,
          payment: _defaultQuickPayment,
        ),
      ),
    );
  }

  Future<void> _savePreferences([double? amount]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastCategoryKey, _selectedCategory);
    if (amount != null) {
      await prefs.setDouble(_prefsLastAmountKey, amount);
      final range = _amountRangeKey(amount);
      _amountCategoryMemory[range] = _selectedCategory;
      await prefs.setString(_prefsAmountMemoryKey, jsonEncode(_amountCategoryMemory));
    }
  }
  static const _QuickAddPaymentData _defaultQuickPayment = _QuickAddPaymentData(
    method: 'Credit Card',
    network: 'Visa',
    channel: 'POS Purchase',
  );
}

class _QuickAddPaymentData {
  const _QuickAddPaymentData({
    required this.method,
    required this.network,
    required this.channel,
  });

  final String method;
  final String network;
  final String channel;
}

class _QuickAddSubmitPayload {
  const _QuickAddSubmitPayload({
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.spentAt,
    required this.payment,
  });

  final String title;
  final double amount;
  final String currencyCode;
  final String category;
  final DateTime spentAt;
  final _QuickAddPaymentData payment;
}

class _QuickAddDraftPayload {
  const _QuickAddDraftPayload({
    required this.amountText,
    required this.category,
    required this.paymentMethod,
    required this.currencyCode,
    required this.spentAt,
  });

  final String amountText;
  final String category;
  final String paymentMethod;
  final String currencyCode;
  final DateTime spentAt;
}
