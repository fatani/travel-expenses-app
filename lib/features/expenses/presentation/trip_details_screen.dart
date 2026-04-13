import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/providers/database_providers.dart';
import '../../sms_parser/presentation/sms_expense_screen.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/trip_form_screen.dart';
import '../domain/expense.dart';
import 'expense_controller.dart';
import 'expense_form_screen.dart';
import 'expense_option_labels.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(_trip.name),
        actions: [
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
          onAddExpense: () => _openExpenseForm(),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openExpenseForm,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.tripDetailsAddExpense),
      ),
    );
  }

  Future<void> _openTripEditor() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => TripFormScreen(trip: _trip)),
    );

    final refreshedTrip = await ref
        .read(tripRepositoryProvider)
        .getTripById(_trip.id);
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
    final baseCurrencyExpenses = _baseCurrencyExpenses(widget.expenses);
    final total = baseCurrencyExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final topCategory = _topCategory(widget.expenses);
    final filteredExpenses = _filteredAndSortedExpenses();
    final hasExcludedCurrencies =
        baseCurrencyExpenses.length != widget.expenses.length;

    return RefreshIndicator(
      onRefresh: () => ProviderScope.containerOf(
        context,
      ).read(expenseControllerProvider(widget.trip.id).notifier).reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TripSummaryCard(trip: widget.trip),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l10n.tripDetailsTotalExpenses,
                  value: _formatCurrency(total, widget.trip.baseCurrency),
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
              FilledButton.icon(
                onPressed: widget.onAddExpense,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.tripDetailsAddExpense),
              ),
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
          if (widget.expenses.isEmpty)
            _EmptyExpensesState(
              onAddExpense: widget.onAddExpense,
              onAddViaSms: widget.onAddViaSms,
            )
          else if (filteredExpenses.isEmpty)
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
    final formatter = NumberFormat.currency(
      name: currencyCode,
      symbol: '$currencyCode ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  List<Expense> _baseCurrencyExpenses(List<Expense> expenses) {
    final baseCurrency = widget.trip.baseCurrency.trim().toUpperCase();
    return expenses
        .where(
          (expense) => expense.currencyCode.trim().toUpperCase() == baseCurrency,
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
          return b.amount.compareTo(a.amount);
        case _ExpenseSort.lowestAmount:
          return a.amount.compareTo(b.amount);
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
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
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
            Text(_formatDateRange(context, trip)),
            if (trip.budget != null) ...[
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

    final localeName = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat('dd MMM yyyy', localeName);
    return '${formatter.format(trip.startDate!)} - ${formatter.format(trip.endDate!)}';
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
            Text(value, style: Theme.of(context).textTheme.titleLarge),
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
    final formatter = NumberFormat.currency(
      name: expense.currencyCode,
      symbol: '${expense.currencyCode} ',
      decimalDigits: 2,
    );
    final dateFormatter = DateFormat(
      expense.spentAt.hour != 0 || expense.spentAt.minute != 0
          ? 'dd MMM yyyy • HH:mm'
          : 'dd MMM yyyy',
      Localizations.localeOf(context).toLanguageTag(),
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
                Flexible(
                  child: Text(
                    formatter.format(expense.amount),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.tripDetailsEmptyExpensesTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tripDetailsEmptyExpensesMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.tripDetailsAddExpense),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAddViaSms,
              icon: const Icon(Icons.sms_rounded),
              label: Text(l10n.tripDetailsAddViaSms),
            ),
          ],
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
