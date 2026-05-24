import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/design_system/app_buttons.dart';
import '../../../core/design_system/app_confirmation_dialog.dart';
import '../../../core/design_system/app_surfaces.dart';
import '../../../core/design_system/calm_snackbar.dart';
import '../../../core/finance/manual_exchange_rate.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../expenses/presentation/expense_form_screen.dart';
import '../../trips/domain/country_database.dart';
import '../../trips/domain/country_info.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/trip_title_resolver.dart';
import '../domain/cash_transaction.dart';
import '../domain/trip_cash_balance.dart';

enum _TransactionTimeGroup { today, yesterday, earlier }

class TripCashWalletScreen extends ConsumerStatefulWidget {
  const TripCashWalletScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripCashWalletScreen> createState() => _TripCashWalletScreenState();
}

class _TripCashWalletScreenState extends ConsumerState<TripCashWalletScreen> {
  bool _isLoading = true;
  List<TripCashBalance> _balances = const [];
  List<CashTransaction> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    // Replace with your actual data loading logic
    final balances = await ref.read(cashWalletRepositoryProvider).getBalancesByTrip(widget.trip.id);
    final transactions = await ref.read(cashWalletRepositoryProvider).getRecentTransactionsByTrip(widget.trip.id);
    if (!mounted) return;
    setState(() {
      _balances = balances;
      _transactions = transactions;
      _isLoading = false;
    });
  }

  _PrimaryCashBalance get _primaryCashBalance {
    final primaryCurrency = widget.trip.destinationCurrency.trim().toUpperCase();
    for (final balance in _balances) {
      if (balance.currencyCode == primaryCurrency) {
        return _PrimaryCashBalance(
          currencyCode: balance.currencyCode,
          amount: balance.balanceAmount,
        );
      }
    }
    if (_balances.isNotEmpty) {
      return _PrimaryCashBalance(
        currencyCode: _balances.first.currencyCode,
        amount: _balances.first.balanceAmount,
      );
    }
    return _PrimaryCashBalance(
      currencyCode: primaryCurrency,
      amount: 0,
    );
  }

  bool get _hasCashSetup {
    return _balances.isNotEmpty ||
        _transactions.any(
          (transaction) =>
              transaction.type != CashTransactionType.cashExpenseDeduction,
        );
  }

  double get _primaryCurrencyTotalCashIn {
    final primaryCurrency = _primaryCashBalance.currencyCode;
    return _transactions.where((transaction) {
      if (transaction.currencyCode != primaryCurrency) {
        return false;
      }

      return transaction.type == CashTransactionType.initialCash ||
          transaction.type == CashTransactionType.atmWithdrawal ||
          transaction.type == CashTransactionType.manualAdjustment ||
          transaction.type == CashTransactionType.currencyExchangeIn;
    }).fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  _CashHealth get _cashHealth {
    final currentBalance = _primaryCashBalance.amount;

    if (currentBalance <= 0) {
      return _CashHealth.critical;
    }

    final totalCashIn = _primaryCurrencyTotalCashIn;

    if (totalCashIn <= 0) {
      return _CashHealth.good;
    }

    final remainingRatio = currentBalance / totalCashIn;

    if (remainingRatio >= 0.65) {
      return _CashHealth.excellent;
    }
    if (remainingRatio >= 0.35) {
      return _CashHealth.good;
    }
    if (remainingRatio >= 0.15) {
      return _CashHealth.low;
    }
    return _CashHealth.critical;
  }

  Map<String, double> get _balanceAfterByTransactionId {
    final runningByCurrency = <String, double>{
      for (final balance in _balances) balance.currencyCode: balance.balanceAmount,
    };
    final result = <String, double>{};

    for (final transaction in _transactions) {
      final currentBalance = runningByCurrency[transaction.currencyCode] ?? 0;
      result[transaction.id] = currentBalance;
      runningByCurrency[transaction.currencyCode] =
          currentBalance - transaction.type.signedDelta(transaction.amount);
    }

    return result;
  }

  Map<_TransactionTimeGroup, List<CashTransaction>> get _groupedTransactions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final grouped = <_TransactionTimeGroup, List<CashTransaction>>{
      _TransactionTimeGroup.today: <CashTransaction>[],
      _TransactionTimeGroup.yesterday: <CashTransaction>[],
      _TransactionTimeGroup.earlier: <CashTransaction>[],
    };

    for (final transaction in _transactions) {
      final transactionDay = DateTime(
        transaction.createdAt.toLocal().year,
        transaction.createdAt.toLocal().month,
        transaction.createdAt.toLocal().day,
      );

      if (transactionDay == today) {
        grouped[_TransactionTimeGroup.today]!.add(transaction);
      } else if (transactionDay == yesterday) {
        grouped[_TransactionTimeGroup.yesterday]!.add(transaction);
      } else {
        grouped[_TransactionTimeGroup.earlier]!.add(transaction);
      }
    }

    return grouped;
  }

  _LastAtmWithdrawalEvent? get _lastAtmWithdrawalEvent {
    for (final transaction in _transactions) {
      if (transaction.type == CashTransactionType.atmWithdrawal) {
        return _LastAtmWithdrawalEvent(
          amount: transaction.amount,
          currencyCode: transaction.currencyCode,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unknownBalanceMessage = l10n.cashWalletBalanceUnknownExpensesFirst;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripDetailsCashWalletAction),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 20),
                children: [
                  _TripContextCard(trip: widget.trip),
                  const SizedBox(height: 14),
                  _CashHeroCard(
                    trip: widget.trip,
                    balance: _primaryCashBalance,
                    health: _cashHealth,
                    hasCashSetup: _hasCashSetup,
                    totalCashIn: _primaryCurrencyTotalCashIn,
                    lastAtmWithdrawalEvent: _lastAtmWithdrawalEvent,
                    onAddCash: () => _showAddCashSheet(initialType: CashTransactionType.initialCash),
                    onAtmWithdrawal: () => _showAddCashSheet(initialType: CashTransactionType.atmWithdrawal),
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(title: l10n.cashWalletBalancesTitle),
                  const SizedBox(height: 10),
                  if (!_hasCashSetup)
                    _EmptyCard(message: unknownBalanceMessage)
                  else if (_balances.isEmpty)
                    _EmptyCard(message: l10n.cashWalletNoBalances)
                  else ...[
                    for (final balance in _balances)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BalanceTile(balance: balance),
                      ),
                  ],
                  const SizedBox(height: 22),
                  _SectionHeader(title: l10n.cashWalletRecentTransactionsTitle),
                  const SizedBox(height: 10),
                  if (_transactions.isEmpty)
                    _EmptyCard(message: l10n.cashWalletNoTransactions)
                  else ...[
                    for (final group in _TransactionTimeGroup.values)
                      if (_groupedTransactions[group]!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _groupTitle(l10n, group),
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: const Color(0xFF6D28D9),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        for (final transaction in _groupedTransactions[group]!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TransactionTile(
                              transaction: transaction,
                              balanceAfterTransaction: _hasCashSetup
                                  ? _balanceAfterByTransactionId[transaction.id]
                                  : null,
                              onEdit: _canEditManualTransaction(transaction)
                                  ? () => _showAddCashSheet(
                                        initialType: transaction.type,
                                        editingTransaction: transaction,
                                      )
                                  : null,
                              onDelete: _canDeleteManualTransaction(transaction)
                                  ? () => _confirmDeleteManualTransaction(transaction)
                                  : null,
                              onEditExpense: _canEditLinkedExpense(transaction)
                                  ? () => _openLinkedExpenseEditor(transaction)
                                  : null,
                            ),
                          ),
                        const SizedBox(height: 4),
                      ],
                  ],
                ],
              ),
            ),
    );
  }

  String _groupTitle(AppLocalizations l10n, _TransactionTimeGroup group) {
    switch (group) {
      case _TransactionTimeGroup.today:
        return l10n.cashWalletGroupToday;
      case _TransactionTimeGroup.yesterday:
        return l10n.cashWalletGroupYesterday;
      case _TransactionTimeGroup.earlier:
        return l10n.cashWalletGroupEarlier;
    }
  }



  Future<void> _showAddCashSheet({
    required CashTransactionType initialType,
    CashTransaction? editingTransaction,
    bool isOnboarding = false,
  }) async {
    debugPrint('Opening Add Cash Sheet: $initialType');
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: _AddCashSheet(
            trip: widget.trip,
            initialType: initialType,
            editingTransaction: editingTransaction,
            isOnboarding: isOnboarding,
          ),
        );
      },
    );

    if (result == true) {
      await _load();
    }
  }

  bool _canEditManualTransaction(CashTransaction transaction) {
    if (transaction.isReversed || transaction.expenseId != null) {
      return false;
    }
    return transaction.type == CashTransactionType.initialCash ||
        transaction.type == CashTransactionType.atmWithdrawal ||
        transaction.type == CashTransactionType.currencyExchangeIn ||
        transaction.type == CashTransactionType.manualAdjustment;
  }

  bool _canDeleteManualTransaction(CashTransaction transaction) {
    return _canEditManualTransaction(transaction);
  }

  bool _canEditLinkedExpense(CashTransaction transaction) {
    return transaction.type == CashTransactionType.cashExpenseDeduction &&
        transaction.expenseId != null &&
        transaction.expenseId!.isNotEmpty;
  }

  Future<void> _confirmDeleteManualTransaction(CashTransaction transaction) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (sheetContext) {
        final typeLabel = _transactionTypeLabel(l10n, transaction.type);
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
              icon: _deleteIconForTransactionType(transaction.type),
              title: l10n.cashWalletDeleteTransactionTitleForType(typeLabel),
              message: l10n.cashWalletDeleteTransactionMessage,
              cancelLabel: l10n.commonCancel,
              confirmLabel: l10n.commonDelete,
              onCancel: () => Navigator.of(sheetContext).pop(false),
              onConfirm: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    try {
      await ref
          .read(cashWalletRepositoryProvider)
          .reverseManualCashTransaction(transaction: transaction);
      if (!mounted) {
        return;
      }
      await _load();
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

  String _transactionTypeLabel(AppLocalizations l10n, CashTransactionType type) {
    switch (type) {
      case CashTransactionType.initialCash:
        return l10n.cashWalletTypeInitialCash;
      case CashTransactionType.atmWithdrawal:
        return l10n.cashWalletTypeAtmWithdrawal;
      case CashTransactionType.currencyExchangeIn:
        return l10n.cashWalletTypeCurrencyExchangeIn;
      case CashTransactionType.currencyExchangeOut:
        return l10n.cashWalletTypeCurrencyExchangeOut;
      case CashTransactionType.manualAdjustment:
        return l10n.cashWalletTypeManualAdjustment;
      case CashTransactionType.cashExpenseDeduction:
        return l10n.cashWalletTypeCashExpense;
    }
  }

  IconData _deleteIconForTransactionType(CashTransactionType type) {
    switch (type) {
      case CashTransactionType.atmWithdrawal:
        return Icons.local_atm_outlined;
      case CashTransactionType.manualAdjustment:
        return Icons.tune_rounded;
      case CashTransactionType.initialCash:
        return Icons.account_balance_wallet_outlined;
      case CashTransactionType.currencyExchangeIn:
      case CashTransactionType.currencyExchangeOut:
        return Icons.currency_exchange_outlined;
      case CashTransactionType.cashExpenseDeduction:
        return Icons.receipt_long_outlined;
    }
  }

  Future<void> _openLinkedExpenseEditor(CashTransaction transaction) async {
    final expenseId = transaction.expenseId;
    if (expenseId == null || expenseId.isEmpty) {
      return;
    }

    final expense = await ref.read(expenseRepositoryProvider).getExpenseById(expenseId);
    if (!mounted) {
      return;
    }

    if (expense == null) {
      final l10n = AppLocalizations.of(context)!;
      CalmSnackBar.showMessage(context, message: l10n.tripDetailsLoadError);
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseFormScreen(
          trip: widget.trip,
          expense: expense,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _load();
  }
}

class _AddCashSheet extends ConsumerStatefulWidget {
  const _AddCashSheet({
    required this.trip,
    required this.initialType,
    this.editingTransaction,
    this.isOnboarding = false,
  });

  final Trip trip;
  final CashTransactionType initialType;
  final CashTransaction? editingTransaction;
  final bool isOnboarding;

  @override
  ConsumerState<_AddCashSheet> createState() => _AddCashSheetState();
}

class _AddManualRateSheet extends ConsumerStatefulWidget {
  const _AddManualRateSheet({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_AddManualRateSheet> createState() => _AddManualRateSheetState();
}

class _AddManualRateSheetState extends ConsumerState<_AddManualRateSheet> {
  final _fromCurrencyController = TextEditingController();
  final _toCurrencyController = TextEditingController();
  final _rateController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _fromCurrencyController.dispose();
    _toCurrencyController.dispose();
    _rateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _PremiumSheetContainer(
      viewInsetsBottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            icon: Icons.currency_exchange,
            title: l10n.manualExchangeAddRate,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fromCurrencyController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: l10n.manualExchangeFromCurrency,
              prefixIcon: const Icon(Icons.call_made_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _toCurrencyController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: l10n.manualExchangeToCurrency,
              prefixIcon: const Icon(Icons.call_received_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              labelText: l10n.manualExchangeRate,
              prefixIcon: const Icon(Icons.percent_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: l10n.manualExchangeSourceNote,
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 18),
          _SheetGradientButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(l10n.tripDetailsQuickAddSave),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final fromCurrency = _fromCurrencyController.text.trim().toUpperCase();
    final toCurrency = _toCurrencyController.text.trim().toUpperCase();
    final rate = double.tryParse(_rateController.text.trim());

    if (fromCurrency.length != 3 || toCurrency.length != 3 || rate == null || rate <= 0) {
      CalmSnackBar.showMessage(context, message: l10n.commonEnterValidNumber);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(manualExchangeRateRepositoryProvider).saveRate(
            ManualExchangeRate.create(
              tripId: widget.tripId,
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              rate: rate,
              sourceNote: _noteController.text,
            ),
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      CalmSnackBar.showMessage(context, message: l10n.manualExchangeSaveError);
      setState(() {
        _isSaving = false;
      });
    }
  }
}



class _AddCashSheetState extends ConsumerState<_AddCashSheet> {
  final _amountController = TextEditingController();
  final _homeValueController = TextEditingController();
  final _noteController = TextEditingController();
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late String _selectedCurrencyCode;
  CashTransactionType _selectedType = CashTransactionType.initialCash;
  DateTime? _selectedDateTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    final editingTransaction = widget.editingTransaction;
    if (editingTransaction != null) {
      _selectedType = editingTransaction.type;
      _amountController.text = editingTransaction.amount.toStringAsFixed(2);
      _selectedCurrencyCode = editingTransaction.currencyCode.trim().toUpperCase();
      if (editingTransaction.homeCurrencyAmount != null) {
        _homeValueController.text = editingTransaction.homeCurrencyAmount!.toStringAsFixed(2);
      }
      _noteController.text = editingTransaction.note ?? '';
      _selectedDateTime = editingTransaction.createdAt.toLocal();
      return;
    }

    _selectedType = widget.initialType;
    _selectedCurrencyCode = widget.trip.destinationCurrency.trim().toUpperCase();
    _selectedDateTime = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDateTimeFields();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _homeValueController.dispose();
    _noteController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final isEditMode = widget.editingTransaction != null;
    final isOnboardingMode = widget.isOnboarding && !isEditMode;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 420,
            maxHeight: maxHeight,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetHeader(
                  icon: Icons.account_balance_wallet_outlined,
                  title: isEditMode
                      ? l10n.cashWalletEditCash
                      : (isOnboardingMode
                          ? l10n.cashWalletOnboardingTitle
                          : l10n.cashWalletAddCash),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.cashWalletCashAmountLabel,
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _isSaving ? null : _pickCurrency,
                  child: Builder(builder: (ctx) {
                    final isArabic =
                        Localizations.localeOf(ctx).languageCode == 'ar';
                    final entry = CountryDatabase.countries.firstWhere(
                      (c) => c.currencyCode == _selectedCurrencyCode,
                      orElse: () => CountryInfo(
                        countryCode: '',
                        englishName: _selectedCurrencyCode,
                        arabicName: _selectedCurrencyCode,
                        currencyCode: _selectedCurrencyCode,
                        currencyName: '',
                        flagEmoji: '🏳',
                      ),
                    );
                    return InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.cashWalletCashCurrencyLabel,
                        prefixIcon: const Icon(Icons.currency_exchange_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Row(
                        children: [
                          Text(entry.flagEmoji,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${entry.getLocalizedName(isArabic)} | ${entry.currencyCode}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _homeValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.cashWalletHomeValueLabel,
                    helperText: l10n.cashWalletHomeValueHelper,
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                if (!isOnboardingMode) ...[
                  DropdownButtonFormField<CashTransactionType>(
                    initialValue: _selectedType,
                    decoration: InputDecoration(
                      labelText: l10n.cashWalletTransactionType,
                      helperText: l10n.cashWalletTransactionTypeHelper,
                      prefixIcon: const Icon(Icons.tune_rounded),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: CashTransactionType.initialCash,
                        child: _CashActionOptionRow(
                          icon: Icons.luggage_outlined,
                          label: l10n.cashWalletTypeInitialCash,
                        ),
                      ),
                      DropdownMenuItem(
                        value: CashTransactionType.atmWithdrawal,
                        child: _CashActionOptionRow(
                          icon: Icons.local_atm_outlined,
                          label: l10n.cashWalletTypeAtmWithdrawal,
                        ),
                      ),
                      DropdownMenuItem(
                        value: CashTransactionType.currencyExchangeIn,
                        child: _CashActionOptionRow(
                          icon: Icons.currency_exchange_outlined,
                          label: l10n.cashWalletTypeCurrencyExchangeIn,
                        ),
                      ),
                      DropdownMenuItem(
                        value: CashTransactionType.manualAdjustment,
                        child: _CashActionOptionRow(
                          icon: Icons.edit_note_rounded,
                          label: l10n.cashWalletTypeManualAdjustment,
                        ),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedType = value;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: l10n.expenseFormNoteLabel,
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: l10n.cashWalletDateLabel,
                            prefixIcon: const Icon(Icons.calendar_today_rounded),
                          ),
                          onTap: _selectDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _timeController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: l10n.cashWalletTimeLabel,
                            prefixIcon: const Icon(Icons.access_time_rounded),
                          ),
                          onTap: _selectTime,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                _SheetGradientButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isEditMode
                              ? l10n.expenseFormSaveEdit
                              : (isOnboardingMode
                                  ? l10n.cashWalletAddCash
                                  : l10n.tripDetailsQuickAddSave),
                        ),
                ),
                if (isOnboardingMode) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(l10n.cashWalletOnboardingSkip),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncDateTimeFields() {
    final dt = _selectedDateTime;
    if (dt == null) {
      _dateController.text = '';
      _timeController.text = '';
      return;
    }
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    _dateController.text = DateFormat('dd MMM yyyy', localeTag).format(dt);
    _timeController.text = DateFormat('HH:mm', localeTag).format(dt);
  }

  Future<void> _selectDate() async {
    final base = _selectedDateTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(base),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        base.hour,
        base.minute,
      );
      _syncDateTimeFields();
    });
  }

  Future<void> _selectTime() async {
    final base = _selectedDateTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateTime = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      _syncDateTimeFields();
    });
  }

  Future<void> _pickCurrency() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final tripDest = widget.trip.destinationCurrency.trim().toUpperCase();
    final tripHome = widget.trip.homeCurrencySnapshot.trim().toUpperCase();

    // Deduplicate: first occurrence per currency code from CountryDatabase.
    final seen = <String>{};
    final allUnique = <CountryInfo>[];
    for (final c in CountryDatabase.countries) {
      if (seen.add(c.currencyCode)) allUnique.add(c);
    }

    // Pinned: trip currencies first, then rest sorted by code.
    final pinned = allUnique
        .where((c) => c.currencyCode == tripDest || c.currencyCode == tripHome)
        .toList();
    final rest = allUnique
        .where((c) => c.currencyCode != tripDest && c.currencyCode != tripHome)
        .toList()
      ..sort((a, b) => a.currencyCode.compareTo(b.currencyCode));
    final fullList = [...pinned, ...rest];

    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrencyPickerSheet(
        allEntries: fullList,
        selectedCode: _selectedCurrencyCode,
        isArabic: isArabic,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedCurrencyCode = picked;
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text.trim());
    final homeValueText = _homeValueController.text.trim();
    final double? homeValue = homeValueText.isEmpty
        ? null
        : double.tryParse(homeValueText);
    final currencyCode = _selectedCurrencyCode.trim().toUpperCase();
    final homeCurrencyCode = widget.trip.homeCurrencySnapshot.trim().toUpperCase();

    final allowsZeroAmount =
        _selectedType == CashTransactionType.initialCash;

    String? validationMessage;
    if (amount == null) {
      validationMessage = l10n.cashWalletValidationInvalidAmount;
    } else if (amount < 0) {
      validationMessage = l10n.cashWalletValidationNegativeAmount;
    } else if (amount == 0 && !allowsZeroAmount) {
      validationMessage = l10n.cashWalletValidationInvalidAmount;
    } else if (currencyCode.length != 3 ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
      validationMessage = l10n.cashWalletValidationInvalidCurrency;
    } else if (homeValueText.isNotEmpty && homeValue == null) {
      validationMessage = l10n.commonEnterValidNumber;
    }

    if (validationMessage != null) {
      CalmSnackBar.showMessage(context, message: validationMessage);
      return;
    }

    final validAmount = amount!;

    setState(() {
      _isSaving = true;
    });

    try {
      final editingTransaction = widget.editingTransaction;
      if (editingTransaction != null) {
        await ref.read(cashWalletRepositoryProvider).updateManualCashTransaction(
              existingTransaction: editingTransaction,
              nextType: _selectedType,
              nextAmount: validAmount,
              nextCurrencyCode: currencyCode,
              nextHomeCurrencyAmount: homeValue,
              nextHomeCurrencyCode: homeCurrencyCode,
              nextNote: _noteController.text,
              nextCreatedAt: _selectedDateTime,
            );
      } else {
        await ref.read(cashWalletRepositoryProvider).addCashTransaction(
              tripId: widget.trip.id,
              type: _selectedType,
              amount: validAmount,
              currencyCode: currencyCode,
              homeCurrencyAmount: homeValue,
              homeCurrencyCode: homeCurrencyCode,
              note: _noteController.text,
              createdAt: _selectedDateTime,
            );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      CalmSnackBar.showMessage(
        context,
        message: l10n.expenseFormSaveError('$error'),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E1B4B),
          ),
    );
  }
}

enum _CashHealth { excellent, good, low, critical }

class _PrimaryCashBalance {
  const _PrimaryCashBalance({
    required this.currencyCode,
    required this.amount,
  });

  final String currencyCode;
  final double amount;
}

class _CashHeroCard extends StatelessWidget {
  const _CashHeroCard({
    required this.trip,
    required this.balance,
    required this.health,
    required this.hasCashSetup,
    required this.totalCashIn,
    required this.lastAtmWithdrawalEvent,
    required this.onAddCash,
    required this.onAtmWithdrawal,
  });

  final Trip trip;
  final _PrimaryCashBalance balance;
  final _CashHealth health;
  final bool hasCashSetup;
  final double totalCashIn;
  final _LastAtmWithdrawalEvent? lastAtmWithdrawalEvent;
  final VoidCallback onAddCash;
  final VoidCallback onAtmWithdrawal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final amountText = _formatAmount(balance.amount, balance.currencyCode);

    if (!hasCashSetup) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.cashTrackingNotStarted,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onAddCash,
                child: Text(l10n.cashWalletAddCash),
              ),
            ],
          ),
        ),
      );
    }

    final healthText = switch (health) {
      _CashHealth.excellent => l10n.cashWalletHealthExcellent,
      _CashHealth.good => l10n.cashWalletHealthHealthy,
      _CashHealth.low => l10n.cashWalletHealthLow,
      _CashHealth.critical => l10n.cashWalletHealthCritical,
    };

    final healthColor = switch (health) {
      _CashHealth.excellent => const Color(0xFF4F46E5),
      _CashHealth.good => const Color(0xFF6D28D9),
      _CashHealth.low => const Color(0xFFD97706),
      _CashHealth.critical => const Color(0xFFDC2626),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF1FF), Color(0xFFF7EEFF)],
          ),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.cashWalletHeroTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4C1D95),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.cashWalletHeroSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5B5F7A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Directionality(
                textDirection: TextDirection.ltr,
                child: _ResponsiveHeroBalanceText(text: amountText),
              ),
              if (totalCashIn > 0) ...[
                const SizedBox(height: 14),
                _HeroPill(
                  label: l10n.cashWalletHealthTitle,
                  value: healthText,
                  valueColor: healthColor,
                ),
              ],
              if (lastAtmWithdrawalEvent != null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.cashWalletLastAtmWithdrawal(
                    _formatAmount(
                      lastAtmWithdrawalEvent!.amount,
                      lastAtmWithdrawalEvent!.currencyCode,
                    ),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _HeroPrimaryActionButton(
                      label: l10n.cashWalletAddCash,
                      onPressed: onAddCash,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeroSecondaryActionButton(
                    label: l10n.cashWalletQuickAtmShort,
                    onPressed: onAtmWithdrawal,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveHeroBalanceText extends StatelessWidget {
  const _ResponsiveHeroBalanceText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
          height: 0.98,
          letterSpacing: -0.8,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = width < 300
            ? 0.78
            : (width < 340 ? 0.86 : 1.0);

        final style = (baseStyle ?? const TextStyle()).copyWith(
          fontSize: (baseStyle?.fontSize ?? 36) * scale,
        );

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(text, maxLines: 1, style: style),
        );
      },
    );
  }
}

