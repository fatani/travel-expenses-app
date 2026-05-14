import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/finance/manual_exchange_rate.dart';
import '../../../core/providers/database_providers.dart';
import '../../../l10n/app_localizations.dart';
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
  static const double _minBurnForEstimate = 0.01;
  static const double _maxReasonableRemainingDays = 60;

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
        _transactions.any((transaction) => transaction.type != CashTransactionType.cashExpenseDeduction);
  }

  _CashSituationMetrics get _cashMetrics {
    final currency = _primaryCashBalance.currencyCode;
    final cashExpenses = _transactions
        .where((transaction) =>
            transaction.currencyCode == currency &&
            transaction.type == CashTransactionType.cashExpenseDeduction)
        .toList();

    if (cashExpenses.isEmpty) {
      return const _CashSituationMetrics(
        hasBurnRateData: false,
        dailyBurn: 0,
        remainingDays: null,
        health: _CashHealth.medium,
      );
    }

    final totalCashExpenses = cashExpenses.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );
    final activeTravelDays = _calculateActiveTravelDays(cashExpenses);
    final dailyBurn = totalCashExpenses / activeTravelDays;

    if (dailyBurn < _minBurnForEstimate) {
      return const _CashSituationMetrics(
        hasBurnRateData: false,
        dailyBurn: 0,
        remainingDays: null,
        health: _CashHealth.medium,
      );
    }

    final rawRemainingDays = _primaryCashBalance.amount / dailyBurn;
    final remainingDays = rawRemainingDays.clamp(0, _maxReasonableRemainingDays).toDouble();

    final health = remainingDays >= 3
        ? _CashHealth.healthy
        : (remainingDays >= 1 ? _CashHealth.medium : _CashHealth.critical);

    return _CashSituationMetrics(
      hasBurnRateData: true,
      dailyBurn: dailyBurn,
      remainingDays: remainingDays,
      health: health,
    );
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
          currentBalance - _signedDelta(transaction.type, transaction.amount);
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

  _LastCashInEvent? get _lastCashInEvent {
    for (final transaction in _transactions) {
      if (transaction.type == CashTransactionType.atmWithdrawal) {
        return _LastCashInEvent(
          amount: transaction.amount,
          currencyCode: transaction.currencyCode,
          isAtm: true,
        );
      }
      if (transaction.type == CashTransactionType.initialCash ||
          transaction.type == CashTransactionType.manualAdjustment) {
        return _LastCashInEvent(
          amount: transaction.amount,
          currencyCode: transaction.currencyCode,
          isAtm: false,
        );
      }
    }
    return null;
  }

  double _signedDelta(CashTransactionType type, double amount) {
    switch (type) {
      case CashTransactionType.initialCash:
      case CashTransactionType.atmWithdrawal:
      case CashTransactionType.currencyExchangeIn:
      case CashTransactionType.manualAdjustment:
        return amount;
      case CashTransactionType.currencyExchangeOut:
      case CashTransactionType.cashExpenseDeduction:
        return -amount;
    }
  }

  double _calculateActiveTravelDays(List<CashTransaction> cashExpenses) {
    final now = DateTime.now();
    final tripStart = widget.trip.startDate?.toLocal();
    final tripEnd = widget.trip.endDate?.toLocal();

    DateTime activeStart;
    if (tripStart != null) {
      activeStart = DateTime(tripStart.year, tripStart.month, tripStart.day);
    } else {
      final firstExpense = cashExpenses
          .map((transaction) => transaction.createdAt.toLocal())
          .reduce((a, b) => a.isBefore(b) ? a : b);
      activeStart = DateTime(firstExpense.year, firstExpense.month, firstExpense.day);
    }

    final boundedEnd = (tripEnd != null && tripEnd.isBefore(now)) ? tripEnd : now;
    final activeEnd = DateTime(boundedEnd.year, boundedEnd.month, boundedEnd.day);

    if (activeEnd.isBefore(activeStart)) {
      return 1;
    }

    return activeEnd.difference(activeStart).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripDetailsCashWalletAction),
        actions: [
          IconButton(
            tooltip: l10n.manualExchangeAddRate,
            onPressed: _openAddManualRateSheet,
            icon: const Icon(Icons.currency_exchange),
          ),
        ],
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
                    metrics: _cashMetrics,
                    hasCashSetup: _hasCashSetup,
                    lastCashInEvent: _lastCashInEvent,
                    onAddCash: () => _showAddCashSheet(initialType: CashTransactionType.initialCash),
                    onAtmWithdrawal: () => _showAddCashSheet(initialType: CashTransactionType.atmWithdrawal),
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(title: l10n.cashWalletBalancesTitle),
                  const SizedBox(height: 10),
                  if (_balances.isEmpty)
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
                              balanceAfterTransaction: _balanceAfterByTransactionId[transaction.id],
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
          ),
        );
      },
    );

    if (result == true) {
      await _load();
    }
  }

  Future<void> _openAddManualRateSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddManualRateSheet(),
    );

    if (!mounted || result != true) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.manualExchangeSaved)),
    );
  }
}

class _AddCashSheet extends ConsumerStatefulWidget {
  const _AddCashSheet({
    required this.trip,
    required this.initialType,
  });

  final Trip trip;
  final CashTransactionType initialType;

  @override
  ConsumerState<_AddCashSheet> createState() => _AddCashSheetState();
}

