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
    required this.missingManualRate,
    this.missingFromCurrency,
    this.missingToCurrency,
  });

  final bool cashBalanceInsufficient;
  final bool noCashBalanceRecorded;
  final bool missingManualRate;
  final String? missingFromCurrency;
  final String? missingToCurrency;
}

class _ResolvedConversionSnapshot {
  const _ResolvedConversionSnapshot({
    required this.originalAmount,
    required this.originalCurrency,
    required this.convertedHomeAmount,
    required this.homeCurrency,
    required this.conversionRate,
    required this.missingManualRate,
  });

  final double originalAmount;
  final String originalCurrency;
  final double? convertedHomeAmount;
  final String? homeCurrency;
  final double? conversionRate;
  final bool missingManualRate;
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

    final conversionSnapshot = await _resolveConversionSnapshot(
      fallbackAmount: amount,
      fallbackCurrencyCode: currencyCode,
      normalizedMoney: normalizedMoney,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
      convertedHomeAmount: convertedHomeAmount,
      homeCurrency: homeCurrency,
      conversionRate: conversionRate,
      tripHomeCurrency: tripHomeCurrency,
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
    );

    final expense = Expense.create(
      tripId: _tripId,
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      transactionAmount: normalizedMoney.transactionAmount ?? amount,
      transactionCurrency: normalizedMoney.transactionCurrency ?? currencyCode,
      originalAmount: conversionSnapshot.originalAmount,
      originalCurrency: conversionSnapshot.originalCurrency,
      convertedHomeAmount: conversionSnapshot.convertedHomeAmount,
      homeCurrency: conversionSnapshot.homeCurrency,
      conversionRate: conversionSnapshot.conversionRate,
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
        return ExpenseCreateOutcome(
          cashBalanceInsufficient: false,
          noCashBalanceRecorded: false,
          missingManualRate: conversionSnapshot.missingManualRate,
          missingFromCurrency:
            conversionSnapshot.missingManualRate
              ? conversionSnapshot.originalCurrency
              : null,
          missingToCurrency:
            conversionSnapshot.missingManualRate
              ? conversionSnapshot.homeCurrency
              : null,
        );
      }

