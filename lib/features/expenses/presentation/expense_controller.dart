import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/async/async_notifier_reload.dart';
import '../../../core/providers/database_providers.dart';
import '../../global_reports/data/global_report_provider.dart';
import '../../predictions/data/trip_prediction_provider.dart';
import '../../reports/data/trip_report_provider.dart';
import '../domain/expense_fx_snapshot_service.dart';
import '../domain/expense.dart';
import '../domain/expense_payment.dart';
import '../domain/expense_payment_service.dart';
import '../domain/money_model.dart';

class ExpenseCreateOutcome {
  const ExpenseCreateOutcome({
    required this.cashBalanceInsufficient,
    required this.noCashBalanceRecorded,
    required this.missingManualRate,
    this.createdExpenseId,
    this.missingFromCurrency,
    this.missingToCurrency,
  });

  final bool cashBalanceInsufficient;
  final bool noCashBalanceRecorded;
  final bool missingManualRate;
  final String? createdExpenseId;
  final String? missingFromCurrency;
  final String? missingToCurrency;
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
    state = AsyncNotifierReload.loadingPreserving(state);

    try {
      state = AsyncData(await _loadExpenses());
    } catch (error, stackTrace) {
      state = AsyncNotifierReload.errorPreserving(error, stackTrace, state);
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

    final normalizedPayment = expensePaymentService.normalizeExpensePaymentMetadata(
      paymentMethod: paymentMethod,
      paymentNetwork: paymentNetwork,
      paymentChannel: paymentChannel,
      cardProfileId: cardProfileId,
    );

    final fxSnapshotService = ExpenseFxSnapshotService(
      cashWalletRepository: ref.read(cashWalletRepositoryProvider),
    );

    final conversionSnapshot = await fxSnapshotService.resolveCreateSnapshot(
      tripId: _tripId,
      fallbackAmount: amount,
      fallbackCurrencyCode: currencyCode,
      normalizedMoney: normalizedMoney,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
      convertedHomeAmount: convertedHomeAmount,
      homeCurrency: homeCurrency,
      conversionRate: conversionRate,
      tripHomeCurrency: tripHomeCurrency,
      paymentMethod: normalizedPayment.paymentMethod,
      paymentChannel: normalizedPayment.paymentChannel,
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
      paymentMethod: normalizedPayment.paymentMethod,
      paymentNetwork: normalizedPayment.paymentNetwork,
      paymentChannel: normalizedPayment.paymentChannel,
      source: source,
      category: category,
      note: _normalizeText(note),
      rawSmsText: _normalizeText(rawSmsText),
      cardProfileId: normalizedPayment.cardProfileId,
    );

    return _runMutation(() async {
      final created = await ref.read(expenseRepositoryProvider).createExpense(expense);
      if (!_isCashExpense(created)) {
        return ExpenseCreateOutcome(
          cashBalanceInsufficient: false,
          noCashBalanceRecorded: false,
          missingManualRate: conversionSnapshot.missingManualRate,
          createdExpenseId: created.id,
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
                createdExpenseId: created.id,
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
          createdExpenseId: created.id,
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
    return isCashExpensePayment(
      paymentMethod: expense.paymentMethod,
      paymentChannel: expense.paymentChannel,
    );
  }

  Future<T> _runMutation<T>(Future<T> Function() mutation) async {
    state = AsyncNotifierReload.loadingPreserving(state);

    try {
      final result = await mutation();
      ref.invalidate(globalReportProvider);
      ref.invalidate(tripReportProvider(_tripId));
      ref.invalidate(tripPredictionProvider(_tripId));
      state = AsyncData(await _loadExpenses());
      return result;
    } catch (error, stackTrace) {
      state = AsyncNotifierReload.errorPreserving(error, stackTrace, state);
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

    final normalizedPayment = expensePaymentService.normalizeExpensePaymentMetadata(
      paymentMethod: paymentMethod,
      paymentNetwork: paymentNetwork,
      paymentChannel: paymentChannel,
      cardProfileId: cardProfileId,
    );

    final fxSnapshotService = ExpenseFxSnapshotService(
      cashWalletRepository: ref.read(cashWalletRepositoryProvider),
    );

    final previousWasCash = _isCashPayment(
      paymentMethod: expense.paymentMethod,
      paymentChannel: expense.paymentChannel,
    );
    final nextIsCash = _isCashPayment(
      paymentMethod: normalizedPayment.paymentMethod,
      paymentChannel: normalizedPayment.paymentChannel,
    );
    final removedCardChargedAmount =
        !previousWasCash &&
        !nextIsCash &&
        expense.totalChargedAmount != null &&
        normalizedMoney.totalChargedAmount == null;
    final shouldForceClearSnapshot =
        (previousWasCash && !nextIsCash) || removedCardChargedAmount;

    final conversionSnapshot = await fxSnapshotService.resolveUpdateSnapshot(
      tripId: _tripId,
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
      paymentMethod: normalizedPayment.paymentMethod,
      paymentChannel: normalizedPayment.paymentChannel,
      forceClearSnapshot: shouldForceClearSnapshot,
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
      paymentMethod: normalizedPayment.paymentMethod,
      paymentNetwork: normalizedPayment.paymentNetwork,
      paymentChannel: normalizedPayment.paymentChannel,
      source: source,
      category: category,
      note: _normalizeText(note),
      rawSmsText: _normalizeText(rawSmsText),
      cardProfileId: normalizedPayment.cardProfileId,
    );

    await _runMutation(() async {
      final saved = await ref.read(expenseRepositoryProvider).updateExpense(updatedExpense);
      await ref.read(cashWalletRepositoryProvider).syncExpenseCashImpact(
            previousExpense: expense,
            nextExpense: saved,
          );
    });
  }

  bool _isCashPayment({required String paymentMethod, String? paymentChannel}) {
    return isCashExpensePayment(
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
    );
  }

  Future<List<Expense>> _loadExpenses() {
    return ref.read(expenseRepositoryProvider).getExpensesByTrip(_tripId);
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

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
