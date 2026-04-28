import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => TripFormScreen(trip: _trip)),
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

  Future<void> _openExpenseForm({Expense? expense}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseFormScreen(trip: _trip, expense: expense),
      ),
    );
  }

  Future<void> _openQuickAddSheet(List<Expense> expenses) async {
    final result = await showModalBottomSheet<_QuickAddSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: _QuickAddExpenseSheet(
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
      await _openExpenseForm();
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
    required this.onEditExpense,
    required this.onDeleteExpense,
  });

  final Trip trip;
  final List<Expense> expenses;
  final VoidCallback onAddExpense;
  final VoidCallback onAddViaSms;
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

    if (!hasExpenses) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _TripSummaryCard(trip: widget.trip),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: _EmptyExpensesState(
                  onAddExpense: widget.onAddExpense,
                  onAddViaSms: widget.onAddViaSms,
                ),
              ),
            ),
          ],
        ),
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

class _EmptyExpensesState extends StatelessWidget {
  const _EmptyExpensesState({
    required this.onAddExpense,
    required this.onAddViaSms,
  });

  final VoidCallback onAddExpense;
  final VoidCallback onAddViaSms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 40,
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.tripDetailsEmptyExpensesTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tripDetailsEmptyExpensesMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAddExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.tripDetailsAddExpense),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddViaSms,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(l10n.tripDetailsAddViaSms),
                ),
              ),
            ],
          ),
        ),
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
  const _QuickAddSheetResult.moreDetails()
    : openMoreDetails = true,
      payload = null;

  const _QuickAddSheetResult.submit(_QuickAddSubmitPayload value)
    : openMoreDetails = false,
      payload = value;

  final bool openMoreDetails;
  final _QuickAddSubmitPayload? payload;
}

class _QuickAddExpenseSheet extends ConsumerStatefulWidget {
  const _QuickAddExpenseSheet({required this.trip, required this.expenses});

  final Trip trip;
  final List<Expense> expenses;

  @override
  ConsumerState<_QuickAddExpenseSheet> createState() =>
      _QuickAddExpenseSheetState();
}

class _QuickAddExpenseSheetState extends ConsumerState<_QuickAddExpenseSheet> {
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

  late String _selectedCategory;
  late String _selectedPayment;
  late final List<_RecentMerchant> _recentMerchants;
  String? _selectedMerchantTitle;
  bool _didChangeCategory = false;
  bool _didChangePayment = false;
  bool _showValidationError = false;

  static const List<String> _quickCategories = <String>[
    'Food',
    'Transport',
    'Accommodation',
    'Shopping',
    'Entertainment',
    'Other',
  ];

  static const List<String> _quickPayments = <String>['Cash', 'Card', 'Wallet'];

