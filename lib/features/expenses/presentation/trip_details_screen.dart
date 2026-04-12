import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/providers/database_providers.dart';
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

class _TripDetailsContent extends StatelessWidget {
  const _TripDetailsContent({
    required this.trip,
    required this.expenses,
    required this.onAddExpense,
    required this.onEditExpense,
    required this.onDeleteExpense,
  });

  final Trip trip;
  final List<Expense> expenses;
  final VoidCallback onAddExpense;
  final ValueChanged<Expense> onEditExpense;
  final ValueChanged<Expense> onDeleteExpense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return RefreshIndicator(
      onRefresh: () => ProviderScope.containerOf(
        context,
      ).read(expenseControllerProvider(trip.id).notifier).reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TripSummaryCard(trip: trip),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l10n.tripDetailsTotalExpenses,
                  value: _formatCurrency(total, trip.baseCurrency),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: l10n.tripDetailsExpenseCount,
                  value: expenses.length.toString(),
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
          if (expenses.isEmpty)
            _EmptyExpensesState(onAddExpense: onAddExpense)
          else
            ...expenses.map(
              (expense) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExpenseCard(
                  expense: expense,
                  onEdit: () => onEditExpense(expense),
                  onDelete: () => onDeleteExpense(expense),
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
}

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
      'dd MMM yyyy',
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
                        '${ExpenseOptionLabels.category(l10n, expense.category ?? 'Other')} • ${ExpenseOptionLabels.paymentMethod(l10n, expense.paymentMethod)}',
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
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
  const _EmptyExpensesState({required this.onAddExpense});

  final VoidCallback onAddExpense;

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
          ],
        ),
      ),
    );
  }
}