      try {
        final deductionResult = await ref
            .read(cashWalletRepositoryProvider)
            .recordCashExpenseDeduction(
              tripId: _tripId,
              expenseId: created.id,
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
          missingManualRate: conversionSnapshot.missingManualRate,
          missingFromCurrency:
              conversionSnapshot.missingManualRate
                  ? conversionSnapshot.originalCurrency
                  : null,
          missingToCurrency:
              conversionSnapshot.missingManualRate
                  ? conversionSnapshot.homeCurrency
                  : null,
        );
      } catch (_) {
        // Wallet side-effects should not block core expense persistence.
        return ExpenseCreateOutcome(
          cashBalanceInsufficient: false,
          noCashBalanceRecorded: false,
          missingManualRate: conversionSnapshot.missingManualRate,
          missingFromCurrency:
              conversionSnapshot.missingManualRate
                  ? conversionSnapshot.originalCurrency
                  : null,
          missingToCurrency:
              conversionSnapshot.missingManualRate
                  ? conversionSnapshot.homeCurrency
                  : null,
        );
      }
    });
  }

  bool _isCashExpense(Expense expense) {
    return _isCashPayment(
      paymentMethod: expense.paymentMethod,
      paymentChannel: expense.paymentChannel,
    );
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
          isInternational: isInternational ?? expense.isInternational,
        );

    final conversionSnapshot = await _resolveConversionSnapshot(
      fallbackAmount: amount,
      fallbackCurrencyCode: currencyCode,
      normalizedMoney: normalizedMoney,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
      convertedHomeAmount: convertedHomeAmount,
      homeCurrency: homeCurrency,
      conversionRate: conversionRate,
      tripHomeCurrency: tripHomeCurrency,
      previousExpense: expense,
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
    );

    final updatedExpense = expense.copyWith(
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      transactionAmount: normalizedMoney.transactionAmount ?? amount,
      transactionCurrency: normalizedMoney.transactionCurrency ?? currencyCode,
      originalAmount: conversionSnapshot.originalAmount,
      originalCurrency: conversionSnapshot.originalCurrency,
      convertedHomeAmount: conversionSnapshot.convertedHomeAmount,
      homeCurrency: conversionSnapshot.homeCurrency,
      conversionRate: conversionSnapshot.conversionRate,
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

    await _runMutation(() async {
      final saved = await ref.read(expenseRepositoryProvider).updateExpense(updatedExpense);
      await ref.read(cashWalletRepositoryProvider).syncExpenseCashImpact(
            previousExpense: expense,
            nextExpense: saved,
          );
    });
  }

  Future<void> deleteExpense(String expenseId) async {
    await _runMutation(() async {
      final existing = await ref.read(expenseRepositoryProvider).getExpenseById(expenseId);
      if (existing != null) {
        await ref.read(cashWalletRepositoryProvider).restoreCashForDeletedExpense(existing);
      }
      await ref.read(expenseRepositoryProvider).deleteExpense(expenseId);
    });
  }

  Future<List<Expense>> _loadExpenses() {
    return ref.read(expenseRepositoryProvider).getExpensesByTrip(_tripId);
  }

  Future<_ResolvedConversionSnapshot> _resolveConversionSnapshot({
    required double fallbackAmount,
    required String fallbackCurrencyCode,
    required MoneyModel normalizedMoney,
    double? originalAmount,
    String? originalCurrency,
    double? convertedHomeAmount,
    String? homeCurrency,
    double? conversionRate,
    String? tripHomeCurrency,
    Expense? previousExpense,
    required String paymentMethod,
    String? paymentChannel,
  }) async {
    final normalizedOriginalAmount =
        originalAmount ?? normalizedMoney.transactionAmount ?? fallbackAmount;
    final normalizedOriginalCurrency =
        _normalizeCurrency(
          originalCurrency ??
              normalizedMoney.transactionCurrency ??
              fallbackCurrencyCode,
        ) ??
        fallbackCurrencyCode.trim().toUpperCase();
    final normalizedHomeCurrency = _normalizeCurrency(
      homeCurrency ?? tripHomeCurrency ?? previousExpense?.homeCurrency,
    );

    var computedConvertedHomeAmount = convertedHomeAmount;
    var computedConversionRate = conversionRate;
    var computedHomeCurrency = normalizedHomeCurrency;
    var missingManualRate = false;

    if (normalizedHomeCurrency == null || normalizedHomeCurrency.isEmpty) {
      return _ResolvedConversionSnapshot(
        originalAmount: normalizedOriginalAmount,
        originalCurrency: normalizedOriginalCurrency,
        convertedHomeAmount: computedConvertedHomeAmount,
        homeCurrency: computedHomeCurrency,
        conversionRate: computedConversionRate,
        missingManualRate: false,
      );
    }

    if (normalizedOriginalCurrency == normalizedHomeCurrency) {
      return _ResolvedConversionSnapshot(
        originalAmount: normalizedOriginalAmount,
        originalCurrency: normalizedOriginalCurrency,
        convertedHomeAmount: normalizedOriginalAmount,
        homeCurrency: normalizedHomeCurrency,
        conversionRate: 1,
        missingManualRate: false,
      );
    }

    if (computedConversionRate != null) {
      return _ResolvedConversionSnapshot(
        originalAmount: normalizedOriginalAmount,
        originalCurrency: normalizedOriginalCurrency,
        convertedHomeAmount: normalizedOriginalAmount * computedConversionRate,
        homeCurrency: normalizedHomeCurrency,
        conversionRate: computedConversionRate,
        missingManualRate: false,
      );
    }

    final shouldKeepCardRate =
        previousExpense != null &&
        !_isCashPayment(
          paymentMethod: paymentMethod,
          paymentChannel: paymentChannel,
        ) &&
        previousExpense.conversionRate != null;

    if (shouldKeepCardRate) {
      computedConversionRate = previousExpense.conversionRate;
      return _ResolvedConversionSnapshot(
        originalAmount: normalizedOriginalAmount,
        originalCurrency: normalizedOriginalCurrency,
        convertedHomeAmount: normalizedOriginalAmount * computedConversionRate!,
        homeCurrency: normalizedHomeCurrency,
        conversionRate: computedConversionRate,
        missingManualRate: false,
      );
    }

    try {
      final conversion = await ref
          .read(manualCurrencyConversionServiceProvider)
          .convert(
            tripId: _tripId,
            amount: normalizedOriginalAmount,
            fromCurrency: normalizedOriginalCurrency,
            toCurrency: normalizedHomeCurrency,
          );

      if (conversion != null) {
        computedConvertedHomeAmount = conversion.convertedAmount;
        computedConversionRate = conversion.rate;
        computedHomeCurrency = normalizedHomeCurrency;
      } else {
        computedConvertedHomeAmount = null;
        computedConversionRate = null;
        computedHomeCurrency = normalizedHomeCurrency;
        missingManualRate = true;
      }
    } catch (_) {
      computedConvertedHomeAmount = null;
      computedConversionRate = null;
      computedHomeCurrency = normalizedHomeCurrency;
      missingManualRate = true;
    }

    return _ResolvedConversionSnapshot(
      originalAmount: normalizedOriginalAmount,
      originalCurrency: normalizedOriginalCurrency,
      convertedHomeAmount: computedConvertedHomeAmount,
      homeCurrency: computedHomeCurrency,
      conversionRate: computedConversionRate,
      missingManualRate: missingManualRate,
    );
  }

  bool _isCashPayment({required String paymentMethod, String? paymentChannel}) {
    final normalizedPaymentMethod = paymentMethod.trim().toLowerCase();
    final normalizedPaymentChannel = paymentChannel?.trim().toLowerCase();
    return normalizedPaymentMethod == 'cash' || normalizedPaymentChannel == 'cash';
  }

  String? _normalizeCurrency(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed.toUpperCase();
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
