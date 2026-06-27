import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/async/async_notifier_reload.dart';
import '../../../core/providers/database_providers.dart';
import '../../cash_wallet/data/cash_wallet_repository.dart';
import '../../cash_wallet/domain/insufficient_cash_exception.dart';
import '../../global_reports/data/global_report_provider.dart';
import '../../predictions/data/trip_prediction_provider.dart';
import '../../reports/data/trip_cash_balances_provider.dart';
import '../../reports/data/trip_report_provider.dart';
import '../domain/expense_fx_snapshot_service.dart';
import '../domain/expense.dart';
import '../domain/expense_payment.dart';
import '../domain/expense_payment_service.dart';
import '../domain/money_model.dart';
import '../domain/update_cash_expense_exception.dart';

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

/// Returned when an expense edit is saved successfully so callers can show
/// undo feedback without treating a plain back navigation as a save.
class ExpenseEditSaveOutcome {
  const ExpenseEditSaveOutcome({required this.previousExpense});

  final Expense previousExpense;
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

    final affectsCashBalances = _isCashExpense(expense);

    return _runMutation(
      () async {
      final expenseRepository = ref.read(expenseRepositoryProvider);

      if (!affectsCashBalances) {
        final created = await expenseRepository.createExpense(expense);
        return _buildCreateOutcome(
          created: created,
          conversionSnapshot: conversionSnapshot,
        );
      }

      try {
        final cashCreateResult =
            await ref.read(recordCashExpenseUseCaseProvider).execute(expense);
        return _buildCreateOutcome(
          created: cashCreateResult.expense,
          conversionSnapshot: conversionSnapshot,
          deductionResult: cashCreateResult.deduction,
        );
      } on InsufficientCashException {
        return ExpenseCreateOutcome(
          cashBalanceInsufficient: true,
          noCashBalanceRecorded: true,
          missingManualRate: conversionSnapshot.missingManualRate,
          createdExpenseId: null,
        );
      }
    },
      invalidateCashBalances: affectsCashBalances,
    );
  }

  bool _isCashExpense(Expense expense) {
    return isCashExpensePayment(
      paymentMethod: expense.paymentMethod,
      paymentChannel: expense.paymentChannel,
    );
  }

  ExpenseCreateOutcome _buildCreateOutcome({
    required Expense created,
    required ExpenseConversionSnapshot conversionSnapshot,
    CashExpenseDeductionResult? deductionResult,
  }) {
    final wasInsufficient = deductionResult?.wasInsufficientBeforeDeduction ?? false;
    final balanceAfter = deductionResult?.balanceAfterDeduction;

    return ExpenseCreateOutcome(
      cashBalanceInsufficient: wasInsufficient,
      noCashBalanceRecorded: wasInsufficient &&
          balanceAfter != null &&
          (balanceAfter + created.transactionAmount).abs() < 0.0001,
      missingManualRate: conversionSnapshot.missingManualRate,
      createdExpenseId: created.id,
      missingFromCurrency: conversionSnapshot.missingManualRate
          ? conversionSnapshot.originalCurrency
          : null,
      missingToCurrency: conversionSnapshot.missingManualRate
          ? conversionSnapshot.homeCurrency
          : null,
    );
  }

  Future<T> _runMutation<T>(
    Future<T> Function() mutation, {
    bool invalidateCashBalances = false,
  }) async {
    state = AsyncNotifierReload.loadingPreserving(state);

    try {
      final result = await mutation();
      ref.invalidate(globalReportProvider);
      ref.invalidate(tripReportProvider(_tripId));
      if (invalidateCashBalances) {
        ref.invalidate(tripCashBalancesProvider(_tripId));
      }
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

    final previousWasCash = _isCashPayment(
      paymentMethod: expense.paymentMethod,
      paymentChannel: expense.paymentChannel,
    );
    final nextIsCash = _isCashPayment(
      paymentMethod: normalizedPayment.paymentMethod,
      paymentChannel: normalizedPayment.paymentChannel,
    );

    // ── Cash path ────────────────────────────────────────────────────────────
    // When either side is cash, delegate to UpdateCashExpenseUseCase which
    // handles FIFO lot reversal + recreation atomically.
    // getEffectiveCashRate is NOT called on this path; FIFO is the sole source
    // of cost basis for cash expenses.
    if (nextIsCash || previousWasCash) {
      // For cash → card: resolve the card FX snapshot so the expense carries
      // a valid home-currency amount.  The FX service is safe here because
      // neither old nor new expense is cash (nextIsCash = false), so
      // getEffectiveCashRate is never invoked.
      ExpenseConversionSnapshot? cardSnapshot;
      if (!nextIsCash) {
        final fxSnapshotService = ExpenseFxSnapshotService(
          cashWalletRepository: ref.read(cashWalletRepositoryProvider),
        );
        cardSnapshot = await fxSnapshotService.resolveUpdateSnapshot(
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
          // Force-clear the stale cash snapshot when switching to card.
          forceClearSnapshot: true,
        );
      }

      // Build the candidate expense.  For cash destinations the FX fields are
      // intentionally null — the use case will derive them from FIFO.
      final txAmount = normalizedMoney.transactionAmount ?? amount;
      final txCurrency = normalizedMoney.transactionCurrency ?? currencyCode;
      final updatedExpense = expense.copyWith(
        title: title,
        amount: amount,
        currencyCode: currencyCode,
        transactionAmount: txAmount,
        transactionCurrency: txCurrency,
        // Cash → card: use the resolved card snapshot.
        // Card → cash / cash → cash: null — FIFO will set these.
        originalAmount: nextIsCash ? txAmount : cardSnapshot?.originalAmount,
        originalCurrency:
            nextIsCash ? txCurrency : cardSnapshot?.originalCurrency,
        convertedHomeAmount:
            nextIsCash ? null : cardSnapshot?.convertedHomeAmount,
        homeCurrency: nextIsCash
            ? (homeCurrency ?? expense.homeCurrency)
            : cardSnapshot?.homeCurrency,
        conversionRate: nextIsCash ? null : cardSnapshot?.conversionRate,
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

      await _runMutation(
        () async {
          try {
            await ref
                .read(updateCashExpenseUseCaseProvider)
                .execute(updatedExpense);
          } on UpdateCashExpenseException {
            rethrow;
          }
        },
        invalidateCashBalances: true,
      );
      return;
    }

    // ── Card → card path ────────────────────────────────────────────────────
    final activeRefunds = await ref
        .read(expenseRefundRepositoryProvider)
        .getActiveRefundsByExpense(expense.id);
    if (activeRefunds.isNotEmpty) {
      throw const UpdateCashExpenseException(
        UpdateCashExpenseFailureReason.hasActiveRefunds,
      );
    }

    final fxSnapshotService = ExpenseFxSnapshotService(
      cashWalletRepository: ref.read(cashWalletRepositoryProvider),
    );

    final removedCardChargedAmount = expense.totalChargedAmount != null &&
        normalizedMoney.totalChargedAmount == null;

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
      forceClearSnapshot: removedCardChargedAmount,
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
      final saved =
          await ref.read(expenseRepositoryProvider).updateExpense(updatedExpense);
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
    await _runMutation(
      () async {
        // UpdateCashExpenseUseCase.reverseAndDelete atomically restores FIFO lot
        // state (consumptions reversed, lot remaining_amounts restored,
        // cash_transactions deduction reversed) before hard-deleting the row.
        await ref
            .read(updateCashExpenseUseCaseProvider)
            .reverseAndDelete(expenseId);
      },
      invalidateCashBalances: true,
    );
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