class _HeroPrimaryActionButton extends StatelessWidget {
  const _HeroPrimaryActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HeroSecondaryActionButton extends StatelessWidget {
  const _HeroSecondaryActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: const Color(0xFF312E81),
        backgroundColor: const Color(0xFFEDE9FE),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.local_atm_outlined, size: 18),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? const Color(0xFF0F172A),
                ),
          ),
        ],
      ),
    );
  }
}

class _TripContextCard extends StatelessWidget {
  const _TripContextCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = TripTitleResolver.resolve(trip, isArabic);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final hasTripDates = trip.startDate != null && trip.endDate != null;
    final dateText = hasTripDates
        ? _formatTripDates(trip, localeName)
        : null;
    final tripStatus = _formatTripStatus(context, trip);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/travel.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.luggage_outlined,
                  color: Color(0xFF7C3AED),
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                      ),
                    ),
                    if (tripStatus != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: _InfoChip(
                          icon: Icons.schedule,
                          label: tripStatus,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  trip.destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.currency_exchange_outlined,
                      label: trip.destinationCurrency.trim().toUpperCase(),
                    ),
                    if (dateText != null)
                      _InfoChip(
                        icon: Icons.calendar_month_outlined,
                        label: dateText,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF6D28D9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF4C1D95),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(double amount, String currencyCode) {
  final formatter = NumberFormat('#,##0.##', 'en');
  return '${formatter.format(amount)} ${currencyCode.trim().toUpperCase()}';
}

String _formatTripDates(Trip trip, String localeName) {
  final formatter = DateFormat('dd MMM', localeName);
  return '${formatter.format(trip.startDate!.toLocal())} - ${formatter.format(trip.endDate!.toLocal())}';
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.balance});

  final TripCashBalance balance;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0.##', 'en');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          balance.currencyCode.trim().toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F2FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '${formatter.format(balance.balanceAmount)} ${balance.currencyCode}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4C1D95),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.balanceAfterTransaction,
    this.onEdit,
    this.onDelete,
    this.onEditExpense,
  });

  final CashTransaction transaction;
  final double? balanceAfterTransaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onEditExpense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final formatter = NumberFormat('#,##0.##', 'en');
    final sign = _isNegative(transaction.type) ? '-' : '+';
    final amountColor = _isNegative(transaction.type)
        ? const Color(0xFFB45309)
        : const Color(0xFF4C1D95);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          _typeLabel(l10n, transaction.type),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F2937),
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                DateFormat('dd MMM yyyy, HH:mm').format(transaction.createdAt.toLocal()),
                if (transaction.note != null && transaction.note!.isNotEmpty)
                  transaction.note!,
              ].join(' | '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
            ),
            if (balanceAfterTransaction != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.cashWalletBalanceAfterTransaction(
                    '${formatter.format(balanceAfterTransaction)} ${transaction.currencyCode}',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            if (onEdit != null || onDelete != null || onEditExpense != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onEditExpense != null)
                      _ExpenseLinkActionButton(
                        onPressed: onEditExpense,
                        icon: Icons.receipt_long_outlined,
                        label: l10n.cashWalletEditExpenseAction,
                      ),
                    if (onEdit != null)
                      _SoftLedgerIconButton(
                        onPressed: onEdit,
                        icon: Icons.edit_outlined,
                        tooltip: l10n.commonEdit,
                      ),
                    if (onDelete != null)
                      _SoftLedgerIconButton(
                        onPressed: onDelete,
                        icon: Icons.delete_outline_rounded,
                        tooltip: l10n.commonDelete,
                        foregroundColor: const Color(0xFFB42318),
                        backgroundColor: const Color(0xFFFEE4E2),
                      ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F2FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$sign${formatter.format(transaction.amount)} ${transaction.currencyCode.trim().toUpperCase()}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: amountColor,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isNegative(CashTransactionType type) {
    return type == CashTransactionType.cashExpenseDeduction ||
        type == CashTransactionType.currencyExchangeOut;
  }

  String _typeLabel(AppLocalizations l10n, CashTransactionType type) {
    switch (type) {
      case CashTransactionType.initialCash:
        return l10n.cashWalletTypeInitialCash;
      case CashTransactionType.atmWithdrawal:
        return l10n.cashWalletTypeAtmWithdrawal;
      case CashTransactionType.currencyExchangeIn:
        return l10n.cashWalletTypeCurrencyExchangeIn;
      case CashTransactionType.currencyExchangeOut:
        return l10n.cashWalletTypeCurrencyExchangeOut;
      case CashTransactionType.manualAdjustment:
        return l10n.cashWalletTypeManualAdjustment;
      case CashTransactionType.cashExpenseDeduction:
        return l10n.cashWalletTypeCashExpense;
    }
  }
}

class _LastAtmWithdrawalEvent {
  const _LastAtmWithdrawalEvent({
    required this.amount,
    required this.currencyCode,
  });

  final double amount;
  final String currencyCode;
}

class _SoftLedgerIconButton extends StatelessWidget {
  const _SoftLedgerIconButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.foregroundColor = const Color(0xFF6D28D9),
    this.backgroundColor = const Color(0xFFF3E8FF),
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}

class _ExpenseLinkActionButton extends StatelessWidget {
  const _ExpenseLinkActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: const Color(0xFF5B21B6)),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF5B21B6),
              fontWeight: FontWeight.w700,
            ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFD6BBFB)),
        backgroundColor: const Color(0xFFF9F5FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

String? _formatTripStatus(BuildContext context, Trip trip) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = trip.startDate != null
      ? DateTime(trip.startDate!.toLocal().year, trip.startDate!.toLocal().month, trip.startDate!.toLocal().day)
      : null;
  final end = trip.endDate != null
      ? DateTime(trip.endDate!.toLocal().year, trip.endDate!.toLocal().month, trip.endDate!.toLocal().day)
      : null;

  if (start != null && today.isBefore(start)) {
    final days = start.difference(today).inDays;
    if (days <= 0) {
      return l10n.cashWalletTripStatusStartsToday;
    }
    return l10n.cashWalletTripStatusStartsIn(days);
  }

  if (start != null && end != null && (today.isAtSameMomentAs(start) || (today.isAfter(start) && !today.isAfter(end)))) {
    return l10n.cashWalletTripStatusActive;
  }

  if (end != null && today.isAfter(end)) {
    return l10n.cashWalletTripStatusCompleted;
  }

  return null;
}