  @override
  void initState() {
    super.initState();

    final defaults = _deriveDefaults(widget.expenses);
    _recentMerchants = _deriveRecentMerchants(widget.expenses);
    _selectedCategory = defaults.category;
    _selectedPayment = defaults.payment;
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

    final amountError = _showValidationError ? _validateAmount(l10n) : null;
    final currencyCode = widget.trip.baseCurrency.trim().toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.tripDetailsAddExpense,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  autofocus: true,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  textInputAction: TextInputAction.done,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_amountFormatter],
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: l10n.expenseFormAmountLabel,
                    hintText: l10n.expenseFormAmountHint,
                    errorText: amountError,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  currencyCode,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.expenseFormCategoryLabel,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickCategories.map((category) {
              final isSelected = _selectedCategory == category;
              final selectedAlpha = _didChangeCategory ? 0.22 : 0.10;
              final selectedBorderAlpha = _didChangeCategory ? 0.45 : 0.25;
              return ChoiceChip(
                showCheckmark: false,
                label: Text(ExpenseOptionLabels.category(l10n, category)),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                selectedColor: theme.colorScheme.primary.withValues(
                  alpha: selectedAlpha,
                ),
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(
                          alpha: selectedBorderAlpha,
                        )
                      : theme.colorScheme.outlineVariant,
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    if (_selectedCategory != category) {
                      _didChangeCategory = true;
                    }
                    _selectedCategory = category;
                  });
                },
              );
            }).toList(),
          ),
          if (_recentMerchants.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.tripDetailsQuickAddRecentMerchants,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _recentMerchants.map((merchant) {
                  final isSelected = _selectedMerchantTitle == merchant.title;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      showCheckmark: false,
                      selected: isSelected,
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          merchant.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      selectedColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      backgroundColor: theme.colorScheme.surface,
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.35)
                            : theme.colorScheme.outlineVariant,
                      ),
                      onSelected: (_) => _applyRecentMerchant(merchant),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.expenseFormPaymentMethodLabel,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickPayments.map((payment) {
              final isSelected = _selectedPayment == payment;
              final selectedAlpha = _didChangePayment ? 0.22 : 0.10;
              final selectedBorderAlpha = _didChangePayment ? 0.45 : 0.25;
              return ChoiceChip(
                showCheckmark: false,
                label: Text(_paymentLabel(l10n, payment)),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                selectedColor: theme.colorScheme.primary.withValues(
                  alpha: selectedAlpha,
                ),
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(
                          alpha: selectedBorderAlpha,
                        )
                      : theme.colorScheme.outlineVariant,
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    if (_selectedPayment != payment) {
                      _didChangePayment = true;
                    }
                    _selectedPayment = payment;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _QuickAddSheetResult.moreDetails()),
                child: Text(l10n.tripDetailsQuickAddMoreDetails),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(l10n.tripDetailsQuickAddSave),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 2 : 0),
        ],
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
    final paymentData = _mapQuickPaymentToSavedFields(_selectedPayment);
    final merchantTitle = _selectedMerchantTitle?.trim();
    final title = merchantTitle == null || merchantTitle.isEmpty
      ? _selectedCategory
      : merchantTitle;

    Navigator.of(context).pop(
      _QuickAddSheetResult.submit(
        _QuickAddSubmitPayload(
          title: title,
          amount: amount,
          currencyCode: widget.trip.baseCurrency.trim().toUpperCase(),
          category: _selectedCategory,
          spentAt: now,
          payment: paymentData,
        ),
      ),
    );
  }

  String _paymentLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Cash':
        return l10n.tripDetailsQuickAddPaymentCash;
      case 'Wallet':
        return l10n.tripDetailsQuickAddPaymentWallet;
      default:
        return l10n.tripDetailsQuickAddPaymentCard;
    }
  }

  _QuickAddDefaultCategoryPayment _deriveDefaults(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const _QuickAddDefaultCategoryPayment(
        category: 'Food',
        payment: 'Card',
      );
    }

    final latest = expenses.first;
    final category = _quickCategories.contains(latest.category)
        ? latest.category!
        : 'Food';

    final payment = _inferQuickPayment(latest);

    return _QuickAddDefaultCategoryPayment(
      category: category,
      payment: payment,
    );
  }

  List<_RecentMerchant> _deriveRecentMerchants(
    List<Expense> expenses, {
    int limit = 8,
  }) {
    final sortedExpenses = [...expenses]..sort((a, b) {
      final spentAtComparison = b.spentAt.compareTo(a.spentAt);
      if (spentAtComparison != 0) {
        return spentAtComparison;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    final seen = <String>{};
    final recentMerchants = <_RecentMerchant>[];

    for (final expense in sortedExpenses) {
      final title = expense.title.trim();
      if (!_isMerchantLikeTitle(title)) {
        continue;
      }

      final key = title.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }

      final category = expense.category?.trim();
      recentMerchants.add(
        _RecentMerchant(
          title: title,
          category: category == null || category.isEmpty ? null : category,
        ),
      );

      if (recentMerchants.length >= limit) {
        break;
      }
    }

    return recentMerchants;
  }

  bool _isMerchantLikeTitle(String title) {
    final normalized = title.trim().toLowerCase();
    if (normalized.length < 3) {
      return false;
    }

    final categoryNames = _quickCategories
        .map((category) => category.toLowerCase())
        .toSet();
    if (categoryNames.contains(normalized)) {
      return false;
    }

    final cleaned = normalized
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length < 3) {
      return false;
    }

    const genericTitles = <String>{
      'expense',
      'expenses',
      'purchase',
      'payment',
      'transaction',
      'charge',
      'item',
      'misc',
      'other',
      'general',
      'unknown',
      'cost',
    };

    return !genericTitles.contains(cleaned);
  }

  void _applyRecentMerchant(_RecentMerchant merchant) {
    setState(() {
      _selectedMerchantTitle = merchant.title;
      final merchantCategory = merchant.category;
      if (
          merchantCategory != null &&
          _quickCategories.contains(merchantCategory)) {
        if (_selectedCategory != merchantCategory) {
          _didChangeCategory = true;
        }
        _selectedCategory = merchantCategory;
      }
    });
  }

  String _inferQuickPayment(Expense latest) {
    final method = latest.paymentMethod;
    if (method == 'Cash') {
      return 'Cash';
    }
    if (method == 'Mobile Wallet') {
      return 'Wallet';
    }
    return 'Card';
  }

  _QuickAddPaymentData _mapQuickPaymentToSavedFields(String payment) {
    switch (payment) {
      case 'Cash':
        return const _QuickAddPaymentData(
          method: 'Cash',
          network: 'Other',
          channel: 'Other',
        );
      case 'Wallet':
        return const _QuickAddPaymentData(
          method: 'Mobile Wallet',
          network: 'Other',
          channel: 'Other',
        );
      default:
        return const _QuickAddPaymentData(
          method: 'Credit Card',
          network: 'Visa',
          channel: 'POS Purchase',
        );
    }
  }
}

class _QuickAddDefaultCategoryPayment {
  const _QuickAddDefaultCategoryPayment({
    required this.category,
    required this.payment,
  });

  final String category;
  final String payment;
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

class _RecentMerchant {
  const _RecentMerchant({required this.title, required this.category});

  final String title;
  final String? category;
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
