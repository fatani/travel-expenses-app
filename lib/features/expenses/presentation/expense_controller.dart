import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../global_reports/data/global_report_provider.dart';
import '../../reports/data/trip_report_provider.dart';
import '../domain/expense.dart';
import '../domain/money_model.dart';

class ExpenseCreateOutcome {
  const ExpenseCreateOutcome({
    required this.cashBalanceInsufficient,
    required this.noCashBalanceRecorded,
  });

  final bool cashBalanceInsufficient;
  final bool noCashBalanceRecorded;
}

final expenseControllerProvider =
    AsyncNotifierProvider.family<ExpenseController, List<Expense>, String>(
      ExpenseController.new,
    );

class ExpenseController extends FamilyAsyncNotifier<List<Expense>, String> {
  late final String _tripId;

  @override
  Future<List<Expense>> build(String tripId) {
    _tripId = tripId;
    return _loadExpenses();
  }

  Future<void> reload() async {
    state = const AsyncLoading();

    try {
      state = AsyncData(await _loadExpenses());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<ExpenseCreateOutcome> createExpense({
    required String title,
    required double amount,
    required String currencyCode,
    MoneyModel? moneyModel,
    double? transactionAmount,
    String? transactionCurrency,
    double? originalAmount,
    String? originalCurrency,
    double? convertedHomeAmount,
    String? homeCurrency,
    double? conversionRate,
    double? billedAmount,
    String? billedCurrency,
    double? feesAmount,
    String? feesCurrency,
    double? totalChargedAmount,
    String? totalChargedCurrency,
    bool? isInternational,
    required String category,
    required DateTime spentAt,
    required String paymentMethod,
    String? paymentNetwork,
    String? paymentChannel,
    String source = 'manual',
    String? note,
    String? rawSmsText,
    int? cardProfileId,
    String? tripHomeCurrency,
  }) async {
    final normalizedMoney = moneyModel ??
        MoneyModel(
          transactionAmount: transactionAmount ?? amount,
          transactionCurrency: transactionCurrency ?? currencyCode,
          billedAmount: billedAmount,
          billedCurrency: billedCurrency,
          feesAmount: feesAmount,
          feesCurrency: feesCurrency,
          totalChargedAmount: totalChargedAmount,
          totalChargedCurrency: totalChargedCurrency,
          isInternational: isInternational ?? false,
        );

    final normalizedOriginalAmount =
        originalAmount ?? normalizedMoney.transactionAmount ?? amount;
    final normalizedOriginalCurrency =
        (originalCurrency ?? normalizedMoney.transactionCurrency ?? currencyCode)
            .trim()
            .toUpperCase();
    final normalizedHomeCurrency = tripHomeCurrency?.trim().toUpperCase();

    double? computedConvertedHomeAmount = convertedHomeAmount;
    double? computedConversionRate = conversionRate;
    String? computedHomeCurrency = homeCurrency;

    if (normalizedHomeCurrency != null &&
        normalizedHomeCurrency.isNotEmpty &&
        computedConvertedHomeAmount == null &&
        normalizedOriginalCurrency != normalizedHomeCurrency) {
      try {
        final conversion = await ref
            .read(manualCurrencyConversionServiceProvider)
            .convert(
              amount: normalizedOriginalAmount,
              fromCurrency: normalizedOriginalCurrency,
              toCurrency: normalizedHomeCurrency,
            );

        if (conversion != null) {
          computedConvertedHomeAmount = conversion.convertedAmount;
          computedConversionRate = conversion.rate;
          computedHomeCurrency = normalizedHomeCurrency;
        }
      } catch (_) {
        // Conversion must never block expense saving.
      }
    } else if (normalizedHomeCurrency != null &&
        normalizedHomeCurrency.isNotEmpty &&
        normalizedOriginalCurrency == normalizedHomeCurrency &&
        computedConvertedHomeAmount == null) {
      computedConvertedHomeAmount = normalizedOriginalAmount;
      computedConversionRate = 1;
      computedHomeCurrency = normalizedHomeCurrency;
    }

    final expense = Expense.create(
      tripId: _tripId,
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      transactionAmount: normalizedMoney.transactionAmount ?? amount,
      transactionCurrency: normalizedMoney.transactionCurrency ?? currencyCode,
      originalAmount: normalizedOriginalAmount,
      originalCurrency: normalizedOriginalCurrency,
      convertedHomeAmount: computedConvertedHomeAmount,
      homeCurrency: computedHomeCurrency,
      conversionRate: computedConversionRate,
      billedAmount: normalizedMoney.billedAmount,
      billedCurrency: normalizedMoney.billedCurrency,
      feesAmount: normalizedMoney.feesAmount,
      feesCurrency: normalizedMoney.feesCurrency,
      totalChargedAmount: normalizedMoney.totalChargedAmount,
      totalChargedCurrency: normalizedMoney.totalChargedCurrency,
      isInternational: moneyModel?.isInternational ?? isInternational,
      spentAt: spentAt,
      paymentMethod: paymentMethod,
      paymentNetwork: paymentNetwork,
      paymentChannel: paymentChannel,
      source: source,
      category: category,
      note: _normalizeText(note),
      rawSmsText: _normalizeText(rawSmsText),
      cardProfileId: cardProfileId,
    );

    return _runMutation(() async {
      final created = await ref.read(expenseRepositoryProvider).createExpense(expense);
      if (!_isCashExpense(created)) {
        return const ExpenseCreateOutcome(
          cashBalanceInsufficient: false,
          noCashBalanceRecorded: false,
        );
      }

      try {
        final deductionResult = await ref
            .read(cashWalletRepositoryProvider)
            .recordCashExpenseDeduction(
              tripId: _tripId,
              amount: created.transactionAmount,
              currencyCode: created.transactionCurrency,
              note: created.note,
            );

        return ExpenseCreateOutcome(
          cashBalanceInsufficient:
              deductionResult.wasInsufficientBeforeDeduction,
          noCashBalanceRecorded:
              deductionResult.wasInsufficientBeforeDeduction &&
              (deductionResult.balanceAfterDeduction + created.transactionAmount)
                      .abs() <
                  0.0001,
        );
      } catch (_) {
        // Wallet side-effects should not block core expense persistence.
        return const ExpenseCreateOutcome(
          cashBalanceInsufficient: false,
          noCashBalanceRecorded: false,
        );
      }
    });
  }

  bool _isCashExpense(Expense expense) {
    final paymentMethod = expense.paymentMethod.trim().toLowerCase();
    final paymentChannel = expense.paymentChannel?.trim().toLowerCase();
    return paymentMethod == 'cash' || paymentChannel == 'cash';
  }

  Future<T> _runMutation<T>(Future<T> Function() mutation) async {
    state = const AsyncLoading();

    try {
      final result = await mutation();
      ref.invalidate(globalReportProvider);
      ref.invalidate(tripReportProvider);
      state = AsyncData(await _loadExpenses());
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateExpense({
    required Expense expense,
    required String title,
    required double amount,
    required String currencyCode,
    MoneyModel? moneyModel,
    double? transactionAmount,
    String? transactionCurrency,
    double? originalAmount,
    String? originalCurrency,
    double? convertedHomeAmount,
    String? homeCurrency,
    double? conversionRate,
    double? billedAmount,
    String? billedCurrency,
    double? feesAmount,
    String? feesCurrency,
    double? totalChargedAmount,
    String? totalChargedCurrency,
    bool? isInternational,
    required String category,
    required DateTime spentAt,
    required String paymentMethod,
    String? paymentNetwork,
    String? paymentChannel,
    String source = 'manual',
    String? note,
    String? rawSmsText,
    int? cardProfileId,
  }) async {
    final normalizedMoney = moneyModel ??
        MoneyModel(
          transactionAmount: transactionAmount ?? amount,
          transactionCurrency: transactionCurrency ?? currencyCode,
          billedAmount: billedAmount,
          billedCurrency: billedCurrency,
          feesAmount: feesAmount,
          feesCurrency: feesCurrency,
          totalChargedAmount: totalChargedAmount,
          totalChargedCurrency: totalChargedCurrency,
          isInternational: isInternational ?? expense.isInternational,
        );

    final updatedExpense = expense.copyWith(
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      transactionAmount: normalizedMoney.transactionAmount ?? amount,
      transactionCurrency: normalizedMoney.transactionCurrency ?? currencyCode,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
      convertedHomeAmount: convertedHomeAmount,
      homeCurrency: homeCurrency,
      conversionRate: conversionRate,
      billedAmount: normalizedMoney.billedAmount,
      billedCurrency: normalizedMoney.billedCurrency,
      feesAmount: normalizedMoney.feesAmount,
      feesCurrency: normalizedMoney.feesCurrency,
      totalChargedAmount: normalizedMoney.totalChargedAmount,
      totalChargedCurrency: normalizedMoney.totalChargedCurrency,
      isInternational: moneyModel?.isInternational ?? isInternational,
      spentAt: spentAt,
      paymentMethod: paymentMethod,
      paymentNetwork: paymentNetwork,
      paymentChannel: paymentChannel,
      source: source,
      category: category,
      note: _normalizeText(note),
      rawSmsText: _normalizeText(rawSmsText),
      cardProfileId: cardProfileId,
    );

    await _runMutation(
      () => ref.read(expenseRepositoryProvider).updateExpense(updatedExpense),
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    await _runMutation(
      () => ref.read(expenseRepositoryProvider).deleteExpense(expenseId),
    );
  }

  Future<List<Expense>> _loadExpenses() {
    return ref.read(expenseRepositoryProvider).getExpensesByTrip(_tripId);
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