// ── Currency picker sheet ──────────────────────────────────────────────────

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({
    required this.allEntries,
    required this.selectedCode,
    required this.isArabic,
  });

  final List<CountryInfo> allEntries;
  final String selectedCode;
  final bool isArabic;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _searchController = TextEditingController();
  late List<CountryInfo> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.allEntries;
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.allEntries
          : widget.allEntries.where((c) => c.matchesSearch(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.cashWalletSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Icon(Icons.search_off, size: 48, color: Color(0xFFCBD5E1)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final entry = _filtered[i];
                          final isSelected =
                              entry.currencyCode == widget.selectedCode;
                          return ListTile(
                            leading: Text(entry.flagEmoji,
                                style: const TextStyle(fontSize: 22)),
                            title: Text(
                              entry.getLocalizedName(widget.isArabic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${entry.currencyCode} | ${entry.currencyName}',
                              textDirection: TextDirection.ltr,
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_rounded,
                                    color: Color(0xFF4F46E5))
                                : null,
                            onTap: () =>
                                Navigator.of(ctx).pop(entry.currencyCode),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetGradientButton extends StatelessWidget {
  const _SheetGradientButton({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(onPressed: onPressed, child: child);
  }
}

class _PremiumSheetContainer extends StatelessWidget {
  const _PremiumSheetContainer({
    required this.viewInsetsBottom,
    required this.child,
  });

  final double viewInsetsBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: AppDurations.fast,
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: AppBottomSheetContainer(child: child),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF5B21B6), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E1B4B),
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CashActionOptionRow extends StatelessWidget {
  const _CashActionOptionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6D28D9)),
        const SizedBox(width: 10),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
