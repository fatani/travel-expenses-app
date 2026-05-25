import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';
import '../../../core/design_system/app_confirmation_dialog.dart';
import '../../../core/design_system/calm_snackbar.dart';
import '../../../core/formatting/bidi_format.dart';
import '../../../core/formatting/expense_date_format.dart';
import '../../../core/formatting/trip_date_phrase.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/rtl_typography.dart';
import '../../export/presentation/export_menu.dart';
import '../../cash_wallet/presentation/trip_cash_wallet_screen.dart';
import '../../sms_parser/presentation/sms_expense_screen.dart';
import '../../reports/presentation/trip_reports_screen.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/trip_timeline_status.dart';
import '../../trips/domain/trip_title_resolver.dart';
import '../../trips/presentation/trip_form_screen.dart';
import '../domain/expense.dart';
import '../domain/expense_payment.dart';
import 'expense_controller.dart';
import 'expense_form_screen.dart';
import 'expense_option_labels.dart';
import 'quick_add_payment.dart';
import 'quick_add_recent_merchants.dart';

part 'quick_add_expense_sheet.dart';

class TripDetailsScreen extends ConsumerStatefulWidget {
  const TripDetailsScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends ConsumerState<TripDetailsScreen> {
  late Trip _trip;
  final Set<String> _pendingDeletionExpenseIds = <String>{};

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
        centerTitle: true,
        title: Text(
          TripTitleResolver.resolve(
            _trip,
            Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        actions: [
          _TopActionWrapper(
            child: _TripDetailsOverflowMenu(
              trip: _trip,
              hasExpenses: hasExpenses,
              onEditTrip: _openTripEditor,
              onOpenReports: _openTripReports,
              onOpenCashWallet: _openCashWallet,
              onAddViaSms: _openSmsExpenseScreen,
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
      floatingActionButton: expensesState.maybeWhen(
        data: (expenses) {
          final visibleExpenses = expenses
              .where((expense) => !_pendingDeletionExpenseIds.contains(expense.id))
              .toList(growable: false);
          return _CalmAddExpenseFab(
            onPressed: () => _openQuickAddSheet(visibleExpenses),
          );
        },
        orElse: () => null,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: expensesState.when(
        data: (expenses) {
          final visibleExpenses = expenses
              .where((expense) => !_pendingDeletionExpenseIds.contains(expense.id))
              .toList(growable: false);
          return _TripDetailsContent(
            trip: _trip,
            expenses: visibleExpenses,
            onFixDates: _openTripEditor,
            onEditExpense: (expense) => _openExpenseForm(expense: expense),
            onDeleteExpense: (expense) => _confirmDelete(expense),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.tripDetailsLoadError,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.tripDetailsExpensesLoadError,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
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
    );
  }

  @override
  void deactivate() {
    CalmSnackBar.clear(context);
    super.deactivate();
  }

  Future<void> _openTripEditor() async {
    CalmSnackBar.clear(context);
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
    String? initialTitle,
    String? initialAmount,
    String? initialCategory,
    String? initialPaymentMethod,
    String? initialCurrency,
    DateTime? initialSpentAt,
  }) async {
    CalmSnackBar.clear(context);
    final outcome = await Navigator.of(context).push<ExpenseCreateOutcome?>(
      MaterialPageRoute<ExpenseCreateOutcome?>(
        builder: (_) => ExpenseFormScreen(
          trip: _trip,
          expense: expense,
          initialTitle: initialTitle,
          initialAmount: initialAmount,
          initialCategory: initialCategory,
          initialPaymentMethod: initialPaymentMethod,
          initialCurrency: initialCurrency,
          initialSpentAt: initialSpentAt,
        ),
      ),
    );

    if (outcome != null) {
      _showSaveConfirmationWithUndo(outcome);
      return;
    }
    if (expense != null) {
      _showEditSaveConfirmationWithUndo(expense);
    }
  }

  Future<void> _openQuickAddSheet(List<Expense> expenses) async {
    CalmSnackBar.clear(context);
    final result = await showModalBottomSheet<_QuickAddSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
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

    CalmSnackBar.clear(context);

    if (result.openMoreDetails) {
      final draft = result.draft;
      await _openExpenseForm(
        initialTitle: draft?.title,
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
  }

  Future<void> _createQuickExpense(_QuickAddSubmitPayload payload) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final isCashQuickExpense = isCashExpensePayment(
        paymentMethod: payload.payment.method,
        paymentChannel: payload.payment.channel,
      );
      final outcome = await ref
          .read(expenseControllerProvider(_trip.id).notifier)
          .createExpense(
            title: payload.title,
            amount: payload.amount,
            currencyCode: payload.currencyCode,
            category: payload.category,
            spentAt: payload.spentAt,
            paymentMethod: payload.payment.method,
            paymentNetwork: isCashQuickExpense ? null : payload.payment.network,
            paymentChannel: payload.payment.channel,
            cardProfileId: payload.payment.cardProfileId,
            tripHomeCurrency: _trip.homeCurrencySnapshot,
          );

      if (!mounted) {
        return;
      }

      _showSaveConfirmationWithUndo(outcome);
    } catch (error) {
      if (!mounted) {
        return;
      }

      CalmSnackBar.showMessage(
        context,
        message: l10n.expenseFormSaveError('$error'),
      );
    }
  }

  Future<void> _openSmsExpenseScreen() async {
    CalmSnackBar.clear(context);
    final outcome = await Navigator.of(context).push<ExpenseCreateOutcome?>(
      MaterialPageRoute<ExpenseCreateOutcome?>(
        builder: (_) => SmsExpenseScreen(trip: _trip),
      ),
    );

    _showSaveConfirmationWithUndo(outcome);
  }

  Future<void> _openTripReports() async {
    CalmSnackBar.clear(context);
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TripReportsScreen(trip: _trip),
      ),
    );
  }

  void _showSaveConfirmationWithUndo(ExpenseCreateOutcome? outcome) {
    if (!mounted || outcome == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final createdExpenseId = outcome.createdExpenseId;
    CalmSnackBar.showMessage(
      context,
      message: l10n.tripDetailsQuickAddExpenseAdded,
      action: createdExpenseId == null
          ? null
          : SnackBarAction(
              label: l10n.commonUndo,
              onPressed: () {
                unawaited(_undoCreatedExpense(createdExpenseId));
              },
            ),
    );
  }

  Future<void> _undoCreatedExpense(String expenseId) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref.read(expenseControllerProvider(_trip.id).notifier).deleteExpense(expenseId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      CalmSnackBar.showMessage(
        context,
        message: l10n.tripDetailsDeleteExpenseError('$error'),
      );
    }
  }

  void _showEditSaveConfirmationWithUndo(Expense previousExpense) {
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    CalmSnackBar.showMessage(
      context,
      message: l10n.tripDetailsChangesSaved,
      action: SnackBarAction(
        label: l10n.commonUndo,
        onPressed: () {
          unawaited(_restorePreviousExpense(previousExpense));
        },
      ),
    );
  }

  Future<void> _restorePreviousExpense(Expense previousExpense) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref.read(expenseControllerProvider(_trip.id).notifier).updateExpense(
        expense: previousExpense,
        title: previousExpense.title,
        amount: previousExpense.amount,
        currencyCode: previousExpense.currencyCode,
        transactionAmount: previousExpense.transactionAmount,
        transactionCurrency: previousExpense.transactionCurrency,
        originalAmount: previousExpense.originalAmount,
        originalCurrency: previousExpense.originalCurrency,
        convertedHomeAmount: previousExpense.convertedHomeAmount,
        homeCurrency: previousExpense.homeCurrency,
        conversionRate: previousExpense.conversionRate,
        billedAmount: previousExpense.billedAmount,
        billedCurrency: previousExpense.billedCurrency,
        feesAmount: previousExpense.feesAmount,
        feesCurrency: previousExpense.feesCurrency,
        totalChargedAmount: previousExpense.totalChargedAmount,
        totalChargedCurrency: previousExpense.totalChargedCurrency,
        isInternational: previousExpense.isInternational,
        category: previousExpense.category ?? 'Other',
        spentAt: previousExpense.spentAt,
        paymentMethod: previousExpense.paymentMethod,
        paymentNetwork: previousExpense.paymentNetwork,
        paymentChannel: previousExpense.paymentChannel,
        source: previousExpense.source,
        note: previousExpense.note,
        rawSmsText: previousExpense.rawSmsText,
        cardProfileId: previousExpense.cardProfileId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      CalmSnackBar.showMessage(
        context,
        message: l10n.expenseFormSaveError('$error'),
      );
    }
  }

  Future<void> _openCashWallet() async {
    CalmSnackBar.clear(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TripCashWalletScreen(trip: _trip),
      ),
    );
  }

  Future<void> _confirmDelete(Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await showModalBottomSheet<bool>(
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
              icon: Icons.receipt_long_outlined,
              title: l10n.tripDetailsDeleteExpenseTitle,
              message: l10n.tripDetailsDeleteExpenseMessage(expense.title),
              cancelLabel: l10n.commonCancel,
              confirmLabel: l10n.commonDelete,
              onCancel: () => Navigator.of(sheetContext).pop(false),
              onConfirm: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    if (_pendingDeletionExpenseIds.contains(expense.id)) {
      return;
    }

    setState(() {
      _pendingDeletionExpenseIds.add(expense.id);
    });

    var undone = false;
    await CalmSnackBar.showUndo(
      context,
      message: l10n.tripDetailsExpenseDeleted,
      undoLabel: l10n.commonUndo,
      onUndo: () {
        undone = true;
        if (!mounted) {
          return;
        }
        setState(() {
          _pendingDeletionExpenseIds.remove(expense.id);
        });
      },
    );

    if (undone || !mounted) {
      return;
    }

    try {
      await ref
          .read(expenseControllerProvider(_trip.id).notifier)
          .deleteExpense(expense.id);

      if (!mounted) {
        return;
      }
      setState(() {
        _pendingDeletionExpenseIds.remove(expense.id);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingDeletionExpenseIds.remove(expense.id);
      });

      CalmSnackBar.showMessage(
        context,
        message: l10n.tripDetailsDeleteExpenseError('$error'),
      );
    }
  }
}

class _TripDetailsContent extends StatefulWidget {
  const _TripDetailsContent({
    required this.trip,
    required this.expenses,
    this.onFixDates,
    required this.onEditExpense,
    required this.onDeleteExpense,
  });

  final Trip trip;
  final List<Expense> expenses;
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
    final filteredExpenses = hasExpenses ? _filteredAndSortedExpenses() : const <Expense>[];
    final subtleTotalLine = hasExpenses ? _buildSubtleTotalLine(l10n) : null;
    final listBottomPadding = MediaQuery.of(context).padding.bottom + 96;
    final showSearch = widget.expenses.length >= 5;

    return RefreshIndicator(
      onRefresh: () => ProviderScope.containerOf(
        context,
      ).read(expenseControllerProvider(widget.trip.id).notifier).reload(),
      child: ListView(
        cacheExtent: 10000,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          listBottomPadding,
        ),
        children: [
          _TripContextStrip(
            trip: widget.trip,
            subtleTotalLine: subtleTotalLine,
            onFixDates: widget.onFixDates,
          ),
          if (!hasExpenses) ...[
            const SizedBox(height: AppSpacing.lg),
            _TripDetailsEmptyState(title: l10n.tripDetailsEmptyExpensesTitle),
          ] else ...[
            if (showSearch) ...[
              const SizedBox(height: AppSpacing.sm),
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
                        hintText: l10n.tripDetailsSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs + 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Badge(
                    isLabelVisible: _activeFilterCount > 0,
                    label: Text('$_activeFilterCount'),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.tripDetailsFiltersAndSort,
                      onPressed: () => _showFiltersBottomSheet(context),
                      icon: const Icon(Icons.tune_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (filteredExpenses.isEmpty)
              _EmptyFilteredState(
                message: l10n.tripDetailsNoMatchingExpenses,
                clearLabel: l10n.tripDetailsClearFilters,
                onClear: _clearFilters,
              )
            else
              ...filteredExpenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ExpenseCard(
                    expense: expense,
                    tripHomeCurrency: widget.trip.homeCurrencySnapshot,
                    onEdit: () => widget.onEditExpense(expense),
                    onDelete: () => widget.onDeleteExpense(expense),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String? _buildSubtleTotalLine(AppLocalizations l10n) {
    if (_hasMultipleTransactionCurrencies(widget.expenses)) {
      return null;
    }

    final totalableExpenses = _totalableExpenses(widget.expenses);
    if (totalableExpenses.isEmpty) {
      return null;
    }

    final total = totalableExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.transactionAmount,
    );
    final baseCurrency = widget.trip.baseCurrency.trim().toUpperCase();
    if (total <= 0) {
      return null;
    }

    return '${l10n.tripDetailsTotalInCurrencyOnly(baseCurrency)}: ${_formatCurrency(total, baseCurrency)}';
  }

  String _formatCurrency(double amount, String currencyCode) {
    return BidiAmountFormat.ltrIsolate(amount, currencyCode);
  }

  List<Expense> _totalableExpenses(List<Expense> expenses) {
    final baseCurrency = widget.trip.baseCurrency.trim().toUpperCase();

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

  bool _hasMultipleTransactionCurrencies(List<Expense> expenses) {
    final currencies = <String>{};
    for (final expense in expenses) {
      final currency = expense.transactionCurrency.trim().toUpperCase();
      if (currency.isEmpty) {
        continue;
      }
      currencies.add(currency);
      if (currencies.length > 1) {
        return true;
      }
    }
    return false;
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

class _TripContextStrip extends StatelessWidget {
  const _TripContextStrip({
    required this.trip,
    this.subtleTotalLine,
    this.onFixDates,
  });

  final Trip trip;
  final String? subtleTotalLine;
  final VoidCallback? onFixDates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final status = _TripTimelineStatusChip.resolve(l10n, trip);
    final datesMissing = trip.startDate == null || trip.endDate == null;
    final title = TripTitleResolver.resolve(trip, isArabic);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        onTap: datesMissing ? onFixDates : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: RtlTypography.titleWeight(isArabic),
                                  height: RtlTypography.titleLineHeight(isArabic),
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _TripTimelineStatusChip(status: status),
                      ],
                    ),
                    if (datesMissing)
                      Text(
                        l10n.tripsDatesNeedAttention,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.tertiary,
                              fontSize: 12,
                              height: RtlTypography.bodyLineHeight(isArabic),
                            ),
                      )
                    else
                      LtrText(
                        data: TripDatePhrase.forContextStrip(
                          trip: trip,
                          localeName: Localizations.localeOf(context).toLanguageTag(),
                          l10n: l10n,
                          isArabic: isArabic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              height: RtlTypography.bodyLineHeight(isArabic),
                            ),
                      ),
                    if (subtleTotalLine != null)
                      Text(
                        subtleTotalLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                              fontSize: 11,
                              height: RtlTypography.bodyLineHeight(isArabic),
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

}

class _TripTimelineStatusChip extends StatelessWidget {
  const _TripTimelineStatusChip({required this.status});

  final ({String label, Color background, Color foreground}) status;

  static ({String label, Color background, Color foreground}) resolve(
    AppLocalizations l10n,
    Trip trip,
  ) {
    return switch (resolveTripTimelineStatus(trip)) {
      TripTimelineStatus.datesPending => (
        label: l10n.tripTimelineDatesPending,
        background: const Color(0xFFFFEDD5),
        foreground: const Color(0xFF9A3412),
      ),
      TripTimelineStatus.upcoming => (
        label: l10n.tripTimelineUpcoming,
        background: const Color(0xFFDBEAFE),
        foreground: const Color(0xFF1D4ED8),
      ),
      TripTimelineStatus.active => (
        label: l10n.tripTimelineActive,
        background: const Color(0xFFDCFCE7),
        foreground: const Color(0xFF166534),
      ),
      TripTimelineStatus.completed => (
        label: l10n.tripTimelineCompleted,
        background: const Color(0xFFE2E8F0),
        foreground: const Color(0xFF475569),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.foreground,
          fontWeight: RtlTypography.chipWeight(
            Localizations.localeOf(context).languageCode == 'ar',
          ),
          fontSize: 11,
          height: RtlTypography.chipLineHeight(
            Localizations.localeOf(context).languageCode == 'ar',
          ),
        ),
      ),
    );
  }
}

class _TripDetailsEmptyState extends StatelessWidget {
  const _TripDetailsEmptyState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

enum _ExpenseCardAction { delete }

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.tripHomeCurrency,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final String tripHomeCurrency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    // Primary display is always the real travel-country transaction amount.
    final double primaryAmount = expense.transactionAmount;
    final String primaryCurrency = expense.transactionCurrency;
    final originalAmount = expense.originalAmount ?? expense.transactionAmount;
    final originalCurrency = expense.originalCurrency ?? expense.transactionCurrency;
    final normalizedTripHomeCurrency = tripHomeCurrency.trim().toUpperCase();
    final normalizedStoredHomeCurrency = _normalizeCurrency(expense.homeCurrency);
    final storedRate = expense.conversionRate;
    final storedOriginalAmount = expense.originalAmount;

    final double? displayedConvertedHomeAmount;
    final String? displayedHomeCurrency;

    if (expense.convertedHomeAmount != null) {
      displayedConvertedHomeAmount = expense.convertedHomeAmount;
      displayedHomeCurrency =
          normalizedStoredHomeCurrency ??
          (storedRate != null ? normalizedTripHomeCurrency : null);
    } else {
      final fallbackHomeCurrency =
          normalizedStoredHomeCurrency ?? normalizedTripHomeCurrency;
      final canUseStoredRateFallback =
          storedRate != null &&
          storedRate > 0 &&
          fallbackHomeCurrency.isNotEmpty &&
          originalCurrency.trim().toUpperCase() != fallbackHomeCurrency;

      if (canUseStoredRateFallback) {
        // Legacy data path: when converted amount is missing, trust persisted
        // conversion snapshots only — never derive from cash wallet history.
        final baseAmount =
            (storedOriginalAmount != null && storedOriginalAmount > 0)
                ? storedOriginalAmount
                : originalAmount;
        displayedConvertedHomeAmount = baseAmount * storedRate;
        displayedHomeCurrency = fallbackHomeCurrency;
      } else {
        displayedConvertedHomeAmount = null;
        displayedHomeCurrency = null;
      }
    }

    final normalizedHomeCurrency = displayedHomeCurrency?.trim().toUpperCase() ?? '';
    final normalizedOriginalCurrency = originalCurrency.trim().toUpperCase();
    final hasHomeConversion =
        displayedConvertedHomeAmount != null &&
        normalizedHomeCurrency.isNotEmpty &&
        normalizedOriginalCurrency.isNotEmpty &&
        normalizedOriginalCurrency != normalizedHomeCurrency;

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final isArabic = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final dateText = ExpenseDateFormat.cardDate(expense.spentAt, localeTag);
    final timeText = ExpenseDateFormat.cardTime(
      expense.spentAt,
      localeTag,
      isArabic: isArabic,
    );

    final secondaryStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          height: RtlTypography.bodyLineHeight(isArabic),
        );
    final subtleStyle = secondaryStyle?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      fontSize: 11,
    );
    final timeStyle = subtleStyle?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.58),
      fontSize: 10,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm + 2,
                    AppSpacing.xs,
                    AppSpacing.sm + 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              expense.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: RtlTypography.titleWeight(isArabic),
                                    color: const Color(0xFF0F172A),
                                    height: RtlTypography.titleLineHeight(isArabic),
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _PrimaryAmountDisplay(
                            amount: primaryAmount,
                            currency: primaryCurrency,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${ExpenseOptionLabels.category(l10n, expense.category ?? 'Other')} · ${ExpenseOptionLabels.paymentSummary(
                                l10n,
                                paymentMethodValue: expense.paymentMethod,
                                paymentNetworkValue: expense.paymentNetwork,
                                paymentChannelValue: expense.paymentChannel,
                              )}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection:
                                  isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                              style: secondaryStyle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              LtrText(
                                data: dateText,
                                style: secondaryStyle,
                              ),
                              if (timeText.isNotEmpty)
                                LtrText(
                                  data: timeText,
                                  style: timeStyle,
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (hasHomeConversion) ...[
                        const SizedBox(height: 2),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: LtrText(
                            data: BidiAmountFormat.formatApproximate(
                              displayedConvertedHomeAmount,
                              normalizedHomeCurrency,
                            ),
                            style: subtleStyle,
                          ),
                        ),
                      ],
                      if (expense.note != null && expense.note!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          expense.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection:
                              isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                          style: subtleStyle,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2, end: 2),
            child: PopupMenuButton<_ExpenseCardAction>(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              onSelected: (action) {
                if (action == _ExpenseCardAction.delete) {
                  onDelete();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _ExpenseCardAction.delete,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: scheme.error.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(l10n.commonDelete),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _normalizeCurrency(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.toUpperCase();
  }
}

class _PrimaryAmountDisplay extends StatelessWidget {
  const _PrimaryAmountDisplay({
    required this.amount,
    required this.currency,
  });

  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerEnd,
        child: Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                BidiAmountFormat.formatNumber(amount),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: RtlTypography.amountWeight(
                        Localizations.localeOf(context).languageCode == 'ar',
                      ),
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.1,
                      height: RtlTypography.amountLineHeight(
                        Localizations.localeOf(context).languageCode == 'ar',
                      ),
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                currency.trim().toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: const Color(0xFF334155),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


enum _TripDetailsOverflowAction {
  editTrip,
  reports,
  cashWallet,
  smsImport,
  exportCsv,
  exportPdf,
}

class _TripDetailsOverflowMenu extends ConsumerWidget {
  const _TripDetailsOverflowMenu({
    required this.trip,
    required this.hasExpenses,
    required this.onEditTrip,
    required this.onOpenReports,
    required this.onOpenCashWallet,
    required this.onAddViaSms,
  });

  final Trip trip;
  final bool hasExpenses;
  final VoidCallback onEditTrip;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenCashWallet;
  final VoidCallback onAddViaSms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<_TripDetailsOverflowAction>(
      tooltip: l10n.tripDetailsExportTooltip,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _TripDetailsOverflowAction.editTrip:
            onEditTrip();
          case _TripDetailsOverflowAction.reports:
            onOpenReports();
          case _TripDetailsOverflowAction.cashWallet:
            onOpenCashWallet();
          case _TripDetailsOverflowAction.smsImport:
            onAddViaSms();
          case _TripDetailsOverflowAction.exportCsv:
            unawaited(
              handleTripExport(
                context,
                ref,
                trip: trip,
                format: TripExportFormat.csv,
              ),
            );
          case _TripDetailsOverflowAction.exportPdf:
            unawaited(
              handleTripExport(
                context,
                ref,
                trip: trip,
                format: TripExportFormat.pdf,
              ),
            );
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _TripDetailsOverflowAction.editTrip,
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.tripDetailsEditTripTooltip),
            ],
          ),
        ),
        PopupMenuItem(
          value: _TripDetailsOverflowAction.reports,
          child: Row(
            children: [
              const Icon(Icons.bar_chart_outlined, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.tripDetailsReportTooltip),
            ],
          ),
        ),
        PopupMenuItem(
          value: _TripDetailsOverflowAction.cashWallet,
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.tripDetailsCashWalletAction),
            ],
          ),
        ),
        if (hasExpenses) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _TripDetailsOverflowAction.smsImport,
            child: Row(
              children: [
                const Icon(Icons.sms_outlined, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(l10n.tripDetailsAddViaSms),
                ),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: hasExpenses,
          value: _TripDetailsOverflowAction.exportCsv,
          child: Text(l10n.exportMenuCsv),
        ),
        PopupMenuItem(
          enabled: hasExpenses,
          value: _TripDetailsOverflowAction.exportPdf,
          child: Text(l10n.exportMenuPdf),
        ),
      ],
      child: const _TopActionIcon(icon: Icons.more_horiz_rounded),
    );
  }
}

class _CalmAddExpenseFab extends StatelessWidget {
  const _CalmAddExpenseFab({required this.onPressed});

  final VoidCallback onPressed;

  static const double _size = 67;
  static const double _iconSize = 34;
  static const Color _fabColor = AppColors.primaryDeep;

  static final List<BoxShadow> _premiumShadow = [
    BoxShadow(
      color: _fabColor.withValues(alpha: 0.12),
      blurRadius: 14,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.xs,
        bottom: AppSpacing.md,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            sizeConstraints: const BoxConstraints.tightFor(
              width: _size,
              height: _size,
            ),
            elevation: 0,
            highlightElevation: 0,
            shape: const CircleBorder(),
            backgroundColor: _fabColor,
            foregroundColor: Colors.white,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _premiumShadow,
          ),
          child: FloatingActionButton(
            onPressed: onPressed,
            tooltip: l10n.tripDetailsAddExpense,
            elevation: 0,
            highlightElevation: 0,
            backgroundColor: _fabColor,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded, size: _iconSize),
          ),
        ),
      ),
    );
  }
}

class _TopActionWrapper extends StatelessWidget {
  const _TopActionWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: child,
    );
  }
}

class _TopActionIcon extends StatelessWidget {
  const _TopActionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
      ),
      child: Icon(icon, color: const Color(0xFF0F172A), size: 20),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(onPressed: onClear, child: Text(clearLabel)),
        ],
      ),
    );
  }
}
