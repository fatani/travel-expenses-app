import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';
import '../../../core/design_system/app_confirmation_dialog.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../export/presentation/export_menu.dart';
import '../../cash_wallet/domain/trip_cash_balance.dart';
import '../../cash_wallet/domain/cash_transaction.dart';
import '../../cash_wallet/presentation/trip_cash_wallet_screen.dart';
import '../../exchange_rates/presentation/trip_exchange_rates_screen.dart';
import '../../sms_parser/presentation/sms_expense_screen.dart';
import '../../reports/presentation/trip_reports_screen.dart';
import '../../settings/domain/card_profile.dart';
import '../../settings/presentation/cards_provider.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/trip_timeline_status.dart';
import '../../trips/domain/trip_title_resolver.dart';
import '../../trips/presentation/trip_form_screen.dart';
import '../domain/expense.dart';
import '../domain/expense_payment.dart';
import 'expense_controller.dart';
import 'expense_form_screen.dart';
import 'expense_option_labels.dart';

part 'quick_add_expense_sheet.dart';

String _formatAmountCurrency(double amount, String currencyCode) {
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  final formatter = NumberFormat('#,##0.##', 'en');
  return '${formatter.format(amount)} $normalizedCurrency';
}

String _formatAmountNumber(double amount) {
  final formatter = NumberFormat('#,##0.##', 'en');
  return formatter.format(amount);
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
  int _cashWalletVersion = 0;
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
              onOpenReports: _openTripReports,
              onAddViaSms: _openSmsExpenseScreen,
            ),
          ),
          _TopActionWrapper(
            child: _TopActionIconButton(
              tooltip: l10n.tripDetailsEditTripTooltip,
              onPressed: _openTripEditor,
              icon: Icons.edit_outlined,
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
          if (visibleExpenses.isEmpty) {
            return null;
          }
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
            cashWalletVersion: _cashWalletVersion,
            onAddExpense: () => _openQuickAddSheet(visibleExpenses),
            onRepeatLast: visibleExpenses.isEmpty
                ? null
                : () => _openQuickAddSheet(
                      visibleExpenses,
                      repeat: true,
                      lastExpense: visibleExpenses.last,
                    ),
            onOpenCashWallet: _openCashWallet,
            onOpenExchangeRates: _openExchangeRates,
            onAddViaSms: _openSmsExpenseScreen,
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

  void _clearSnackBars() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.clearSnackBars();
  }

  void _showLocalSnackBar(SnackBar snackBar) {
    _clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void deactivate() {
    // Clear any lingering snackbars when navigating away from this screen.
    ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..clearSnackBars();
    super.deactivate();
  }

  Future<void> _openTripEditor() async {
    _clearSnackBars();
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
    _clearSnackBars();
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

    _showCashGuidanceIfNeeded(outcome);
    if (outcome != null) {
      _showSaveConfirmationWithUndo(outcome);
      return;
    }
    if (expense != null) {
      _showEditSaveConfirmationWithUndo(expense);
    }
  }

  Future<void> _openQuickAddSheet(
    List<Expense> expenses, {
    bool repeat = false,
    Expense? lastExpense,
    String? repeatCategory,
    String? repeatPaymentChipKey,
  }) async {
    _clearSnackBars();
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
            repeatLast: repeat,
            lastExpense: lastExpense,
            repeatCategory: repeatCategory,
            repeatPaymentChipKey: repeatPaymentChipKey,
          ),
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    _clearSnackBars();

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
    if (result.addAnother) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) {
        await _openQuickAddSheet(
          expenses,
          repeat: true,
          repeatCategory: result.repeatCategory,
          repeatPaymentChipKey: result.repeatPaymentChipKey,
        );
      }
    }
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

      _showCashGuidanceIfNeeded(outcome);
      _showSaveConfirmationWithUndo(outcome);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showLocalSnackBar(
        SnackBar(content: Text(l10n.expenseFormSaveError('$error'))),
      );
    }
  }

  Future<void> _openSmsExpenseScreen() async {
    _clearSnackBars();
    final outcome = await Navigator.of(context).push<ExpenseCreateOutcome?>(
      MaterialPageRoute<ExpenseCreateOutcome?>(
        builder: (_) => SmsExpenseScreen(trip: _trip),
      ),
    );

    _showCashGuidanceIfNeeded(outcome);
    _showSaveConfirmationWithUndo(outcome);
  }

  Future<void> _openTripReports() async {
    _clearSnackBars();
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
    _showLocalSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(l10n.tripDetailsQuickAddExpenseAdded),
        action: createdExpenseId == null
            ? null
            : SnackBarAction(
                label: l10n.commonUndo,
                onPressed: () {
                  unawaited(_undoCreatedExpense(createdExpenseId));
                },
              ),
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
      _showLocalSnackBar(
        SnackBar(content: Text(l10n.tripDetailsDeleteExpenseError('$error'))),
      );
    }
  }

  void _showEditSaveConfirmationWithUndo(Expense previousExpense) {
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    _showLocalSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(l10n.tripDetailsChangesSaved),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () {
            unawaited(_restorePreviousExpense(previousExpense));
          },
        ),
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
      _showLocalSnackBar(
        SnackBar(content: Text(l10n.expenseFormSaveError('$error'))),
      );
    }
  }

  Future<void> _openCashWallet() async {
    _clearSnackBars();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TripCashWalletScreen(trip: _trip),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _cashWalletVersion++;
    });
  }

  Future<void> _openExchangeRates() async {
    _clearSnackBars();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TripExchangeRatesScreen(trip: _trip),
      ),
    );
  }

  void _showCashGuidanceIfNeeded(ExpenseCreateOutcome? outcome) {
    if (!mounted || outcome == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    if (outcome.cashBalanceInsufficient) {
      _showLocalSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            outcome.noCashBalanceRecorded
                ? l10n.cashBalanceNoRecordedWarning
                : l10n.cashBalanceInsufficientWarning,
          ),
          action: outcome.noCashBalanceRecorded
              ? SnackBarAction(
                  label: l10n.cashBalanceAddCashAction,
                  onPressed: _openCashWallet,
                )
              : null,
        ),
      );
    }
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.clearSnackBars();
    final closed = messenger
        .showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            content: Text(l10n.tripDetailsExpenseDeleted),
            action: SnackBarAction(
              label: l10n.commonUndo,
              onPressed: () {
                undone = true;
                if (!mounted) {
                  return;
                }
                setState(() {
                  _pendingDeletionExpenseIds.remove(expense.id);
                });
              },
            ),
          ),
        )
        .closed;

    await closed;

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

      _showLocalSnackBar(
        SnackBar(content: Text(l10n.tripDetailsDeleteExpenseError('$error'))),
      );
    }
  }
}