class _AddManualRateSheet extends ConsumerStatefulWidget {
  const _AddManualRateSheet();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonEnterValidNumber)),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(manualExchangeRateRepositoryProvider).saveRate(
            ManualExchangeRate.create(
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.expenseFormSaveError('$error'))),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }
}

class _AddCashSheetState extends ConsumerState<_AddCashSheet> {
  final _amountController = TextEditingController();
  final _currencyController = TextEditingController();
  final _noteController = TextEditingController();
  CashTransactionType _selectedType = CashTransactionType.initialCash;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _currencyController.text = widget.trip.destinationCurrency;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

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
                  title: l10n.cashWalletAddCash,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.expenseFormAmountLabel,
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currencyController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.expenseFormCurrencyLabel,
                    hintText: 'THB',
                    prefixIcon: const Icon(Icons.currency_exchange_outlined),
                  ),
                ),
                const SizedBox(height: 12),
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
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text.trim());
    final currencyCode = _currencyController.text.trim().toUpperCase();

    if (amount == null || amount <= 0 || currencyCode.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonEnterValidNumber)),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(cashWalletRepositoryProvider).addCashTransaction(
            tripId: widget.trip.id,
            type: _selectedType,
            amount: amount,
            currencyCode: currencyCode,
            note: _noteController.text,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.expenseFormSaveError('$error'))),
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

enum _CashHealth { healthy, medium, critical }

class _CashSituationMetrics {
  const _CashSituationMetrics({
    required this.hasBurnRateData,
    required this.dailyBurn,
    required this.remainingDays,
    required this.health,
  });

  final bool hasBurnRateData;
  final double dailyBurn;
  final double? remainingDays;
  final _CashHealth health;
}

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
    required this.metrics,
    required this.hasCashSetup,
    required this.lastCashInEvent,
    required this.onAddCash,
    required this.onAtmWithdrawal,
  });

  final Trip trip;
  final _PrimaryCashBalance balance;
  final _CashSituationMetrics metrics;
  final bool hasCashSetup;
  final _LastCashInEvent? lastCashInEvent;
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
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/travel.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Color(0xFF7C3AED),
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cashWalletEmptyTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E1B4B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.cashWalletEmptySubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                          height: 1.4,
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

    final healthText = switch (metrics.health) {
      _CashHealth.healthy => l10n.cashWalletHealthHealthy,
      _CashHealth.medium => l10n.cashWalletHealthMedium,
      _CashHealth.critical => l10n.cashWalletHealthCritical,
    };

    final healthColor = switch (metrics.health) {
      _CashHealth.healthy => const Color(0xFF4F46E5),
      _CashHealth.medium => const Color(0xFFD97706),
      _CashHealth.critical => const Color(0xFFDC2626),
    };

    final burnValue = metrics.hasBurnRateData
        ? _formatAmount(metrics.dailyBurn, balance.currencyCode)
        : l10n.cashWalletBurnNoData;

    final remainingDaysText = metrics.hasBurnRateData && metrics.remainingDays != null
        ? l10n.cashWalletRemainingDaysMessage(
            NumberFormat('#,##0.#', 'en').format(metrics.remainingDays),
          )
        : l10n.cashWalletRemainingDaysNoData;

    final lastCashInText = switch (lastCashInEvent) {
      null => null,
      final event when event.isAtm => l10n.cashWalletLastAtmWithdrawal(
          _formatAmount(event.amount, event.currencyCode),
        ),
      final event => l10n.cashWalletLastCashAdded(
          _formatAmount(event.amount, event.currencyCode),
        ),
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
              const SizedBox(height: 14),
              _HeroPill(
                label: l10n.cashWalletHealthTitle,
                value: metrics.hasBurnRateData ? healthText : l10n.cashWalletHealthNotEnoughData,
                valueColor: metrics.hasBurnRateData ? healthColor : const Color(0xFF64748B),
              ),
              const SizedBox(height: 12),
              Text(
                remainingDaysText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${l10n.cashWalletDailyBurnTitle}: $burnValue',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (lastCashInText != null) ...[
                const SizedBox(height: 6),
                Text(
                  lastCashInText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                l10n.cashWalletCurrentBalanceHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
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
    final dateText = _formatTripDates(context, trip, localeName);
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

String _formatTripDates(BuildContext context, Trip trip, String localeName) {
  final l10n = AppLocalizations.of(context)!;
  if (trip.startDate == null || trip.endDate == null) {
    return l10n.cashWalletTripDatesPending;
  }

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
        subtitle: Text(
          DateFormat('dd MMM yyyy, HH:mm').format(balance.updatedAt.toLocal()),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
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
  });

  final CashTransaction transaction;
  final double? balanceAfterTransaction;

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
              ].join(' • '),
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

class _LastCashInEvent {
  const _LastCashInEvent({
    required this.amount,
    required this.currencyCode,
    required this.isAtm,
  });

  final double amount;
  final String currencyCode;
  final bool isAtm;
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

class _SheetGradientButton extends StatelessWidget {
  const _SheetGradientButton({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: onPressed == null ? 0.7 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 360,
            maxHeight: maxHeight,
            minWidth: double.infinity,
          ),
          child: Material(
            color: const Color(0xFFFCFAFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: child,
              ),
            ),
          ),
        ),
      ),
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
