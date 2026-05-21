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
    final isArabic = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

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
            child: ExportMenu(
              trip: _trip,
              enabled: hasExpenses,
              trigger: Tooltip(
                message: isArabic ? 'طھطµط¯ظٹط±' : 'Export',
                child: const _TopActionIcon(icon: Icons.file_download_outlined),
              ),
            ),
          ),
          _TopActionWrapper(
            child: _TopActionIconButton(
              tooltip: context.l10n.tripDetailsReportTooltip,
              onPressed: _openTripReports,
              icon: Icons.bar_chart_outlined,
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
      body: expensesState.when(
        data: (expenses) {
          final visibleExpenses = expenses
              .where((expense) => !_pendingDeletionExpenseIds.contains(expense.id))
              .toList(growable: false);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (visibleExpenses.isNotEmpty)
                      ActionChip(
                        label: Text(AppLocalizations.of(context)!.tripDetailsRepeatLastExpense),
                        avatar: const Icon(Icons.refresh, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _openQuickAddSheet(visibleExpenses, repeat: true, lastExpense: visibleExpenses.last);
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _TripDetailsContent(
                  trip: _trip,
                  expenses: visibleExpenses,
                  cashWalletVersion: _cashWalletVersion,
                  onAddExpense: () => _openQuickAddSheet(visibleExpenses),
                  onOpenCashWallet: _openCashWallet,
                  onOpenExchangeRates: _openExchangeRates,
                  onAddViaSms: _openSmsExpenseScreen,
                  onFixDates: _openTripEditor,
                  onEditExpense: (expense) => _openExpenseForm(expense: expense),
                  onDeleteExpense: (expense) => _confirmDelete(expense),
                ),
              ),
            ],
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
                Text('$error', textAlign: TextAlign.center),
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

    if (result.openCashWallet) {
      await _openCashWallet();
      return;
    }

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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    _showLocalSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(l10n.tripDetailsQuickAddExpenseAdded),
        action: createdExpenseId == null
            ? null
            : SnackBarAction(
                label: isArabic ? 'طھط±ط§ط¬ط¹' : 'Undo',
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

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    _showLocalSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(isArabic ? 'طھظ… ط­ظپط¸ ط§ظ„طھط¹ط¯ظٹظ„ط§طھ' : 'Changes saved'),
        action: SnackBarAction(
          label: isArabic ? 'طھط±ط§ط¬ط¹' : 'Undo',
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

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    var undone = false;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.clearSnackBars();
    final closed = messenger
        .showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            content: Text(
              isArabic ? 'طھظ… ط­ط°ظپ ط§ظ„ظ…طµط±ظˆظپ' : 'Expense deleted',
            ),
            action: SnackBarAction(
              label: isArabic ? 'طھط±ط§ط¬ط¹' : 'Undo',
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
    final topCategory = _topCategory(widget.expenses);
    final filteredExpenses = _filteredAndSortedExpenses();
    final hasExcludedCurrencies =
        totalableExpenses.length != widget.expenses.length;
    final hasExpensesOutsideBaseCurrency =
      total == 0 && hasExcludedCurrencies && widget.expenses.isNotEmpty;
    final totalDisplayValue = hasExpensesOutsideBaseCurrency
      ? l10n.tripDetailsNoExpensesInBaseCurrency
      : _formatCurrency(total, widget.trip.baseCurrency);

    // Partial charged total: only one currency is shown to avoid mixed-currency sums.
    String? chargedSummaryCurrency;
    var chargedSummaryTotal = 0.0;
    for (final expense in widget.expenses.where((e) => e.isInternational)) {
      final amount = expense.totalChargedAmount ?? expense.billedAmount;
      final currency =
          (expense.totalChargedCurrency ?? expense.billedCurrency)
              ?.trim()
              .toUpperCase();
      if (amount == null || amount <= 0 || currency == null || currency.isEmpty) {
        continue;
      }
      chargedSummaryCurrency ??= currency;
      if (currency == chargedSummaryCurrency) {
        chargedSummaryTotal += amount;
      }
    }
    final hasChargedSummary =
        chargedSummaryCurrency != null && chargedSummaryTotal > 0;
    final chargedSummaryLabelCurrency =
      hasChargedSummary ? chargedSummaryCurrency : null;
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
        padding: EdgeInsets.fromLTRB(16, 16, 16, listBottomPadding),
        children: [
          _TripSummaryCard(trip: widget.trip),
          const SizedBox(height: 18),
          if (chargedSummaryLabelCurrency != null) ...[
            _StatCard(
              label: l10n.tripDetailsTotalInCurrencyOnly(chargedSummaryLabelCurrency),
              value: _formatCurrency(chargedSummaryTotal, chargedSummaryLabelCurrency),
              labelTextDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            ),
            const SizedBox(height: 12),
          ],
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
          _PrimaryGradientButton(
            label: l10n.tripDetailsAddExpense,
            icon: Icons.add_rounded,
            onTap: widget.onAddExpense,
          ),
          const SizedBox(height: 12),
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
                label: _cashWalletCtaState.hasTrackingStarted
                    ? l10n.tripDetailsCashWalletRemainingCta(amountText)
                    : l10n.cashTrackingNotStarted,
                subtitle: _cashWalletCtaState.hasTrackingStarted
                    ? l10n.tripDetailsCashWalletAction
                    : l10n.cashBalanceAddCashAction,
                icon: Icons.account_balance_wallet_outlined,
                onTap: widget.onOpenCashWallet,
              );
            },
          ),
          const SizedBox(height: 12),
          _OutlineActionButton(
            label: l10n.tripDetailsAddViaSms,
            icon: Icons.sms_outlined,
            onTap: widget.onAddViaSms,
          ),
          const SizedBox(height: 12),
          // TODO: Temporarily hiding Expense Estimates CTA for UX evaluation
          // _OutlineActionButton(
          //   label: l10n.tripExchangeRatesTitle,
          //   subtitle: l10n.tripExchangeRatesSubtitle,
          //   icon: Icons.currency_exchange,
          //   onTap: widget.onOpenExchangeRates,
          // ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      labelText: l10n.tripDetailsSearchLabel,
                      hintText: l10n.tripDetailsSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
    final status = _resolveStatus(isArabic);

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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: isArabic
                            ? WrapAlignment.end
                            : WrapAlignment.start,
                        children: [
                          Text(
                            TripTitleResolver.resolve(trip, isArabic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.4,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
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
                        ],
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 10),
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
                const SizedBox(width: 12),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Image.asset(
                    'assets/travel.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.flight_takeoff_rounded,
                      size: 46,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    bool isArabic,
  ) {
    return switch (resolveTripTimelineStatus(trip)) {
      TripTimelineStatus.datesPending => (
        label: isArabic ? 'ط§ظ„طھظˆط§ط±ظٹط® ظ†ط§ظ‚طµط©' : 'Dates Pending',
        background: const Color(0xFFFFEDD5),
        foreground: const Color(0xFF9A3412),
      ),
      TripTimelineStatus.upcoming => (
        label: isArabic ? 'ظ‚ط§ط¯ظ…ط©' : 'Upcoming',
        background: const Color(0xFFDBEAFE),
        foreground: const Color(0xFF1D4ED8),
      ),
      TripTimelineStatus.active => (
        label: isArabic ? 'ظ†ط´ط·ط©' : 'Active',
        background: const Color(0xFFDCFCE7),
        foreground: const Color(0xFF166534),
      ),
      TripTimelineStatus.completed => (
        label: isArabic ? 'ظ…ظƒطھظ…ظ„ط©' : 'Completed',
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.06),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 10),
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
      isArabic ? 'd MMMM' : 'dd MMM yyyy',
      localeTag,
    ).format(expense.spentAt);
    final timeText = hasTime
        ? DateFormat(isArabic ? 'h:mm a' : 'HH:mm', localeTag).format(expense.spentAt)
        : null;
    final spentAtText = timeText == null ? dateText : '$dateText | $timeText';

    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.74),
      fontWeight: FontWeight.w500,
      fontSize: 10.5,
      height: 1.15,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.05),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${ExpenseOptionLabels.category(l10n, expense.category ?? 'Other')} | ${ExpenseOptionLabels.paymentSummary(
                            l10n,
                            paymentMethodValue: expense.paymentMethod,
                            paymentNetworkValue: expense.paymentNetwork,
                            paymentChannelValue: expense.paymentChannel,
                          )}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          spentAtText,
                          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (expense.note != null && expense.note!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            expense.note!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
                          '${isArabic ? 'تقريبًا' : 'Approx.'} ${_formatAmountCurrencyLtr(displayedConvertedHomeAmount, displayedHomeCurrency as String)}',
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
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.tripsEditTooltip,
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
    final status = _resolveStatus(isArabic);

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
                  label: isArabic ? 'ط§ظ„ط¹ظ…ظ„ط© ط§ظ„ط£ط³ط§ط³ظٹط©' : 'Base currency',
                  trailing: baseCurrency,
                  trailingColor: const Color(0xFF00897B),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: null,
                  child: _NoExpensesInfoLine(
                    isArabic: isArabic,
                    icon: Icons.calendar_month_outlined,
                    label: datesMissing
                        ? (isArabic
                            ? 'ط§ظ„طھظˆط§ط±ظٹط® طھط­طھط§ط¬ طھط­ط¯ظٹط¯'
                            : 'Dates need attention')
                        : (dateRangeText ?? ''),
                    subtitle: datesMissing
                        ? (isArabic
                            ? 'ط­ط¯ط¯ طھط§ط±ظٹط® ط§ظ„ط¨ط¯ط§ظٹط© ظˆط§ظ„ظ†ظ‡ط§ظٹط©'
                            : 'Set start and end dates')
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
    bool isArabic,
  ) {
    return switch (resolveTripTimelineStatus(trip)) {
      TripTimelineStatus.datesPending => (
        label: isArabic ? 'ط§ظ„طھظˆط§ط±ظٹط® ظ†ط§ظ‚طµط©' : 'Dates Pending',
        background: const Color(0xFFFFEDD5),
        foreground: const Color(0xFF9A3412),
      ),
      TripTimelineStatus.upcoming => (
        label: isArabic ? 'ظ‚ط§ط¯ظ…ط©' : 'Upcoming',
        background: const Color(0xFFDBEAFE),
        foreground: const Color(0xFF1D4ED8),
      ),
      TripTimelineStatus.active => (
        label: isArabic ? 'ظ†ط´ط·ط©' : 'Active',
        background: const Color(0xFFDCFCE7),
        foreground: const Color(0xFF166534),
      ),
      TripTimelineStatus.completed => (
        label: isArabic ? 'ظ…ظƒطھظ…ظ„ط©' : 'Completed',
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
              crossAxisAlignment: CrossAxisAlignment.start,
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

class _QuickAddSheetResult {
  const _QuickAddSheetResult.moreDetails(_QuickAddDraftPayload value)
    : openMoreDetails = true,
      openCashWallet = false,
      addAnother = false,
      repeatCategory = null,
      repeatPaymentChipKey = null,
      payload = null,
      draft = value;

  const _QuickAddSheetResult.submit(_QuickAddSubmitPayload value)
    : openMoreDetails = false,
      openCashWallet = false,
      addAnother = false,
      repeatCategory = null,
      repeatPaymentChipKey = null,
      payload = value,
      draft = null;

  const _QuickAddSheetResult.submitAndAddAnother(
    _QuickAddSubmitPayload value, {
    required String category,
    required String paymentChipKey,
  }) : openMoreDetails = false,
       openCashWallet = false,
       addAnother = true,
       repeatCategory = category,
       repeatPaymentChipKey = paymentChipKey,
       payload = value,
       draft = null;

  const _QuickAddSheetResult.openCashWallet()
    : openMoreDetails = false,
      openCashWallet = true,
      addAnother = false,
      repeatCategory = null,
      repeatPaymentChipKey = null,
      payload = null,
      draft = null;

  final bool openMoreDetails;
  final bool openCashWallet;
  final bool addAnother;
  final String? repeatCategory;
  final String? repeatPaymentChipKey;
  final _QuickAddSubmitPayload? payload;
  final _QuickAddDraftPayload? draft;
}

class QuickAddExpenseSheet extends ConsumerStatefulWidget {
  const QuickAddExpenseSheet({
    super.key,
    required this.trip,
    required this.expenses,
    this.repeatLast = false,
    this.lastExpense,
    this.repeatCategory,
    this.repeatPaymentChipKey,
  });

  final Trip trip;
  final List<Expense> expenses;
  final bool repeatLast;
  final Expense? lastExpense;
  final String? repeatCategory;
  final String? repeatPaymentChipKey;

  @override
  ConsumerState<QuickAddExpenseSheet> createState() =>
      _QuickAddExpenseSheetState();
}

class _QuickAddExpenseSheetState extends ConsumerState<QuickAddExpenseSheet> {
  bool _showRepeatHint = false;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _firstCardLast4Controller =
      TextEditingController();
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
  double? _lastAmountSuggestion;
  Map<String, String> _amountCategoryMemory = {};
  int? _lastUsedCardProfileId;
  String _selectedPaymentChipKey = 'cash';
  bool _hasCashSetup = true;
  bool _cashSetupLoaded = false;
  bool _firstPaymentResolved = false;
  _FirstPaymentStep _firstPaymentStep = _FirstPaymentStep.chooseHowToPay;
  String _firstCardNetwork = 'Visa';

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
    _lastUsedCardProfileId = _resolveLastUsedCardProfileId();
    if (_lastUsedCardProfileId != null) {
      _selectedPaymentChipKey = _paymentChipKeyForCard(_lastUsedCardProfileId!);
    }
    // Repeat Last / Add Another logic
    if (widget.repeatLast) {
      final category = widget.repeatCategory ?? widget.lastExpense?.category;
      final paymentKey = widget.repeatPaymentChipKey ??
          (widget.lastExpense != null ? _paymentChipKeyForExpense(widget.lastExpense!) : null);
      if (category != null) {
        _selectedCategory = category;
        _userSelectedCategory = true;
      }
      if (paymentKey != null) {
        _selectedPaymentChipKey = paymentKey;
      }
      _lastUsedCardProfileId = widget.lastExpense?.cardProfileId;
      _amountController.text = '';
      _showRepeatHint = true;
      _isPrefilledFromMemory = false;
    } else {
      _loadPreferences();
    }
    unawaited(_loadCashSetupState());
  }

  String _paymentChipKeyForExpense(Expense e) {
    if (e.cardProfileId != null) {
      return _paymentChipKeyForCard(e.cardProfileId!);
    }
    return e.paymentMethod;
  }

  Future<void> _loadCashSetupState() async {
    try {
      final repository = ref.read(cashWalletRepositoryProvider);
      final balances = await repository.getBalancesByTrip(widget.trip.id);
      final transactions = await repository.getRecentTransactionsByTrip(
        widget.trip.id,
      );
      final hasIntentionalCashTx = transactions.any(
        (transaction) =>
            transaction.type != CashTransactionType.cashExpenseDeduction,
      );
      final hasPositiveBalance = balances.any(
        (balance) => balance.balanceAmount > 0,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _hasCashSetup = hasIntentionalCashTx || hasPositiveBalance;
        _cashSetupLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasCashSetup = true;
        _cashSetupLoaded = true;
      });
    }
  }

  int? _resolveLastUsedCardProfileId() {
    for (final expense in widget.expenses) {
      if (expense.cardProfileId == null) {
        continue;
      }
      if (!isCardExpenseChannel(expense.paymentChannel)) {
        continue;
      }
      return expense.cardProfileId;
    }
    return null;
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
          _lastAmountSuggestion = lastAmount;
          _selectedCategory = lastCategory ?? 'Other';
          _isPrefilledFromMemory = true;
        } else {
          _lastAmountSuggestion = null;
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
    _firstCardLast4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cardsState = ref.watch(cardsProvider);
    final cards = cardsState.valueOrNull ?? const <CardProfile>[];
    final hasCardsLoaded = cardsState.hasValue;
    final showFirstPaymentOnboarding =
      !_firstPaymentResolved &&
      hasCardsLoaded &&
      _cashSetupLoaded &&
      cards.isEmpty &&
      !_hasCashSetup;
    final showCardInlineSetup =
      showFirstPaymentOnboarding &&
      _firstPaymentStep == _FirstPaymentStep.cardSetup;
    final showCashInlineChoices =
      showFirstPaymentOnboarding &&
      _firstPaymentStep == _FirstPaymentStep.cashChoice;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardInset > 0;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.42;
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    final canSave = amount != null && amount > 0;
    final amountHint = _lastAmountSuggestion != null
      ? _lastAmountSuggestion!.toStringAsFixed(2)
      : '0.00';
    final paymentOptions = _buildPaymentOptions(cards);

    final amountError = _showValidationError ? _validateAmount(l10n) : null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetHeight,
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          24,
          showFirstPaymentOnboarding ? 14 : 20,
          24,
          showFirstPaymentOnboarding ? 14 : 24,
        ),
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
        child: SingleChildScrollView(
          physics: isKeyboardOpen
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
            SizedBox(height: showFirstPaymentOnboarding ? 6 : 10),
            if (_showRepeatHint)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  AppLocalizations.of(context)!.tripDetailsRepeatHint,
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
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
                hintText: amountHint,
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
            SizedBox(height: showFirstPaymentOnboarding ? 8 : 12),
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
            SizedBox(height: showFirstPaymentOnboarding ? 6 : 8),
            if (showFirstPaymentOnboarding)
              _buildFirstPaymentOnboarding(
                context,
                showCardInlineSetup: showCardInlineSetup,
                showCashInlineChoices: showCashInlineChoices,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxCards = constraints.maxWidth < 380 ? 2 : 3;
                  final cashOption = paymentOptions.firstWhere(
                    (option) => option.key == 'cash',
                    orElse: () => paymentOptions.first,
                  );
                  final cardOptions = paymentOptions
                      .where((option) => option.key != 'cash')
                      .toList(growable: false)
                    ..sort((a, b) {
                      final rankA = a.label.startsWith('Visa')
                          ? 0
                          : (a.label.startsWith('MC') ? 1 : 2);
                      final rankB = b.label.startsWith('Visa')
                          ? 0
                          : (b.label.startsWith('MC') ? 1 : 2);
                      if (rankA != rankB) {
                        return rankA.compareTo(rankB);
                      }
                      return a.label.compareTo(b.label);
                    });
                  final visibleOptions = <_QuickAddPaymentOption>[cashOption];
                  for (final option in cardOptions) {
                    if (visibleOptions.length - 1 >= maxCards) {
                      break;
                    }
                    visibleOptions.add(option);
                  }

                  return Row(
                    children: [
                      ...visibleOptions.map((option) {
                        final isSelected = _selectedPaymentChipKey == option.key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: SizedBox(
                              height: 32,
                              child: ChoiceChip(
                                selected: isSelected,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                label: Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF334155)
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: const Color(0xFFF8FAFC),
                                selectedColor: const Color(0xFFEFF3F7),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFFE2E8F0),
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _selectedPaymentChipKey = option.key;
                                  });
                                },
                              ),
                            ),
                          ),
                        );
                      }),
                      SizedBox(
                        height: 32,
                        child: ActionChip(
                          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          label: const Text('...'),
                          onPressed: _openMoreDetails,
                        ),
                      ),
                    ],
                  );
                },
              ),
            SizedBox(height: showFirstPaymentOnboarding ? 8 : 16),
            Row(
              children: [
                Expanded(
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
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                const SizedBox(width: 9),
                                Text(
                                  AppLocalizations.of(context)!.quickAddQuickSave,
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
                    ),
                  ),
                ),
              ],
            ),
            if (!showFirstPaymentOnboarding) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openMoreDetails,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(l10n.quickAddAddDetails),
                ),
              ),
            ],
            ],
          ),
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
    _saveWithPayment(_selectedQuickPayment());
  }

  void _saveWithPayment(_QuickAddPaymentData payment, {bool addAnother = false}) {
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

    final submitPayload = _QuickAddSubmitPayload(
      title: _selectedCategory,
      amount: amount,
      currencyCode: widget.trip.baseCurrency.trim().toUpperCase(),
      category: _selectedCategory,
      spentAt: now,
      payment: payment,
    );

    Navigator.of(context).pop(
      addAnother
          ? _QuickAddSheetResult.submitAndAddAnother(
              submitPayload,
              category: _selectedCategory,
              paymentChipKey: _selectedPaymentChipKey,
            )
          : _QuickAddSheetResult.submit(submitPayload),
    );
  }

  void _openMoreDetails() {
    final selectedPayment = _selectedQuickPayment();
    _savePreferences();
    Navigator.of(context).pop(
      _QuickAddSheetResult.moreDetails(
        _QuickAddDraftPayload(
          title: _selectedCategory,
          amountText: _amountController.text,
          category: _selectedCategory,
          paymentMethod: selectedPayment.method,
          currencyCode: widget.trip.baseCurrency.trim().toUpperCase(),
          spentAt: DateTime.now(),
        ),
      ),
    );
  }

  List<_QuickAddPaymentOption> _buildPaymentOptions(List<CardProfile> cards) {
    final cardsById = <int, CardProfile>{for (final card in cards) card.id: card};
    final options = <_QuickAddPaymentOption>[
      _QuickAddPaymentOption(
        key: 'cash',
        label: AppLocalizations.of(context)!.paymentMethodCash,
        payment: _defaultQuickPayment,
      ),
    ];

    final seenCardIds = <int>{};
    for (final expense in widget.expenses) {
      final cardId = expense.cardProfileId;
      if (cardId == null || seenCardIds.contains(cardId)) {
        continue;
      }
      if (!isCardExpenseChannel(expense.paymentChannel)) {
        continue;
      }

      final card = cardsById[cardId];
      if (card == null) {
        continue;
      }

      options.add(
        _QuickAddPaymentOption(
          key: _paymentChipKeyForCard(cardId),
          label: _cardChipLabel(card, expense.paymentNetwork),
          payment: _paymentForCard(card, expense),
        ),
      );
      seenCardIds.add(cardId);
      if (seenCardIds.length >= 3) {
        break;
      }
    }

    if (options.length == 1 && cards.isNotEmpty) {
      final fallbackCard = _lastUsedCardProfileId == null
          ? cards.first
          : cards.firstWhere(
              (card) => card.id == _lastUsedCardProfileId,
              orElse: () => cards.first,
            );
      options.add(
        _QuickAddPaymentOption(
          key: _paymentChipKeyForCard(fallbackCard.id),
          label: _cardChipLabel(fallbackCard, fallbackCard.cardNetwork),
          payment: _paymentForCardFallback(fallbackCard),
        ),
      );
    }

    return options;
  }

  _QuickAddPaymentData _paymentForCardFallback(CardProfile card) {
    final network =
        _normalizedText(card.cardNetwork ?? card.customCardNetwork) ?? 'Other';
    const channel = 'POS Purchase';
    return _QuickAddPaymentData(
      method: resolvePaymentMethodHint(network, channel),
      network: network,
      channel: channel,
      cardProfileId: card.id,
    );
  }

  Widget _buildFirstPaymentOnboarding(
    BuildContext context, {
    required bool showCardInlineSetup,
    required bool showCashInlineChoices,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final firstCardLast4 = _firstCardLast4Controller.text.trim();
    final canSaveFirstCard = RegExp(r'^\d{4}$').hasMatch(firstCardLast4);

    if (showCardInlineSetup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <String>['Visa', 'Mastercard', 'Mada'].map((network) {
              return SizedBox(
                height: 30,
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selected: _firstCardNetwork == network,
                  label: Text(network == 'Mastercard' ? 'MC' : network),
                  onSelected: (_) {
                    setState(() {
                      _firstCardNetwork = network;
                    });
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                '****',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _firstCardLast4Controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '1234',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(38),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: canSaveFirstCard ? _saveFirstCardAndContinue : null,
              child: Text(isArabic ? 'ظ…طھط§ط¨ط¹ط©' : 'Continue'),
            ),
          ),
        ],
      );
    }

    if (showCashInlineChoices) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic
                ? 'ظ‡ظ„ طھط±ظٹط¯ ط¥ط¯ط®ط§ظ„ ط±طµظٹط¯ ط§ظ„ظƒط§ط´ ط§ظ„ط¢ظ†طں'
                : 'Do you want to add cash balance now?',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _continueWithTemporaryCash,
                  child: Text(isArabic ? 'ظ„ط§ط­ظ‚ط§ظ‹' : 'Later'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _openCashWalletFromQuickAdd,
                  child: Text(isArabic ? 'ط¥ط¯ط®ط§ظ„ ط§ظ„ط±طµظٹط¯' : 'Add balance'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'ظƒظٹظپ ط¯ظپط¹طھطں' : 'How did you pay?',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _firstPaymentStep = _FirstPaymentStep.cardSetup;
                  });
                },
                child: Text(isArabic ? 'ط¨ط·ط§ظ‚ط©' : 'Card'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedPaymentChipKey = 'cash';
                    _firstPaymentStep = _FirstPaymentStep.cashChoice;
                  });
                },
                child: Text(isArabic ? 'ظƒط§ط´' : 'Cash'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveFirstCardAndContinue() async {
    final last4 = _firstCardLast4Controller.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(last4)) {
      return;
    }

    final network = _firstCardNetwork;

    try {
      final createdCard = await ref.read(cardRepositoryProvider).addCard(
        name: '$network ****$last4',
            cardNetwork: network,
            cardTier: network == 'Mada' ? 'Other' : 'Classic',
            last4: last4,
          );
      ref.invalidate(cardsProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _firstPaymentResolved = true;
        _selectedPaymentChipKey = _paymentChipKeyForCard(createdCard.id);
        _lastUsedCardProfileId = createdCard.id;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'طھط¹ط°ط± ط­ظپط¸ ط§ظ„ط¨ط·ط§ظ‚ط©. ط­ط§ظˆظ„ ظ…ط±ط© ط£ط®ط±ظ‰.' : 'Could not save card. Try again.',
          ),
        ),
      );
    }
  }

  void _continueWithTemporaryCash() {
    setState(() {
      _firstPaymentResolved = true;
      _selectedPaymentChipKey = 'cash';
    });
  }

  void _openCashWalletFromQuickAdd() {
    Navigator.of(context).pop(const _QuickAddSheetResult.openCashWallet());
  }

  _QuickAddPaymentData _selectedQuickPayment() {
    final cards = ref.read(cardsProvider).valueOrNull ?? const <CardProfile>[];
    final options = _buildPaymentOptions(cards);
    for (final option in options) {
      if (option.key == _selectedPaymentChipKey) {
        return option.payment;
      }
    }
    return _defaultQuickPayment;
  }

  String _paymentChipKeyForCard(int cardId) => 'card:$cardId';

  String _cardChipLabel(CardProfile card, String? fallbackNetwork) {
    final network = _normalizedText(
          fallbackNetwork ?? card.cardNetwork ?? card.customCardNetwork,
        ) ??
        'Card';
    final compactNetwork = _compactNetworkLabel(network);
    final last4 = _normalizedText(card.last4);
    if (last4 != null) {
      return '$compactNetwork ****$last4';
    }
    return compactNetwork;
  }

  String _compactNetworkLabel(String network) {
    final normalized = network.trim().toLowerCase();
    if (normalized == 'mastercard') {
      return 'MC';
    }
    if (normalized == 'visa') {
      return 'Visa';
    }
    if (normalized == 'apple pay') {
      return 'Apple';
    }
    return network;
  }

  _QuickAddPaymentData _paymentForCard(CardProfile card, Expense recentExpense) {
    final network = _normalizedText(
          recentExpense.paymentNetwork ?? card.cardNetwork ?? card.customCardNetwork,
        ) ??
        'Other';
    final recentChannel = _normalizedText(recentExpense.paymentChannel);
    final channel = recentChannel == 'Online Purchase'
        ? 'Online Purchase'
        : 'POS Purchase';

    return _QuickAddPaymentData(
      method: resolvePaymentMethodHint(network, channel),
      network: network,
      channel: channel,
      cardProfileId: card.id,
    );
  }

  String? _normalizedText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
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
    method: 'Cash',
    network: '',
    channel: 'Cash',
    cardProfileId: null,
  );
}

class _QuickAddPaymentData {
  const _QuickAddPaymentData({
    required this.method,
    required this.network,
    required this.channel,
    required this.cardProfileId,
  });

  final String method;
  final String network;
  final String channel;
  final int? cardProfileId;
}

class _QuickAddPaymentOption {
  const _QuickAddPaymentOption({
    required this.key,
    required this.label,
    required this.payment,
  });

  final String key;
  final String label;
  final _QuickAddPaymentData payment;
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
    required this.title,
    required this.amountText,
    required this.category,
    required this.paymentMethod,
    required this.currencyCode,
    required this.spentAt,
  });

  final String title;
  final String amountText;
  final String category;
  final String paymentMethod;
  final String currencyCode;
  final DateTime spentAt;
}

enum _FirstPaymentStep {
  chooseHowToPay,
  cardSetup,
  cashChoice,
}