class _TripDetailsContent extends StatefulWidget {
  const _TripDetailsContent({
    required this.trip,
    required this.expenses,
    required this.cashWalletVersion,
    required this.onAddExpense,
    this.onRepeatLast,
    required this.onOpenCashWallet,
    required this.onOpenExchangeRates,
    required this.onAddViaSms,
    this.onFixDates,
    required this.onEditExpense,
    required this.onDeleteExpense,
  });

  final Trip trip;
  final List<Expense> expenses;
  final int cashWalletVersion;
  final VoidCallback onAddExpense;
  final VoidCallback? onRepeatLast;
  final VoidCallback onOpenCashWallet;
  final VoidCallback onOpenExchangeRates;
  final VoidCallback onAddViaSms;
  final VoidCallback? onFixDates;
  final ValueChanged<Expense> onEditExpense;
  final ValueChanged<Expense> onDeleteExpense;

  @override
  State<_TripDetailsContent> createState() => _TripDetailsContentState();
}

class _TripDetailsContentState extends State<_TripDetailsContent> {
  late final TextEditingController _searchController;
  _CashWalletCtaState _cashWalletCtaState = const _CashWalletCtaState(
    balances: [],
    hasTrackingStarted: false,
    cashConversionContext: _CashConversionContext.empty(),
  );
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  _ExpenseSort _selectedSort = _ExpenseSort.newestFirst;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    unawaited(_refreshCashWalletCtaState());
  }

  @override
  void didUpdateWidget(covariant _TripDetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id ||
        oldWidget.cashWalletVersion != widget.cashWalletVersion) {
      unawaited(_refreshCashWalletCtaState());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshCashWalletCtaState() async {
    final next = await _loadCashWalletCtaState();
    if (!mounted) {
      return;
    }
    setState(() {
      _cashWalletCtaState = next;
    });
  }

  Future<_CashWalletCtaState> _loadCashWalletCtaState() async {
    try {
      final repository = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(cashWalletRepositoryProvider);
      final balances = await repository.getBalancesByTrip(widget.trip.id);
      final transactions = await repository.getRecentTransactionsByTrip(
        widget.trip.id,
      );

      return _CashWalletCtaState(
        balances: balances,
        hasTrackingStarted: _hasCashTrackingStarted(
          balances: balances,
          transactions: transactions,
        ),
        cashConversionContext: _buildCashConversionContext(transactions),
      );
    } catch (_) {
      return const _CashWalletCtaState(
        balances: [],
        hasTrackingStarted: false,
        cashConversionContext: _CashConversionContext.empty(),
      );
    }
  }

  _CashConversionContext _buildCashConversionContext(
    List<CashTransaction> transactions,
  ) {
    final tripHomeCurrency = widget.trip.homeCurrencySnapshot.trim().toUpperCase();
    if (tripHomeCurrency.isEmpty) {
      return const _CashConversionContext.empty();
    }

    final cashTotalsByCurrency = <String, double>{};
    final homeTotalsByCurrency = <String, double>{};

    for (final transaction in transactions) {
      final isInflow = transaction.type == CashTransactionType.initialCash ||
          transaction.type == CashTransactionType.atmWithdrawal ||
          transaction.type == CashTransactionType.currencyExchangeIn ||
          transaction.type == CashTransactionType.manualAdjustment;
      if (!isInflow) {
        continue;
      }

      final homeAmount = transaction.homeCurrencyAmount;
      if (homeAmount == null || homeAmount <= 0 || transaction.amount <= 0) {
        continue;
      }

      final homeCurrency =
          (transaction.homeCurrencyCode ?? tripHomeCurrency).trim().toUpperCase();
      if (homeCurrency != tripHomeCurrency) {
        continue;
      }

      final currency = transaction.currencyCode.trim().toUpperCase();
      cashTotalsByCurrency.update(
        currency,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
      homeTotalsByCurrency.update(
        currency,
        (value) => value + homeAmount,
        ifAbsent: () => homeAmount,
      );
    }

    final rates = <String, _CashEffectiveRate>{};
    for (final entry in cashTotalsByCurrency.entries) {
      final cashTotal = entry.value;
      final homeTotal = homeTotalsByCurrency[entry.key] ?? 0;
      if (cashTotal <= 0 || homeTotal <= 0) {
        continue;
      }
      rates[entry.key] = _CashEffectiveRate(
        transactionCurrencyCode: entry.key,
        homeCurrencyCode: tripHomeCurrency,
        rate: homeTotal / cashTotal,
      );
    }

    return _CashConversionContext(ratesByTransactionCurrency: rates);
  }

  bool _hasCashTrackingStarted({
    required List<TripCashBalance> balances,
    required List<CashTransaction> transactions,
  }) {
    final hasIntentionalCashTx = transactions.any(
      (transaction) =>
          transaction.type != CashTransactionType.cashExpenseDeduction,
    );
    final hasPositiveBalance = balances.any((balance) => balance.balanceAmount > 0);
    return hasIntentionalCashTx || hasPositiveBalance;
  }

  _PrimaryCashBalance _resolvePrimaryCashBalance({
    required List<TripCashBalance> balances,
    required String preferredCurrency,
  }) {
    final normalizedPreferred = preferredCurrency.trim().toUpperCase();

    for (final balance in balances) {
      if (balance.currencyCode == normalizedPreferred) {
        return _PrimaryCashBalance(balance.balanceAmount, balance.currencyCode);
      }
    }

    if (balances.isNotEmpty) {
      return _PrimaryCashBalance(
        balances.first.balanceAmount,
        balances.first.currencyCode,
      );
    }

    return _PrimaryCashBalance(0, normalizedPreferred);
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
    final hasMultipleTransactionCurrencies =
        _hasMultipleTransactionCurrencies(widget.expenses);
    final topCategory = hasMultipleTransactionCurrencies
        ? null
        : _topCategory(widget.expenses);
    final filteredExpenses = _filteredAndSortedExpenses();
    final hasExcludedCurrencies =
        totalableExpenses.length != widget.expenses.length;
    final baseCurrency = widget.trip.baseCurrency.trim().toUpperCase();
    final hasExpensesOutsideBaseCurrency =
      total == 0 && hasExcludedCurrencies && widget.expenses.isNotEmpty;
    final totalDisplayValue = hasExpensesOutsideBaseCurrency
      ? l10n.tripDetailsNoExpensesInBaseCurrency
      : _formatCurrency(total, widget.trip.baseCurrency);

    final chargedTotalsByCurrency = <String, double>{};
    for (final expense in widget.expenses.where((e) => e.isInternational)) {
      final amount = expense.totalChargedAmount ?? expense.billedAmount;
      final currency =
          (expense.totalChargedCurrency ?? expense.billedCurrency)
              ?.trim()
              .toUpperCase();
      if (amount == null || amount <= 0 || currency == null || currency.isEmpty) {
        continue;
      }
      chargedTotalsByCurrency[currency] =
          (chargedTotalsByCurrency[currency] ?? 0) + amount;
    }
    final String? chargedSummaryLabel;
    final String? chargedSummaryValue;
    if (chargedTotalsByCurrency.isEmpty) {
      chargedSummaryLabel = null;
      chargedSummaryValue = null;
    } else if (chargedTotalsByCurrency.length == 1) {
      final currency = chargedTotalsByCurrency.keys.first;
      chargedSummaryLabel = l10n.tripDetailsCardChargesInCurrency(currency);
      chargedSummaryValue =
          _formatCurrency(chargedTotalsByCurrency[currency]!, currency);
    } else {
      chargedSummaryLabel = l10n.tripDetailsCardChargesMultipleCurrencies;
      chargedSummaryValue = l10n.tripDetailsMixedValue;
    }
    final listBottomPadding = MediaQuery.of(context).padding.bottom + 128;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final datesMissing = widget.trip.startDate == null || widget.trip.endDate == null;
    final dateRangeText = datesMissing ? null : _formatDateRangeText(widget.trip);

    if (!hasExpenses) {
      return NoExpensesPremiumState(
        trip: widget.trip,
        isArabic: isArabic,
        tripName: TripTitleResolver.resolve(widget.trip, isArabic),
        baseCurrency: widget.trip.baseCurrency,
        datesMissing: datesMissing,
        dateRangeText: dateRangeText,
        onAddExpense: widget.onAddExpense,
        onOpenCashWallet: widget.onOpenCashWallet,
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
        cacheExtent: 10000,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          listBottomPadding,
        ),
        children: [
          _TripSummaryCard(trip: widget.trip),
          const SizedBox(height: AppSpacing.lg - 2),
          if (chargedSummaryLabel != null && chargedSummaryValue != null) ...[
            _StatCard(
              label: chargedSummaryLabel,
              value: chargedSummaryValue,
              labelTextDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: hasExcludedCurrencies
                      ? l10n.tripDetailsTotalInCurrencyOnly(baseCurrency)
                      : l10n.tripDetailsTotalExpenses,
                  value: totalDisplayValue,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: l10n.tripDetailsExpenseCount,
                  value: widget.expenses.length.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatCard(
            label: l10n.tripDetailsTopCategory,
            value: hasMultipleTransactionCurrencies
                ? l10n.tripDetailsTopCategoryMultiCurrency
                : topCategory == null
                    ? l10n.tripDetailsTopCategoryNone
                    : ExpenseOptionLabels.category(l10n, topCategory),
          ),
          if (hasExcludedCurrencies) ...[
            const SizedBox(height: AppSpacing.sm),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.md),
          _PrimaryGradientButton(
            label: l10n.tripDetailsAddExpense,
            icon: Icons.add_rounded,
            onTap: widget.onAddExpense,
          ),
          if (widget.onRepeatLast != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _OutlineActionButton(
              label: l10n.tripDetailsRepeatLastExpense,
              subtitle: null,
              icon: Icons.refresh_rounded,
              onTap: widget.onRepeatLast!,
            ),
          ],
          if (_cashWalletCtaState.hasTrackingStarted) ...[
            const SizedBox(height: AppSpacing.sm),
            Builder(
              builder: (context) {
                final primaryBalance = _resolvePrimaryCashBalance(
                  balances: _cashWalletCtaState.balances,
                  preferredCurrency: widget.trip.destinationCurrency,
                );
                final amountText = _formatAmountCurrencyLtr(
                  primaryBalance.amount,
                  primaryBalance.currencyCode,
                );

                return _OutlineActionButton(
                  label: l10n.tripDetailsCashWalletRemainingCta(amountText),
                  subtitle: l10n.tripDetailsCashWalletAction,
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: widget.onOpenCashWallet,
                );
              },
            ),
          ],
          if (widget.expenses.length >= 5) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm - 2,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
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
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md - 2,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
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
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            l10n.tripDetailsExpensesSection,
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
                  cashConversionContext: _cashWalletCtaState.cashConversionContext,
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

  String? _topCategory(List<Expense> expenses) {
    if (expenses.isEmpty || _hasMultipleTransactionCurrencies(expenses)) {
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

class _PrimaryCashBalance {
  const _PrimaryCashBalance(this.amount, this.currencyCode);

  final double amount;
  final String currencyCode;
}

class _CashWalletCtaState {
  const _CashWalletCtaState({
    required this.balances,
    required this.hasTrackingStarted,
    required this.cashConversionContext,
  });

  final List<TripCashBalance> balances;
  final bool hasTrackingStarted;
  final _CashConversionContext cashConversionContext;
}

class _CashConversionContext {
  const _CashConversionContext({
    required this.ratesByTransactionCurrency,
  });

  const _CashConversionContext.empty()
      : ratesByTransactionCurrency = const <String, _CashEffectiveRate>{};

  final Map<String, _CashEffectiveRate> ratesByTransactionCurrency;

  _CashEffectiveRate? findRate(String transactionCurrencyCode) {
    return ratesByTransactionCurrency[transactionCurrencyCode.trim().toUpperCase()];
  }
}

class _CashEffectiveRate {
  const _CashEffectiveRate({
    required this.transactionCurrencyCode,
    required this.homeCurrencyCode,
    required this.rate,
  });

  final String transactionCurrencyCode;
  final String homeCurrencyCode;
  final double rate;
}

enum _ExpenseSort { newestFirst, oldestFirst, highestAmount, lowestAmount }

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final status = _resolveStatus(l10n);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFF), Color(0xFFF3EDFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg - 2,
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: isArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: isArabic
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm - 2,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: status.background,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.label,
                            style: TextStyle(
                              color: status.foreground,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              trip.destination,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm - 2),
                      Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _formatDateRange(context, trip),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Image.asset(
                    'assets/travel.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.flight_takeoff_rounded,
                      size: 36,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md - 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm - 2,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.tripDetailsBaseCurrency(trip.baseCurrency),
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (trip.budget != null && (trip.budget ?? 0) > 0)
                  Text(
                    l10n.tripDetailsBudget(_formatBudget(trip)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7C3AED),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ({String label, Color background, Color foreground}) _resolveStatus(
    AppLocalizations l10n,
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
  const _StatCard({
    required this.label,
    required this.value,
    this.labelTextDirection,
  });

  final String label;
  final String value;
  final TextDirection? labelTextDirection;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg - 2,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              label,
              textDirection: labelTextDirection,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm - 2),
            Text(
              value,
              textDirection: ui.TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
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
    required this.tripHomeCurrency,
    required this.cashConversionContext,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final String tripHomeCurrency;
  final _CashConversionContext cashConversionContext;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Primary display is always the real travel-country transaction amount.
    // Charged/billed home amounts are secondary FX metadata shown in the
    // conversion block only and never promoted to primary.
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
    final double? displayedConversionRate;

    if (expense.convertedHomeAmount != null) {
      displayedConvertedHomeAmount = expense.convertedHomeAmount;
      displayedHomeCurrency =
          normalizedStoredHomeCurrency ??
          (storedRate != null ? normalizedTripHomeCurrency : null);
      displayedConversionRate = storedRate;
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
        // conversion snapshots before deriving any rate from cash wallet history.
        final baseAmount =
            (storedOriginalAmount != null && storedOriginalAmount > 0)
                ? storedOriginalAmount
                : originalAmount;
        displayedConvertedHomeAmount = baseAmount * storedRate;
        displayedHomeCurrency = fallbackHomeCurrency;
        displayedConversionRate = storedRate;
      } else {
        final cashRate = _isCashExpense(expense)
            ? cashConversionContext.findRate(originalCurrency)
            : null;
        if (cashRate != null) {
          displayedConvertedHomeAmount = originalAmount * cashRate.rate;
          displayedHomeCurrency = cashRate.homeCurrencyCode;
          displayedConversionRate = cashRate.rate;
        } else {
          displayedConvertedHomeAmount = null;
          displayedHomeCurrency = null;
          displayedConversionRate = null;
        }
      }
    }

    final hasHomeConversion =
      displayedConvertedHomeAmount != null &&
      (displayedHomeCurrency ?? '').isNotEmpty &&
      originalCurrency.isNotEmpty;

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final isArabic = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final hasTime = expense.spentAt.hour != 0 || expense.spentAt.minute != 0;
    final dateText = DateFormat(
      isArabic ? 'd MMM yyyy' : 'dd MMM yyyy',
      localeTag,
    ).format(expense.spentAt);
    final timeText = hasTime
        ? DateFormat(isArabic ? 'h:mm a' : 'HH:mm', localeTag).format(expense.spentAt)
        : null;
    final spentAtText = timeText == null ? dateText : '$dateText | $timeText';

    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.74),
      fontWeight: FontWeight.w500,
      fontSize: 12,
      height: 1.3,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md - 2,
        ),
          child: Column(
            crossAxisAlignment:
                isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${ExpenseOptionLabels.category(l10n, expense.category ?? 'Other')} · ${ExpenseOptionLabels.paymentSummary(
                            l10n,
                            paymentMethodValue: expense.paymentMethod,
                            paymentNetworkValue: expense.paymentNetwork,
                            paymentChannelValue: expense.paymentChannel,
                          )}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          spentAtText,
                          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (expense.note != null && expense.note!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            expense.note!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 136, maxWidth: 184),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: Directionality(
                            textDirection: ui.TextDirection.ltr,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatAmountNumber(primaryAmount),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF020617),
                                    letterSpacing: -0.2,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  primaryCurrency.trim().toUpperCase(),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (hasHomeConversion) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${l10n.commonApprox} ${_formatAmountCurrencyLtr(displayedConvertedHomeAmount, displayedHomeCurrency as String)}',
                          textAlign: TextAlign.end,
                          textDirection: ui.TextDirection.ltr,
                          style: mutedStyle,
                        ),
                        if (displayedConversionRate != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            '1 $originalCurrency = ${_formatRate(displayedConversionRate)} $displayedHomeCurrency',
                            textAlign: TextAlign.end,
                            textDirection: ui.TextDirection.ltr,
                            style: mutedStyle,
                          ),
                        ],
                      ],
                      if (expense.feesAmount != null &&
                          (expense.feesCurrency ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${l10n.intlFees}: ${_formatAmountCurrencyLtr(expense.feesAmount!, expense.feesCurrency ?? '')}',
                          textAlign: TextAlign.end,
                          textDirection: ui.TextDirection.ltr,
                          style: mutedStyle,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.expenseEditTooltip,
                            onPressed: onEdit,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
                            ),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: l10n.commonDelete,
                            onPressed: onDelete,
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.75),
                            ),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }

  String _formatRate(double rate) {
    if (rate >= 100) return rate.toStringAsFixed(2);
    if (rate >= 1) return rate.toStringAsFixed(3);
    // For small rates strip trailing zeros (e.g. 0.103000 -> 0.103)
    final s = rate.toStringAsFixed(6);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  bool _isCashExpense(Expense value) {
    return isCashExpensePayment(
      paymentMethod: value.paymentMethod,
      paymentChannel: value.paymentChannel,
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

class NoExpensesPremiumState extends StatelessWidget {
  final Trip trip;
  final bool isArabic;
  final String tripName;
  final String baseCurrency;
  final bool datesMissing;
  final String? dateRangeText;
  final VoidCallback onAddExpense;
  final VoidCallback onOpenCashWallet;
  final VoidCallback onAddViaSms;
  final VoidCallback? onFixDates;
  final VoidCallback? onDismissTip;

  const NoExpensesPremiumState({
    super.key,
    required this.trip,
    required this.isArabic,
    required this.tripName,
    required this.baseCurrency,
    required this.datesMissing,
    required this.dateRangeText,
    required this.onAddExpense,
    required this.onOpenCashWallet,
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
              trip: trip,
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
              onOpenCashWallet: onOpenCashWallet,
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
  final Trip trip;
  final bool isArabic;
  final String tripName;
  final String baseCurrency;
  final bool datesMissing;
  final String? dateRangeText;
  final VoidCallback? onFixDates;

  const _NoExpensesTripSummaryCard({
    required this.trip,
    required this.isArabic,
    required this.tripName,
    required this.baseCurrency,
    required this.datesMissing,
    required this.dateRangeText,
    this.onFixDates,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = _resolveStatus(l10n);

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
                        color: status.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          color: status.foreground,
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
                  label: l10n.tripFormCurrencyLabel,
                  trailing: baseCurrency,
                  trailingColor: const Color(0xFF00897B),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: datesMissing ? onFixDates : null,
                  child: _NoExpensesInfoLine(
                    isArabic: isArabic,
                    icon: Icons.calendar_month_outlined,
                    label: datesMissing
                        ? l10n.tripsDatesNeedAttention
                        : (dateRangeText ?? ''),
                    subtitle: datesMissing
                        ? l10n.tripDetailsSetStartEndDates
                        : null,
                    trailingIcon: null,
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

  ({String label, Color background, Color foreground}) _resolveStatus(
    AppLocalizations l10n,
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
  final VoidCallback onOpenCashWallet;
  final VoidCallback onAddViaSms;
  final VoidCallback? onDismissTip;

  const _NoExpensesCard({
    required this.isArabic,
    required this.onAddExpense,
    required this.onOpenCashWallet,
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
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(_fadeScale),
              child: Opacity(
                opacity: 0.90,
                child: Image.asset(
                  'assets/FirstExpense.png',
                  height: 136,
                  fit: BoxFit.contain,
                ),
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
          const SizedBox(height: 14),
          _AnimatedCta(
            animController: _animController,
            child: _OutlineActionButton(
              label: l.noExpensesCashWallet,
              subtitle: l.noExpensesCashWalletSubtitle,
              icon: Icons.account_balance_wallet_outlined,
              onTap: widget.onOpenCashWallet,
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
            child: Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l.noExpensesTipBody,
                          textAlign: TextAlign.start,
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
                      child: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
                        size: 16,
                      ),
                    ),
                ],
              ),
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

enum _TripDetailsOverflowAction { reports, smsImport, exportCsv, exportPdf }

class _TripDetailsOverflowMenu extends ConsumerWidget {
  const _TripDetailsOverflowMenu({
    required this.trip,
    required this.hasExpenses,
    required this.onOpenReports,
    required this.onAddViaSms,
  });

  final Trip trip;
  final bool hasExpenses;
  final VoidCallback onOpenReports;
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
          case _TripDetailsOverflowAction.reports:
            onOpenReports();
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
          value: _TripDetailsOverflowAction.reports,
          child: Row(
            children: [
              const Icon(Icons.bar_chart_outlined, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.tripDetailsReportTooltip),
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
      color: _fabColor.withValues(alpha: 0.20),
      blurRadius: 22,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 28,
      spreadRadius: 0,
      offset: const Offset(0, 10),
    ),
  ];

  @override
  Widget build(BuildContext context) {
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

class _TopActionIconButton extends StatelessWidget {
  const _TopActionIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: _TopActionIcon(icon: icon),
        ),
      ),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: const Color(0xFF0F172A), size: 20),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.2,
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
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineActionButton({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: Color(0xFF7C3AED), width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFFF7F2FF),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6D28D9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
